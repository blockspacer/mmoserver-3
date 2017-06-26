--------------------------------------------------------------------
-- 文件名:	player_rank.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/13 0013
-- 描  述:	玩家排行榜
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local data_base = require "basic/db_mongo"
local create_rank_list = require("global_ranking/basic_rank_list").create_rank_list
local update_rank_list = require("global_ranking/basic_rank_list").update_rank_list
local timer = require "basic/timer"
local DATABASE_TABLE_NAME = "rank_info_2"
local UNDATE_INTERVAL = 300000

local update_timer
local hide_name_number_list = {}
local is_prepare_close = false

local function _db_callback_update_player_rank(caller, status,callback_id)
    if status == 0 then
        flog("error", "_db_callback_update_pet_rank: set data fail!")
        return
    end

    if is_prepare_close then
        RankingUserManageReadyClose("player_rank")
    end
end

local function _write_to_database()
    flog("info", "player rank _write_to_database")
    local player_rank_data = {}
    player_rank_data.rank_name = 'player_rank'
    player_rank_data.hide_name_number_list = hide_name_number_list
    data_base.db_update_doc(0, _db_callback_update_player_rank, DATABASE_TABLE_NAME, {rank_name = 'player_rank'}, player_rank_data, 1, 0)
end

local function hide_name_from_rank_list(rank_set_name, is_hide)
    hide_name_number_list[rank_set_name] = hide_name_number_list[rank_set_name] or 0
    if is_hide then
        hide_name_number_list[rank_set_name] = hide_name_number_list[rank_set_name] + 1
    else
        hide_name_number_list[rank_set_name] = hide_name_number_list[rank_set_name] - 1
    end

    if hide_name_number_list[rank_set_name] < 0 then
        flog("error", string.format("hide_name_number_list[%s] is negetive %d", rank_set_name, hide_name_number_list[rank_set_name]))
    end
    _write_to_database()
    return hide_name_number_list[rank_set_name]
end

local function get_hide_name_number(rank_set_name)
    hide_name_number_list[rank_set_name] = hide_name_number_list[rank_set_name] or 0
    return hide_name_number_list[rank_set_name]
end


local function _db_callback_get_player_rank(caller, status, doc)
    if status == 0 or doc == nil then
        flog("error", "_db_callback_get_pet_rank: get data fail!")
        return
    end

    hide_name_number_list = table.get(doc, "hide_name_number_list", {})

    if update_timer == nil then
        update_timer = timer.create_timer(_write_to_database, UNDATE_INTERVAL, const.INFINITY_CALL)
    end
end

local function _get_data_from_database()
    data_base.db_find_one(0, _db_callback_get_player_rank, DATABASE_TABLE_NAME, {rank_name = 'player_rank'}, {})
end

local function on_server_start()
    _get_data_from_database()
end

local function on_server_stop()
    is_prepare_close = true
    _write_to_database()
end

return {
    hide_name_from_rank_list = hide_name_from_rank_list,
    get_hide_name_number = get_hide_name_number,
    on_server_start = on_server_start,
    on_server_stop = on_server_stop,
}