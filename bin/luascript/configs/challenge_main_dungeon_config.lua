--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/5 0005
-- Time: 19:13
-- To change this template use File | Settings | File Templates.
--

local challenge_main_dungeon = require "data/challenge_main_dungeon"
local flog = require "basic/log"
local const = require "Common/constant"
local string_split = require("basic/scheme").string_split
local tonumber = tonumber
local get_config_name = require("basic/scheme").get_config_name

local dungeon_configs
local transcript_mark_configs
local hegemon_bonus_hour
local hegemon_bonus_min
local dungeon_hegemon_score
local max_get_hegemon_pack_times

local function get_transcript_mark_config(time)
    local transcript_mark_config = nil
    for _,config in pairs(transcript_mark_configs) do
        if time >= config.RestTime then
            transcript_mark_config = config
        else
            break
        end
    end
    return transcript_mark_config
end

local function get_main_dungeon_config(id)
    return dungeon_configs[id]
end

local function get_challenge_main_dungeon_table()
    return challenge_main_dungeon
end

local function get_main_dungeon_scene_setting(id)
    local dungeon_config = get_main_dungeon_config(id)
    if dungeon_config == nil then
        return nil
    end
    return challenge_main_dungeon[dungeon_config.SceneSetting]
end

local function get_dungeon_mark(type,param1,param2)
    flog("tmlDebug","type "..type..",param1 "..param1..",param2 "..param2)
    local reward_index = -1
    local time_rate = 0
    if param1 < 0 then
        param1 = 0
    end

    if type == const.DUNGEON_TYPE.in_limited_time then
        time_rate = param1*100/param2
        for i, v in ipairs(challenge_main_dungeon.TranscriptMark) do
            if time_rate >= v.KillNum then
                reward_index = i
                break
            end
        end
    else
        time_rate = param1*100000/param2
        for i, v in ipairs(challenge_main_dungeon.TranscriptMark) do
            if time_rate >= v.RestTime then
                reward_index = i
                break
            end
        end
    end
    flog("tmlDebug","time_rate "..time_rate)
    return reward_index
end

local function is_dungeon_hegemon_bonus_time(current_time)
    local current_date = os.date("*t", current_time)
    if current_date.hour == hegemon_bonus_hour and current_date.min == hegemon_bonus_min then
        return true
    end
    return false
end

local function get_main_dungeon_name(dungeon_id)
    local config = dungeon_configs[dungeon_id]
    return get_config_name(config)
end

local function reload()
    --检查出生点
    for id,v in pairs(challenge_main_dungeon.NormalTranscript) do
        if v.SceneSetting == nil or v.SceneSetting == "" then
            flog("warn","challenge_main_dungeon can not have SceneSetting id "..id..",SceneSetting "..v.SceneSetting)
        else
            local find = false
            for _,v1 in pairs(challenge_main_dungeon[v.SceneSetting]) do
                if v1.Type == const.ENTITY_TYPE_BIRTHDAY_POS then
                    find = true
                    break
                end
            end
            if find == false then
                flog("error","can not find birth position in main dungeon,id "..id)
            end
        end
    end

    dungeon_configs = {}
    for _,v in pairs(challenge_main_dungeon.NormalTranscript) do
        dungeon_configs[v.ID] = v
    end

    transcript_mark_configs = {}
    for _,v in pairs(challenge_main_dungeon.TranscriptMark) do
        table.insert(transcript_mark_configs,v)
    end
    table.sort(transcript_mark_configs,function(a,b)
        return a.RestTime < b.RestTime
    end)

    local bonus_table = challenge_main_dungeon.Parameter[14].Value
    hegemon_bonus_hour = bonus_table[1]
    hegemon_bonus_min = bonus_table[2]

    dungeon_hegemon_score = {main_dungeon = {}, team_dungeon = {}}
    local teamd_dungeon_rate = challenge_main_dungeon.Parameter[20].Value[1]
    for i = 1, 5 do --第7个参数是第一名奖励
        dungeon_hegemon_score.main_dungeon[i] = challenge_main_dungeon.Parameter[i + 6].Value[1]
        dungeon_hegemon_score.team_dungeon[i] = dungeon_hegemon_score.main_dungeon[i] * teamd_dungeon_rate
    end

    max_get_hegemon_pack_times = challenge_main_dungeon.Parameter[6].Value[1]
end
reload()

return{
    get_transcript_mark_config = get_transcript_mark_config,
    get_main_dungeon_config = get_main_dungeon_config,
    get_challenge_main_dungeon_table = get_challenge_main_dungeon_table,
    get_main_dungeon_scene_setting = get_main_dungeon_scene_setting,
    get_dungeon_mark = get_dungeon_mark,
    is_dungeon_hegemon_bonus_time = is_dungeon_hegemon_bonus_time,
    dungeon_hegemon_score = dungeon_hegemon_score,
    get_main_dungeon_name = get_main_dungeon_name,
    max_get_hegemon_pack_times = max_get_hegemon_pack_times,
    reload = reload,
}