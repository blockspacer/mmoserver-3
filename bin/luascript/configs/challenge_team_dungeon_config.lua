--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/30 0030
-- Time: 15:26
-- To change this template use File | Settings | File Templates.
--
local challenge_team_dungeon = require "data/challenge_team_dungeon"
local flog = require "basic/log"
local const = require "Common/constant"
local const = require "Common/constant"
local brief_config = challenge_team_dungeon.TeamDungeons
local cost_config = challenge_team_dungeon.Cost
local online_user = require "onlinerole"
local flog = require "basic/log"
local get_config_name = require("basic/scheme").get_config_name

local team_dungeon_configs = {}

local function get_team_dungeon_config(dungeon_id)
    return team_dungeon_configs[dungeon_id]
end

local function get_team_dungeon_scene_setting(dungeon_id)
    local team_dungeon_config = get_team_dungeon_config(dungeon_id)
    if team_dungeon_config == nil then
        return
    end
    return challenge_team_dungeon[team_dungeon_config.SceneSetting]
end

local function get_challenge_team_dungeon_table()
    return challenge_team_dungeon
end

local MAX_LEVEL_CONFIG


--是否可以进入副本
local function is_dungeon_enterable(captain, team, target)
    target = target or team.target
    if target == nil or target == "free" then
        return const.error_team_no_target
    end
    local dungeon_cfg = brief_config[target]
    if dungeon_cfg == nil then
        return const.error_team_dungeon_not_exist
    end
    local level_need = dungeon_cfg.Level
    local scene_id = captain.scene_id
    local config = cost_config[dungeon_cfg.Chapter]
    local tili_cost = config.Cost
    local need_member_num = config.Mintime
    if #team.members < need_member_num then
        return const.error_team_member_number_not_enough
    end

    local failed_player = {}
    local player_cache = {}
    for _, v in pairs(team.members) do
        local player = online_user.get_user(v.actor_id)
        player_cache[v.actor_id] = player

        if player == nil then
            table.insert(failed_player, player.actor_id)
        end
    end
    if not table.isEmptyOrNil(failed_player) then
        return const.error_team_member_not_in_same_game_server, failed_player
    end

    for _, v in pairs(team.members) do
        local player = player_cache[v.actor_id]

        if player.scene_id ~= scene_id then
            table.insert(failed_player, player.actor_id)
        end
    end
    if not table.isEmptyOrNil(failed_player) then
        return const.error_team_member_not_in_same_scene, failed_player
    end

    for _, v in pairs(team.members) do
        local player = player_cache[v.actor_id]

        if player.level < level_need then
            table.insert(failed_player, player.actor_id)
        end
    end
    if not table.isEmptyOrNil(failed_player) then
        return const.error_team_member_level_not_match, failed_player
    end

    for _, v in pairs(team.members) do
        local player = player_cache[v.actor_id]

        if not player:is_resource_enough("tili", tili_cost) then
            table.insert(failed_player, player.actor_id)
        end
    end
    if not table.isEmptyOrNil(failed_player) then
        return const.error_team_member_tili_not_enough, failed_player
    end

    for _, v in pairs(team.members) do
        local player = player_cache[v.actor_id]

        if player.dungeon_in_playing ~= const.DUNGEON_NOT_EXIST then
            table.insert(failed_player, player.actor_id)
        end
    end
    if not table.isEmptyOrNil(failed_player) then
        return const.error_team_member_already_in_dungeon, failed_player
    end

    for _, v in pairs(team.members) do
        local player = player_cache[v.actor_id]

        if player.dead_time ~= -1 then
            table.insert(failed_player, player.actor_id)
        end
    end
    if not table.isEmptyOrNil(failed_player) then
        return const.error_team_member_is_dead, failed_player
    end

    return 0
end

local function get_dungeon_cost(target)
    local dungeon_cfg = brief_config[target]
    if dungeon_cfg == nil then
        flog("error", "get_dungeon_cost : error target "..target)
        return
    end

    return cost_config[dungeon_cfg.Chapter].Cost
end

local function get_dungeon_no_reward_times(target)
    local dungeon_cfg = brief_config[target]
    if dungeon_cfg == nil then
        flog("error", "get_dungeon_cost : error target "..target)
        return
    end

    return cost_config[dungeon_cfg.Chapter].Num
end

local function get_dungeon_reward(target)
    local dungeon_cfg = brief_config[target]
    if dungeon_cfg == nil then
        flog("error", "get_dungeon_reward : error target "..target)
        return
    end
    local rewards = {}
    for i = 1, 4 do
        local rwd = dungeon_cfg["Reward"..i]
        if rwd ~= nil and #rwd == 2 then
            rewards[rwd[1]] = rwd[2]
        end
    end
    return rewards
end

local function get_dungeon_unlock_level(target)
    if target == "free" then
        return 0
    end
    local dungeon_cfg = brief_config[target]
    if dungeon_cfg == nil then
        flog("error", "get_dungeon_unlock_level : error target "..target)
        return 0
    end

    return dungeon_cfg.Level
end

local function get_dungeon_time(target)
    local dungeon_cfg = brief_config[target]
    if dungeon_cfg == nil then
        flog("error", "get_dungeon_time : error target "..target)
        return 0
    end

    return dungeon_cfg.Time
end

local function get_chapter_id(target)
    local dungeon_cfg = brief_config[target]
    if dungeon_cfg == nil then
        flog("error", "get_chapter_id : error target "..target)
        return 0
    end

    return dungeon_cfg.Chapter
end

local function get_level_dungeon_chapter()
    return challenge_team_dungeon.Parameter[11].Value[1]
end

local function get_team_dungeon_name(dungeon_id)
    local config = team_dungeon_configs[dungeon_id]
    return get_config_name(config)
end

local function reload()
    --检查出生点
    for id,v in pairs(challenge_team_dungeon.TeamDungeons) do
        if v.SceneSetting == nil or v.SceneSetting == "" then
            flog("warn","challenge_team_dungeon can not have SceneSetting id "..id..",SceneSetting "..v.SceneSetting)
        else
            local find = false
            for id1,v1 in pairs(challenge_team_dungeon[v.SceneSetting]) do
                --flog("info","id "..id1..",SceneSetting "..v.SceneSetting)
                if v1.Type == const.ENTITY_TYPE_BIRTHDAY_POS then
                    find = true
                    break
                end
            end
            if find == false then
                flog("error","can not find birth position in team dungeon,id "..id)
            end
        end
    end

    team_dungeon_configs = {}
    for _,config in pairs(challenge_team_dungeon.TeamDungeons) do
        team_dungeon_configs[config.ID] = config
    end

    MAX_LEVEL_CONFIG = challenge_team_dungeon.Parameter[6]
end

reload()

return {
    get_team_dungeon_config = get_team_dungeon_config,
    get_challenge_team_dungeon_table = get_challenge_team_dungeon_table,
    get_team_dungeon_scene_setting = get_team_dungeon_scene_setting,
    MAX_LEVEL_CONFIG = MAX_LEVEL_CONFIG,
    reload = reload,
    is_dungeon_enterable = is_dungeon_enterable,
    get_dungeon_cost = get_dungeon_cost,
    get_dungeon_no_reward_times = get_dungeon_no_reward_times,
    get_dungeon_reward = get_dungeon_reward,
    get_dungeon_unlock_level = get_dungeon_unlock_level,
    get_dungeon_time = get_dungeon_time,
    get_chapter_id = get_chapter_id,
    get_level_dungeon_chapter = get_level_dungeon_chapter,
    get_team_dungeon_name = get_team_dungeon_name,
}