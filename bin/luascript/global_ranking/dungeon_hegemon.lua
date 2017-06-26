----------------------------------------------------------------------
-- 文件名:	dungeon_hegemon.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/11/10
-- 描  述:	排行榜霸主模块
--------------------------------------------------------------------
local normal_tran_script = require("data/challenge_main_dungeon").NormalTranscript
local const = require "Common/constant"
local data_base = require "basic/db_mongo"
local flog = require "basic/log"
local weekly_refresher = require("helper/weekly_refresher")
local timer = require "basic/timer"
local challenge_main_dungeon_config = require "configs/challenge_main_dungeon_config"
local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"
local pairs = pairs
local mail_helper = require "global_mail/mail_helper"
local is_command_cool_down = require("helper/command_cd").is_command_cool_down

local REFRESH_WDAY = require("data/challenge_main_dungeon").Parameter[15].Value[1]  --周日为1，每周第一天
local REFRESH_HOUR = require("data/challenge_main_dungeon").Parameter[16].Value[1]
local REFRESH_MIN = require("data/challenge_main_dungeon").Parameter[16].Value[2]
local MAIN_DUNGEON_HEGEMON_NUM = 5   --主线副本记录前五名
local TEAM_DUNGEON_HEGEMON_NUM = 3   --组队副本记录前三名
local MAIN_DUNGEON_NO_RECORD_LEVEL_DIFF = require("data/challenge_main_dungeon").Parameter[5].Value[1]
local TEAM_DUNGEON_NO_RECORD_LEVEL_DIFF = require("data/challenge_main_dungeon").Parameter[21].Value[1]

local dungeon_top = {rank_name = 'dungeon_top'}
local hegemon_timer
local hegemon_refresher
local is_prepare_close = false
local HEGEMON_TIMER_INTERVAL = 45000
local TIMER_TRIGGER_CD = 61
local _get_now_time_second = _get_now_time_second

local function _db_callback_update_dungeon_top(caller, status,callback_id)
    if status == 0 then
        flog("error", "_db_callback_update_dungeon_top: set data fail!")
        return
    end

    if is_prepare_close then
        RankingUserManageReadyClose("dungeon_hegemon")
    end
end

local function _write_to_database()
    flog("info", "dungeon_hegemon _write_to_database")
    dungeon_top.hegemon_last_refresh_time = hegemon_refresher:get_last_refresh_time()
    dungeon_top.rank_name = 'dungeon_top'
    data_base.db_update_doc(0, _db_callback_update_dungeon_top, "rank_info", {rank_name = 'dungeon_top'}, dungeon_top, 1, 0)
end

local function _refresh_data()
    dungeon_top = {}
    hegemon_refresher:set_last_refresh_time(_get_now_time_second())
    _write_to_database()
end

local function _db_callback_get_dungeon_top(caller, status, doc)
    if status == 0 or doc == nil then
        flog("error", "_db_callback_get_dungeon_top: get data fail!")
        return
    end
    dungeon_top = table.copy(doc) or {}
    local hegemon_last_refresh_time = dungeon_top.hegemon_last_refresh_time or _get_now_time_second()
    hegemon_refresher = weekly_refresher(_refresh_data, hegemon_last_refresh_time, REFRESH_WDAY, REFRESH_HOUR, REFRESH_MIN)
end

local function _get_data_from_database()
    data_base.db_find_one(0, _db_callback_get_dungeon_top, "rank_info", {rank_name = 'dungeon_top'}, {})
end

local function _is_bonus_time()
    local current_time = _get_now_time_second()
    if challenge_main_dungeon_config.is_dungeon_hegemon_bonus_time(current_time) then
        local result = is_command_cool_down("system", "hegemon_bonus_time", TIMER_TRIGGER_CD)
        if result == 0 then
            return true
        end
    end
    return false
end

local function _dispense_rewards()
    local current_time = _get_now_time_second()
    for chapter_id, chapter_top_list in pairs(dungeon_top) do
        if chapter_id == "team_dungeon" then
            for dungeon_id, info in pairs(chapter_top_list) do
                local dungeon_name = challenge_team_dungeon_config.get_team_dungeon_name(dungeon_id)
                for rank, team in pairs(info) do
                    for _, v in pairs(team.members) do
                        mail_helper.send_mail(v.actor_id, const.MAIL_IDS.TEAM_DUNGEON_SCORE_FIRST + rank - 1, {}, current_time,{dungeon_name})
                    end
                end
            end
        elseif type(chapter_top_list) == 'table' then
            for dungeon_id, info in pairs(chapter_top_list) do
                local dungeon_name = challenge_main_dungeon_config.get_main_dungeon_name(dungeon_id)
                for rank, player in pairs(info) do
                    mail_helper.send_mail(player.actor_id, const.MAIL_IDS.MAIN_DUNGEON_SCORE_FIRST + rank - 1, {}, current_time,{dungeon_name})
                end
            end
        end
    end
end

local function hegemon_timer_callback()
    if hegemon_refresher ~= nil then
        hegemon_refresher:check_refresh()
    else
        _get_data_from_database()
    end

    if _is_bonus_time() then
        _dispense_rewards()
    end
end


local function update_dungeon_hegemon(player, chapter_id, dungeon_id, time)
    if player.level - normal_tran_script[dungeon_id].Level > MAIN_DUNGEON_NO_RECORD_LEVEL_DIFF then
        flog("syzDebug", "level too high , not record to dungeon hegemon :"..player.level)
        return
    end

    dungeon_top[chapter_id] = dungeon_top[chapter_id] or {}
    dungeon_top[chapter_id][dungeon_id] = dungeon_top[chapter_id][dungeon_id] or {}
    local list = dungeon_top[chapter_id][dungeon_id]
    local b_inlist = false
    local rank
    for i, v in pairs(list) do
        if v.actor_id == player.actor_id then
            flog("syzDebug", "dungeon_hegemon is in list")
            b_inlist = true
            if time < v.time then
                flog("syzDebug", "dungeon_hegemon record update")
                v.time = time
                rank = i
            end
            break
        end
    end
    if rank ~= nil then
        local player_data = list[rank]
        for i = rank - 1, 1, -1 do
            if time < list[i].time then
                list[i + 1] =  list[i]
                list[i] = player_data
                rank = i
            end
        end
    end

    if not b_inlist then
        for i = 1, MAIN_DUNGEON_HEGEMON_NUM do
            if list[i] ==nil or time < list[i].time then
                flog("syzDebug", "dungeon_hegemon fresh in list")
                rank = i
                break
            end
        end
        if rank ~= nil then
            table.insert(list, rank, {time = time, actor_id = player.actor_id, actor_name = player.actor_name, level = player.level})
        end
        while(list[MAIN_DUNGEON_HEGEMON_NUM + 1] ~= nil) do
            table.remove(list, MAIN_DUNGEON_HEGEMON_NUM + 1)
        end
    end

    if rank ~= nil then
        _write_to_database()
        --broadcast_message(const.SC_MESSAGE_LUA_HEGEMON_BROADCAST, { actor_id = player.actor_id, actor_name = player.actor_name, dungeon_id = dungeon_id, rank = rank})
    end
    return rank
end

local function update_team_dungeon_hegemon(team, dungeon_id, time)
    local members = team.members

    dungeon_top["team_dungeon"] = dungeon_top["team_dungeon"] or {}
    local team_dungeon_top = dungeon_top["team_dungeon"]
    team_dungeon_top[dungeon_id] = team_dungeon_top[dungeon_id] or {}
    local list = team_dungeon_top[dungeon_id]
    local b_inlist = false
    local rank
    for i, v in pairs(list) do
        if v.captain_id == team.captain_id then
            b_inlist = true
            if time < v.time then
                v.time = time
                v.members = members
                rank = i
            end
            break
        end
    end
    if rank ~= nil then
        local player_data = list[rank]
        for i = rank - 1, 1, -1 do
            if time < list[i].time then
                list[i + 1] =  list[i]
                list[i] = player_data
                rank = i
            end
        end
    end

    if not b_inlist then
        for i = 1, TEAM_DUNGEON_HEGEMON_NUM do
            if list[i] ==nil or time < list[i].time then
                flog("syzDebug", "dungeon_hegemon fresh in list")
                rank = i
                break
            end
        end
        if rank ~= nil then
            table.insert(list, rank, {time = time, captain_id = team.captain_id, members = team.members})
        end
        while(list[TEAM_DUNGEON_HEGEMON_NUM + 1] ~= nil) do
            table.remove(list, TEAM_DUNGEON_HEGEMON_NUM + 1)
        end
    end

    if rank ~= nil then
        _write_to_database()
        --broadcast_message(const.SC_MESSAGE_LUA_HEGEMON_BROADCAST, { actor_id = player.actor_id, actor_name = player.actor_name, dungeon_id = dungeon_id, rank = rank})
    end
    return rank
end


local function clear_dungeon_hegemon()
    flog("syzDebug", "gm_clear_dungeon_hegemon")
    _refresh_data()
end

local function get_dungeon_hegemon(dungeon_id, chapter_ids, dungeon_type)
    dungeon_type = dungeon_type or "main_dungeon"
    if dungeon_id ~= nil then
        local chapter_id
        if dungeon_type == "main_dungeon" then
            chapter_id = normal_tran_script[dungeon_id].Chapter
        elseif dungeon_type == "team_dungeon" then
            chapter_id = "team_dungeon"
        else
            flog("error", "get_dungeon_hegemon: error dungeon_dype "..dungeon_type)
            return
        end
        dungeon_top[chapter_id] = dungeon_top[chapter_id] or {}
        dungeon_top[chapter_id][dungeon_id] = dungeon_top[chapter_id][dungeon_id] or {}
        local dungeon_hegemon = dungeon_top[chapter_id][dungeon_id]
        return {result = 0, dungeon_hegemon = dungeon_hegemon}
    elseif chapter_ids ~= nil then
        local name_table = {}
        for _, cid in pairs(chapter_ids) do
            dungeon_top[cid] = dungeon_top[cid] or {}
            for did, info in pairs(dungeon_top[cid]) do
                if info[1] ~= nil then
                    if dungeon_type == "main_dungeon" then
                        name_table[did] = {actor_name = info[1].actor_name }
                    elseif dungeon_type == "team_dungeon" then
                        local team = info[1]
                        name_table[did] = {captain = team.members[1] }
                    else
                        flog("error", "get_dungeon_hegemon: error dungeon_dype "..dungeon_type)
                        return
                    end
                end
            end
        end
        return {result = 0, name_table = name_table}
    else
        flog("warn", "get_dungeon_hegemon: dungeon_id chapter_ids all nil !")
        return {result = const.error_impossible_param}
    end
end

local function on_server_start()
    if hegemon_timer == nil then
        hegemon_timer = timer.create_timer(hegemon_timer_callback, HEGEMON_TIMER_INTERVAL, const.INFINITY_CALL)
    end
    _get_data_from_database()
end

local function on_server_stop()
    is_prepare_close = true
    _write_to_database()
end

local function gm_hegemon_dispense_rewards()
    _dispense_rewards()
end

return {
    update_dungeon_hegemon = update_dungeon_hegemon,
    clear_dungeon_hegemon = clear_dungeon_hegemon,
    get_dungeon_hegemon = get_dungeon_hegemon,
    on_server_start = on_server_start,
    on_server_stop = on_server_stop,
    update_team_dungeon_hegemon = update_team_dungeon_hegemon,
    gm_hegemon_dispense_rewards = gm_hegemon_dispense_rewards,
}