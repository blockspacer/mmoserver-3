--------------------------------------------------------------------
-- 文件名:	team_factory.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/5 0005
-- 描  述:	组队管理
--------------------------------------------------------------------

local team_class = require "global_team/team"
local const = require "Common/constant"
local flog = require "basic/log"
local timer = require "basic/timer"
local pairs = pairs

local update_timer = nil
local alive_teams = {}
local auto_apply_waiting_list = {{},{}}
local team_apply_waiting_list = {}
local target_team_list = {{},{}}

local function get_team_by_target(target, country)
    target = target or "free"
    if target == "free" then
        local all_team_list = {}
        for target, target_team_list in pairs(target_team_list[country]) do
            for i, v in pairs(target_team_list) do
                all_team_list[i] = v
            end
        end
        return all_team_list
    else
        return target_team_list[country][target]
    end
end

local function add_team_by_target(target, team_id, country)
    target = target or "free"
    target_team_list[country][target] = target_team_list[country][target] or {}
    target_team_list[country][target][team_id] = true
end

local function remove_team_by_target(target, team_id, country)
    target = target or "free"
    local team_list = target_team_list[country][target]
    if team_list == nil then
        flog("error", "remove_team_by_target: team_list is nil")
        return
    end
    team_list[team_id] = nil
end

local function create_team(captain, target, auto_join)
    local team = team_class()
    local result = team:create_team(captain, target, auto_join)
    if result ~= 0 then
        return result
    end

    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    alive_teams[team_info.team_id] = team
    add_team_by_target(target, team_info.team_id, captain.country)
    return 0, team_info
end

local function release_team(team_id)
    if alive_teams[team_id] == nil then
        return const.error_team_not_exist
    end
    local country = alive_teams[team_id].country
    local target = alive_teams[team_id].target
    remove_team_by_target(target, team_id, country)

    alive_teams[team_id] = nil
    team_apply_waiting_list[team_id] = nil
    return 0
end

local function get_team(team_id)
    return alive_teams[team_id]
end

local function add_to_team_apply_list(player_info, team_id)
    team_apply_waiting_list[team_id] = team_apply_waiting_list[team_id] or {}
    team_apply_waiting_list[team_id][player_info.actor_id] = player_info
end

local function get_team_apply_list(team_id)
    team_apply_waiting_list[team_id] = team_apply_waiting_list[team_id] or {}
    return team_apply_waiting_list[team_id]
end

local function clean_team_apply_list(team_id)
    team_apply_waiting_list[team_id] = {}
end

local function add_to_auto_waiting_list(player_info, target, country)
    auto_apply_waiting_list[country][target] = auto_apply_waiting_list[country][target] or {}
    auto_apply_waiting_list[country][target][player_info.actor_id] = player_info
end

local function get_auto_waiting_list(target, country)
    auto_apply_waiting_list[country][target] = auto_apply_waiting_list[country][target] or {}
    return auto_apply_waiting_list[country][target]
end

local function remove_team_member(team_id, member_id)
    local team = alive_teams[team_id]
    if team == nil then
        return const.error_team_not_exist
    end

    local result, member = team:remove_member(member_id)
    if result ~= 0 then
        return result
    end

    if #team.members == 0 then
        release_team(team_id)
        team = nil
    elseif member_id == team.captain_id then
        team.captain_id = team.members[1].actor_id
    end
    return 0, team, member
end

local function add_team_member(team_id, member_info)
    local team = alive_teams[team_id]
    if team == nil then
        return const.error_team_not_exist
    end
    local result = team:add_member(member_info)
    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    return result, team_info
end

local function set_team_target(team_id, new_target, min_level, max_level)
    if alive_teams[team_id] == nil then
        return const.error_team_not_exist
    end
    local team = alive_teams[team_id]
    local target = team.target
    local country = team.country
    remove_team_by_target(target, team_id, country)
    add_team_by_target(new_target, team_id, country)

    local team_info = {}
    team:set_target(new_target)
    if min_level ~= nil or max_level ~= nil then
        team:set_level(min_level, max_level)
    end
    team:team_write_to_sync_dict(team_info)

    return 0, team_info
end

local function get_team_members(team_id)
    local team = alive_teams[team_id]
    if team == nil then
        return nil
    end
    return team:get_members()
end

local function update()
    for _,team in pairs(alive_teams) do
        team:update()
    end
end

local function create_timer()
    update_timer = timer.create_timer(update,1000,const.INFINITY_CALL)
end

local function update_team_member_info(team_id,actor_id,property_name,value)
    if alive_teams[team_id] ~= nil then
        alive_teams[team_id]:update_team_member_info(actor_id,property_name,value)
    end
end

local function set_altar_spritual_update_flag(team_id)
    if alive_teams[team_id] ~= nil then
        alive_teams[team_id]:set_altar_spritual_update_flag()
    end
end

local function get_team_members_number(team_id)
    if alive_teams[team_id] ~= nil then
        return alive_teams[team_id]:get_team_members_number()
    end
    return 0
end

register_function_on_start(create_timer)

return {
    create_team = create_team,
    release_team = release_team,
    get_team = get_team,
    add_to_team_apply_list = add_to_team_apply_list,
    get_team_apply_list = get_team_apply_list,
    clean_team_apply_list = clean_team_apply_list,
    add_to_auto_waiting_list = add_to_auto_waiting_list,
    get_auto_waiting_list = get_auto_waiting_list,
    remove_team_member = remove_team_member,
    add_team_member = add_team_member,
    set_team_target = set_team_target,
    get_team_by_target = get_team_by_target,
    get_team_members = get_team_members,
    update_team_member_info = update_team_member_info,
    set_altar_spritual_update_flag = set_altar_spritual_update_flag,
    get_team_members_number = get_team_members_number,
}