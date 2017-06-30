--------------------------------------------------------------------
-- 文件名:	player.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/2
-- 描  述:	组队玩家
--------------------------------------------------------------------
local net_work = require "basic/net"
local send_to_game = net_work.forward_message_to_game
local send_to_client = net_work.send_to_client
local const = require "Common/constant"
local flog = require "basic/log"
local team_factory = require "global_team/team_factory"
local send_to_global = net_work.forward_message_to_global
local TIME_WAIT_CONFIRM = 10        --组队进副本等待时间
local objectid = objectid
local send_message_to_fight = net_work.send_message_to_fight
local get_fight_server_info = require("basic/common_function").get_fight_server_info
local center_server_manager = require "center_server_manager"
local onlineuser = require "global_team/team_online_user"
local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"

local team_player = {}
team_player.__index = team_player

setmetatable(team_player, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function team_player.__ctor(self)
end

local function send_to_all_member_game(team_members, data, except_id)
    for _ , v in pairs(team_members) do
        if v.actor_id ~= except_id then
            data.actor_id = v.actor_id
            center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)
        end
    end
end

local function send_to_all_member_client(team_members, key_action, data, except_id)
    for _ , v in pairs(team_members) do
        if v.actor_id ~= except_id then
            send_to_client(v.session_id, key_action, data)
        end
    end
end

function team_player.on_team_player_init(self, input)
    self.session_id = tonumber(input.session_id)
    self.actor_id = input.actor_id
    self.game_id = input.actor_game_id
    return true
end

local function _sync_team_info(team, is_member_changed, team_info)
    if team_info == nil then
        team_info = {}
        team:team_write_to_sync_dict(team_info)
    end
    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetTeamInfoRet", team_info=team_info})
    if is_member_changed then
        send_to_all_member_game(team.members, {func_name = "on_team_member_changed", team_info=team_info})
    end
end

local function _change_captain(old_captain, team)
    local data = {actor_id = old_captain.actor_id, func_name = "on_captain_relieved", team_id = team.team_id}
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)
    data.actor_id = team.captain_id
    data.func_name = "team_captain_changed"
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)

    local members = team.members
    local followers = {}
    for _, v in pairs(members) do
        v.team_state = "auto"
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)

    send_to_all_member_game(team.members, {result = 0, func_name = "CancelFollowCaptain", captain_id = old_captain.actor_id, team_info = team_info, team_state = "auto"})
    send_to_all_member_client(members, const.SC_MESSAGE_LUA_GAME_RPC,  {result = 0, func_name = "ChangeCaptainRet", new_captain_id = team.captain_id, team_info = team_info})
    _sync_team_info(team, true, team_info)
end

function team_player.on_team_player_logout(self, input)
    local auto_apply_target = input.auto_apply_target
    local apply_team_list = input.apply_team_list
    local actor_id = input.actor_id
    local country = input.country
    local team_id = input.team_id
    if auto_apply_target ~= 0 then
        local waiting_list = team_factory.get_auto_waiting_list(auto_apply_target, country)
        waiting_list[actor_id] = nil
    end
    for team_id, v in pairs(apply_team_list) do
        local apply_list = team_factory.get_team_apply_list(team_id)
        if apply_list ~= nil then
            apply_list[actor_id] = nil
        end
    end
    local team = team_factory.get_team(team_id)
    if team ~= nil then
        local is_captain_change, old_captain = team:member_logout(actor_id)
        if is_captain_change then
            _change_captain(old_captain, team)
        else
            _sync_team_info(team, false)
        end
    end

    onlineuser.del_user(input.actor_id)
end

function team_player.on_message(self, key_action, input)
    if key_action == const.GT_MESSAGE_LUA_GAME_RPC then
        local func_name = input.func_name
        if func_name == nil or self[func_name] == nil then
            func_name = func_name or "nil"
            flog("error", "team_player.on_message GT_MESSAGE_LUA_GAME_RPC: no func_name  "..func_name)
            return
        end
        flog("info", "GT_MESSAGE_LUA_GAME_RPC func_name "..func_name)
        self[func_name](self, input)
    end
end


local function send_to_captain_client(team_members, key_action, data)
    send_to_client(team_members[1].session_id, key_action, data)
end

local function send_to_captain_game(team_members, key_action, data)
    local captain = team_members[1]
    data.actor_id = captain.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)
end

local function basic_check(team_id, actor_id, permission, country, ignore_sign)
    local team = team_factory.get_team(team_id)
    if team == nil then
        return const.error_team_not_exist
    end
    if permission == "captain_only" then
        if actor_id ~= team.captain_id then
            return const.error_no_permission_to_operate
        end
    elseif permission == "not_captain" then
        if actor_id == team.captain_id then
            return const.error_team_captain_cannot_operate
        end
    end
    if country ~= team.country then
        return const.error_country_different
    end
    if team.sure_sign and not ignore_sign then
        return const.error_team_is_waiting_dungeon_start
    end

    return 0
end


function team_player.team_reconnect(self, input)
    local team_id = input.team_id
    local game_id = input.game_id
    local actor_id = input.actor_id
    local team = team_factory.get_team(team_id)
    if team == nil then
        send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = const.error_team_not_exist, func_name = "team_reconnect_ret"})
        return
    end

    local member = team:member_reconnect(actor_id)
    if member == nil then
        send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = const.error_team_member_not_exist, func_name = "team_reconnect_ret"})
        return
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = 0, func_name = "team_reconnect_ret", team_info = team_info})
end

local function create_team_member_info(session_id, input)
    local info = {session_id = session_id }
    info.actor_name = input.actor_name
    info.actor_id = input.actor_id
    info.level = input.level
    info.country = input.country
    info.vocation = input.vocation
    info.sex = input.sex
    info.scene_id = input.scene_id
    info.current_hp = input.current_hp
    info.hp_max = input.hp_max
    info.team_state = input.team_state
    info.is_online = true
    return info
end

local function _add_auto_apply_player(team_id)
    local team = team_factory.get_team(team_id)
    local target = team.target or "free"
    local waiting_list = team_factory.get_auto_waiting_list(target, team.country)
    for id, info in pairs(waiting_list) do
        local data = {actor_id = info.actor_id, func_name = "on_ensure_join_team", team_id=team_id, new_member_id=info.actor_id, target=target}
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)
    end
end

function team_player.make_team(self, input)
    local actor_name = input.actor_name
    local actor_id = input.actor_id
    local level = input.level
    local game_id = input.game_id
    local target = input.target
    local country = input.country

    local auto_join = input.auto_join
    local captain_info = create_team_member_info(self.session_id, input)
    local result, team_info = team_factory.create_team(captain_info, target, auto_join)
    if result ~= 0 then
        send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = result, func_name = "MakeTeamRet"})
    end
    if auto_join then
        _add_auto_apply_player(team_info.team_id)
    end
    send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = result, func_name = "MakeTeamRet", team_info = team_info})
end

function team_player.dissolve_team(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id
    local rst = basic_check(team_id, actor_id, "captain_only", country)
    if rst ~= 0 then
        return send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = rst, func_name = "DissolveTeamRet"})
    end
    local team = team_factory.get_team(team_id)

    local result = team_factory.release_team(team_id)
    if result ~= 0 then
        send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = result, func_name = "DissolveTeamRet"})
    end

    send_to_all_member_game(team.members, {result = result, func_name = "DissolveTeamRet"})
end

function team_player.apply_team(self, input)
    local team_id = input.apply_team_id
    local actor_id = input.actor_id
    local actor_name = input.actor_name
    local level = input.level
    local game_id = input.game_id
    local country = input.country
    local rst = basic_check(team_id, actor_id, "all", country, true)
    if rst ~= 0 then
        return send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = rst, func_name = "ApplyTeamRet"})
    end

    local team = team_factory.get_team(team_id)
    local new_info = create_team_member_info(self.session_id, input)
    local match_rst = team:is_match(new_info)
    if match_rst ~= 0 then
        return send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = match_rst, func_name = "ApplyTeamRet"})
    end
    if team.auto_join then
        local result, team_info = team_factory.add_team_member(team_id, new_info)
        if result ~= 0 then
            flog("error", "team_player.apply_team add_team_member fail!")
            return
        end
        send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = 0, func_name = "JoinTeamRet", team_info=team_info})
        send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "MemberJoinTeam", member_id=actor_id, member_name = actor_name}, actor_id)
        _sync_team_info(team, true)
    else
        team_factory.add_to_team_apply_list(new_info, team_id)
        send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = 0, func_name = "ApplyTeamRet", team_id=team_id})
        send_to_captain_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "PlayerApplyTeam", player_info = new_info})
    end
end

function team_player.get_team_apply_list(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local rst = basic_check(team_id, actor_id, "all", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "GetTeamApplyListRet"})
    end

    local apply_list = team_factory.get_team_apply_list(team_id)
    apply_list = apply_list or {}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "GetTeamApplyListRet", apply_list = apply_list})
end

function team_player.clean_team_apply_list(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local rst = basic_check(team_id, actor_id, "captain_only", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "CleanTeamApplyRet"})
    end
    local team = team_factory.get_team(team_id)

    team_factory.clean_team_apply_list(team_id)
    local apply_list = team_factory.get_team_apply_list(team_id)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "CleanTeamApplyRet", apply_list = apply_list})
end

function team_player.agree_apply(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local new_member_id = input.new_member_id
    local rst = basic_check(team_id, actor_id, "captain_only", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "AgreeApplyRet"})
    end
    local team = team_factory.get_team(team_id)
    local apply_list = team_factory.get_team_apply_list(team_id)

    local new_member = apply_list[new_member_id]
    if new_member == nil then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_member_not_exist, func_name = "AgreeApplyRet"})
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "AgreeApplyRet"})

    local data = {actor_id = new_member.actor_id,func_name = "on_ensure_join_team", team_id=team_id, new_member_id=new_member_id}
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)
end

function team_player.ensure_join_team(self, input)
    local team_id = input.team_id
    local new_member_id = input.new_member_id
    local target = input.target
    local country = input.country

    local team = team_factory.get_team(team_id)
    if team == nil then
        team_id = team_id or 'nil'
        flog("error", "team_player.ensure_join_team, team not exsit: "..team_id)
        return
    end
    if country ~= team.country then
        flog("error", "team_player.ensure_join_team, country not math ")
        return
    end

    local new_member
    local apply_list
    if target == nil then
        apply_list = team_factory.get_team_apply_list(team_id)
        new_member = apply_list[new_member_id]
    else
        apply_list = team_factory.get_auto_waiting_list(target, team.country)
        new_member = apply_list[new_member_id]
    end

    if new_member == nil then
        flog("error", "team_player.ensure_join_team, error_team_member_not_exist")
        return
    end
    local result, team_info = team_factory.add_team_member(team_id, new_member)

    if result ~= 0 then
        return
    end
    apply_list[new_member_id] = nil
    local data = {actor_id = new_member.actor_id, result = result, func_name = "JoinTeamRet", team_info=team_info}
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)

    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "MemberJoinTeam", member_id=new_member_id, member_name = new_member.actor_name}, new_member_id)
    _sync_team_info(team, true)
end

function team_player.exit_team(self, input)
    local team = team_factory.get_team(input.team_id)
    if team == nil then
        send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = const.error_team_not_exist, func_name = "ExitTeamRet"})
        return
    end
    local old_captain_id = team.captain_id
    local result, team, old_captain = team_factory.remove_team_member(input.team_id, input.actor_id)
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = result, func_name = "ExitTeamRet"})
    if team ~= nil then
        local team_info = {}
        team:team_write_to_sync_dict(team_info)
        send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC,  {result = result, func_name = "MemberExitTeam", member_id = input.actor_id})
        if team.captain_id ~= old_captain_id then
            _change_captain(old_captain, team)
        else
            _sync_team_info(team, true, team_info)
        end
    end
end

function team_player.kick_member(self, input)
    local team = team_factory.get_team(input.team_id)
    if team == nil then
        return send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = const.error_team_not_exist, func_name = "KickMemberRet"})
    end
    if input.actor_id ~=  team.captain_id then
        return send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = const.error_no_permission_to_operate, func_name = "KickMemberRet"})
    end
    local result, team, member = team_factory.remove_team_member(input.team_id, input.member_id)
    if result ~= 0 then
        return send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = result, func_name = "KickMemberRet"})
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    --send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "KickMemberRet"})
    local data = {actor_id = member.actor_id, func_name = "BeKickedFromTeam", result = 0, actor_name = member.actor_name}
    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC,  data)
    _sync_team_info(team, true, team_info)

    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)
end

local function _set_target(team_id, target, min_level, max_level)
    local team = team_factory.get_team(team_id)
    if team == nil then
        team_id = team_id or "nil"
        flog("error", "_set_target: team not exsit "..team_id)
        return
    end
    local result, team_info = team_factory.set_team_target(team_id, target, min_level, max_level)
    if result ~= 0 then
        --flog("error", "_set_target fail "..result)
        return result
    end
    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "TargetChanged", target=target, team_info = team_info})
    return 0
end

function team_player.apply_set_target(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id
    local target = input.target
    local min_level = input.min_level
    local max_level = input.max_level

    local rst = basic_check(team_id, actor_id, "captain_only", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "SetTargetRet"})
    end
    local team = team_factory.get_team(team_id)
    min_level = min_level or team.min_level
    max_level = max_level or team.max_level

    local rst = team:apply_member_operate()
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "SetTargetRet"})
    end

    local level_need = challenge_team_dungeon_config.get_dungeon_unlock_level(target)
    local failed_player = {}
    for _ , v in pairs(team.members) do
        if v.level < level_need then
            table.insert(failed_player, v.actor_id)
        end
    end
    local output = {func_name = "SetTargetRet"}
    if not table.isEmptyOrNil(failed_player) then
        output.result = const.error_team_member_level_not_match
        output.failed_player = failed_player
        team:clear_waiting_state()
        return send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    if team.set_target_timer ~= nil then
        Timer.Remove(team.set_target_timer)
        team.set_target_timer = nil
    end
    team.set_target_timer = Timer.Delay(TIME_WAIT_CONFIRM, function()
        team:clear_waiting_state()
        team.set_target_timer = nil
        _set_target(team_id, target, min_level, max_level)
                end)

    team.new_target = target
    team.new_min_level = min_level
    team.new_max_level = max_level
    input.sure_sign = team.sure_sign
    input.is_captain = true
    team_player.agree_set_target(self, input)
    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "ApplySetTarget", sure_sign = team.sure_sign, target=target})
end

local function _start_team_dungeon(team_id, session_id)
    local team = team_factory.get_team(team_id)
    if team == nil then
        return
    end

    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    local fight_server_id,ip,port,token,fight_id = get_fight_server_info(const.FIGHT_SERVER_TYPE.TEAM_DUNGEON)
    if fight_server_id == nil then
        return
    end

    send_message_to_fight(fight_server_id, const.GD_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "on_create_team_dungeon", team_info = team_info,fight_id=fight_id,token=token,fight_type=const.FIGHT_SERVER_TYPE.TEAM_DUNGEON})
    send_to_all_member_game(team.members, {func_name = "on_team_dungeon_start", dungeon_id = team.target,fight_id=fight_id,port=port,ip=ip,token=token,fight_server_id=fight_server_id})
end

function team_player.agree_set_target(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id
    local is_captain = input.is_captain
    local actor_name = input.actor_name

    local sure_sign = input.sure_sign

    local team = team_factory.get_team(team_id)
    if team == nil then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "AgreeSetTargetRet"})
    end

    if not is_captain then
        if sure_sign == -1 or sure_sign == team.sure_sign then
            --send_to_captain_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {sure_sign = sure_sign, member_id = actor_id, member_name = actor_name, func_name = "TeamMemberReplySetTarget"})
            send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {sure_sign = sure_sign, member_id = actor_id, member_name = actor_name, func_name = "TeamMemberReplySetTarget"})
        end
    end

    if sure_sign == -1 then
        if team.set_target_timer ~= nil then
            Timer.Remove(team.set_target_timer)
            team.set_target_timer = nil
        end
        team:clear_waiting_state()
        if is_captain then
            send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {result = input.result, func_name = "SetTargetRet"})
        else
            send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_set_team_target_fail, func_name = "SetTargetRet"})
        end
        return
    end
    local all_ready = team:member_ensure_operate(actor_id, sure_sign)
    if all_ready then
        if team.set_target_timer ~= nil then
            Timer.Remove(team.set_target_timer)
            team.set_target_timer = nil
        end

        _set_target(team_id, team.new_target, team.new_min_level, team.new_max_level)
        team:clear_waiting_state()
    end
end

function team_player.set_auto_join(self, input)
    local team_id = input.team_id
    local auto_join = input.auto_join
    local team = team_factory.get_team(input.team_id)
    if team == nil then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "SetAutoJoinRet"})
    end

    if auto_join then
        if team:is_full() then
            return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_is_full, func_name = "SetAutoJoinRet"})
        else
            _add_auto_apply_player(team_id)
        end
    end
    team.auto_join = auto_join
    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "SetAutoJoinRet", team_info = team_info})
end

function team_player.get_team_info(self, input)
    local team_id = input.team_id
    local team = team_factory.get_team(team_id)
    if team == nil then
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "GetTeamInfoRet"})
        return
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "GetTeamInfoRet", team_info = team_info})
end

function team_player.get_team_list(self, input)
    local target = input.target
    local country = input.country
    if target == nil then
        flog("warn", "get_team_list: target is nil.")
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_impossible_param, func_name = "GetTeamListRet"})
    end
    local team_id_list = team_factory.get_team_by_target(target, country)
    local team_list = {}
    if team_id_list ~= nil then
        for id , _ in pairs(team_id_list) do
            local team = team_factory.get_team(id)
            if team == nil then
                flog("error", "get_team_list: team not exist "..id)
                break
            end
            if not team.in_dungeon or not team:is_full() then
                local team_info = {}
                team:team_write_to_sync_dict(team_info, "brief")
                table.insert(team_list, team_info)
            end
        end
    end

    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "GetTeamListRet", team_list = team_list})
end

function team_player.change_captain(self, input)
    local team_id = input.team_id
    local new_captain_id = input.new_captain_id
    local actor_id = input.actor_id
    local team = team_factory.get_team(team_id)
    if team == nil then
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "ChangeCaptainRet"})
        return
    end
    if actor_id ~= team.captain_id then
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_no_permission_to_operate, func_name = "ChangeCaptainRet"})
        return
    end
    local result, old_captain = team:change_captain_by_id(new_captain_id)
    if result ~= 0 then
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "ChangeCaptainRet"})
        return
    end

    _change_captain(old_captain, team)
end

function team_player.auto_apply_team(self, input)
    local actor_id = input.actor_id
    local actor_name = input.actor_name
    local level = input.level
    local game_id = input.game_id
    local country = input.country

    local target = input.target or "free"

    local player_info = create_team_member_info(self.session_id, input)

    local team_id_list = team_factory.get_team_by_target(target, country)
    local team_list = {}
    local find_team = false
    if team_id_list ~= nil then
        for id , _ in pairs(team_id_list) do
            local team = team_factory.get_team(id)
            if team == nil then
                flog("error", "get_team_list: team not exist "..id)
                break
            end
            if team.auto_join then
                team_factory.add_to_team_apply_list(player_info, team.team_id)
                team_player.ensure_join_team(self, {team_id = team.team_id, new_member_id = actor_id, country = country})
                find_team = true
                break
            end
        end
    end

    if not find_team then
        team_factory.add_to_auto_waiting_list(player_info, target, country)
        send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = 0, func_name = "AutoApplyTeamRet", target = target})
    end
end

function team_player.cancel_auto_apply(self, input)
    local actor_id = input.actor_id
    local target = input.target
    local game_id = input.game_id
    local country = input.country

    local waiting_list = team_factory.get_auto_waiting_list(target, country)
    waiting_list[actor_id] = nil
    send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = 0, func_name = "CancelAutoApplyRet"})
end

function team_player.summon_member(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local rst = basic_check(team_id, actor_id, "captain_only", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "SummonMemberRet"})
    end
    local team = team_factory.get_team(team_id)

    for _, member in pairs(team.members) do
        if member.actor_id ~= team.captain_id then
            member.team_state = "follow"
        end
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)

    send_to_all_member_game(team.members, {result = 0, func_name = "BeFollowCaptain", captain_id = team.captain_id, team_info = team_info, team_state = "follow"}, team.captain_id)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetTeamInfoRet", team_info=team_info})
end

function team_player.release_summon(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local rst = basic_check(team_id, actor_id, "captain_only", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "ReleaseSummonRet"})
    end
    local team = team_factory.get_team(team_id)

    for _, member in pairs(team.members) do
        if member.actor_id ~= team.captain_id then
            member.team_state = "on_hook"
        end
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)

    send_to_all_member_game(team.members, {result = 0, func_name = "CancelFollowCaptain", captain_id = team.captain_id, team_info = team_info, team_state = "on_hook"}, team.captain_id)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetTeamInfoRet", team_info=team_info})
end

function team_player.follow_captain(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id
    local rst = basic_check(team_id, actor_id, "not_captain", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "FollowCaptainRet"})
    end
    local team = team_factory.get_team(team_id)

    for _, member in pairs(team.members) do
        if member.actor_id == actor_id then
            member.team_state = "follow"
            break
        end
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)

    send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = 0, func_name = "BeFollowCaptain", team_state = "follow", captain_id = team.captain_id, team_info = team_info})
    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC,  {result = 0, func_name = "MemberStateChange", team_info = team_info}, actor_id)
end

function team_player.cancel_follow(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id
    local rst = basic_check(team_id, actor_id, "not_captain", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "CancelFollowRet"})
    end
    local team = team_factory.get_team(team_id)

    for _, member in pairs(team.members) do
        if member.actor_id == actor_id then
            member.team_state = "auto"
            break
        end
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = 0, func_name = "CancelFollowCaptain", team_info = team_info, team_state = "auto"})
    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC,  {result = 0, func_name = "MemberStateChange", team_info = team_info}, actor_id)
end

function team_player.change_on_hook(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id
    local rst = basic_check(team_id, actor_id, "all", country)
    if rst ~= 0 then
        return send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = rst, func_name = "ChangeOnHookRet"})
    end

    local team = team_factory.get_team(team_id)

    local new_state
    for _, member in pairs(team.members) do
        if member.actor_id == actor_id then
            if input.b_on_hook then
                new_state = "on_hook"
            else
                new_state = "auto"
            end
            member.team_state = new_state
            break
        end
    end
    if new_state == nil then
        flog("error", "change_on_hook: no member "..actor_id)
        return
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = 0, func_name = "ChangeOnHookRet", team_info = team_info, team_state = new_state})
    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC,  {result = 0, func_name = "MemberStateChange", team_info = team_info}, actor_id)
end

function team_player.team_invite_player(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id

    local invite_player_id = input.invite_player_id

    local team = team_factory.get_team(team_id)
    if team == nil then
        local captain_info = create_team_member_info(self.session_id, input)
        local result, team_info = team_factory.create_team(captain_info, "free", true)
        if result ~= 0 then
            return send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = result, func_name = "MakeTeamRet"})
        end
        team_id = team_info.team_id
        team = team_factory.get_team(team_id)
        send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = result, func_name = "MakeTeamRet", team_info = team_info})
    end

    local rst = basic_check(team_id, actor_id, "captain_only", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "TeamInvitePlayerRet"})
    end

    local rpc_data = {}
    rpc_data.func_name = "on_be_team_invited"
    rpc_data.invite_player_id = invite_player_id
    rpc_data.inviter_id = actor_id
    rpc_data.team_info = {}
    team:team_write_to_sync_dict(rpc_data.team_info)
    rpc_data.actor_id = invite_player_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, rpc_data)
end

function team_player.reply_team_invite(self, input)
    if not input.is_agree then
        return
    end

    local actor_id = input.actor_id
    local team_id = input.reply_team_id
    local country = input.country
    local player_info = create_team_member_info(self.session_id, input)
    local team = team_factory.get_team(team_id)
    team_factory.add_to_team_apply_list(player_info, team.team_id)
    team_player.ensure_join_team(self, {team_id = team.team_id, new_member_id = actor_id, country = country})
end

function team_player.enter_team_dungeon(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id
    local new_target = input.new_target

    local rst = basic_check(team_id, actor_id, "captain_only", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "EnterTeamDungeonRet"})
    end
    local team = team_factory.get_team(team_id)
    local rst = team:apply_member_operate()
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "EnterTeamDungeonRet"})
    end

    if team.enter_dungeon_timer ~= nil then
        Timer.Remove(team.enter_dungeon_timer)
        team.enter_dungeon_timer = nil
    end
    team.enter_dungeon_timer = Timer.Delay(TIME_WAIT_CONFIRM, function()
        flog("syzDebug", "enter_team_dungeon timer refuse")
        local unsure_index = team:get_unsure_members()
        for _, v in pairs(unsure_index) do
            local member = team.members[v]
            send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {sure_sign = -1, member_id = member.actor_id, member_name = member.actor_name, func_name = "TeamMemberReplyEnterDungeon"})
        end

        team:clear_waiting_state()
        team.enter_dungeon_timer = nil
        send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_enter_dungeon_fail, func_name = "EnterTeamDungeonRet"})
                end)

    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    send_to_game(game_id, const.OG_MESSAGE_LUA_GAME_RPC, {actor_id=self.actor_id, result = 0, func_name = "captain_make_sure", team_info = team_info, new_target = new_target})
end

function team_player.update_member_info(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id

    local rst = basic_check(team_id, actor_id, "all", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "GetTeamInfoRet"})
    end

    local team = team_factory.get_team(team_id)
    local member_info = create_team_member_info(self.session_id, input)
    team:update_member_info(actor_id, member_info)
    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetTeamInfoRet", team_info=team_info})
end


function team_player.ensure_enter_dungeon(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id
    local actor_name = input.actor_name
    local failed_player = input.failed_player
    local new_target = input.new_target

    local sure_sign = input.sure_sign
    local is_captain = input.is_captain

    local team = team_factory.get_team(team_id)
    if team == nil then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "EnterTeamDungeonRet"})
    end
    if not is_captain then
        if sure_sign == -1 or sure_sign == team.sure_sign then
            send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {sure_sign = sure_sign, member_id = actor_id, member_name = actor_name, func_name = "TeamMemberReplyEnterDungeon"}, actor_id)
        end
        if sure_sign == team.sure_sign then
            team.new_target = new_target
        end
    end
    if sure_sign == -1 then
        team.new_target = nil
        if team.enter_dungeon_timer ~= nil then
            Timer.Remove(team.enter_dungeon_timer)
            team.enter_dungeon_timer = nil
        end

        team:clear_waiting_state()
        local result = input.result or const.error_team_member_refuse_enter_dungeon
        failed_player = failed_player or {actor_id}
        send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {result = result, failed_player = failed_player, func_name = "EnterTeamDungeonRet"})
        return
    end
    local all_ready = team:member_ensure_operate(actor_id, sure_sign)
    if all_ready then
        if team.enter_dungeon_timer ~= nil then
            Timer.Remove(team.enter_dungeon_timer)
            team.enter_dungeon_timer = nil
        end
        team:clear_waiting_state()

        if team.new_target ~= nil then
            local result = _set_target(team_id, team.new_target)
            if result == 0 then
                _start_team_dungeon(team_id, self.session_id)
            else
                send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "EnterTeamDungeonRet"})
            end
        else
            _start_team_dungeon(team_id, self.session_id)
        end

        team.in_dungeon = true
    end
end


function team_player.end_team_dungeon(self, input)
    local cost_time = input.cost_time
    local team_id = input.team_id
    local win = input.win

    local team = team_factory.get_team(team_id)
    if team == nil then
        team_id = team_id or nil
        flog("error", "end_team_dungeon: team dissolved! "..team_id)
        return
    end
--    local dungeon_id = team.target
--    team.in_dungeon = false
--    send_to_all_member_game(team.members, {func_name = "on_team_dungeon_end", dungeon_id = dungeon_id, cost_time = cost_time, win = win,wave=input.wave,mark=input.mark})

    local output = {func_name = "update_team_dungeon_hegemon" }
    output.team = {}
    team:team_write_to_sync_dict(output.team)
    output.dungeon_id = team.target
    output.time = cost_time
    output.actor_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.ranking_service,const.GR_MESSAGE_LUA_GAME_RPC, output)
end

function team_player.set_team_level(self, input)
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local game_id = input.game_id

    local min_level = input.min_level
    local max_level = input.max_level
    local rst = basic_check(team_id, actor_id, "captain_only", country)
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = rst, func_name = "SetTeamLevelRet"})
    end
    local team = team_factory.get_team(team_id)
    min_level, max_level = team:set_level(min_level, max_level)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "SetTeamLevelRet", min_level = min_level, max_level=max_level})
end

function team_player.start_team_task_dungeon(self,input)
    if input.team_id == nil or input.dungeon_id == nil then
        return
    end
    local team_id = input.team_id
    local team = team_factory.get_team(team_id)
    if team == nil then
        return
    end

    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    local fight_server_id,ip,port,token,fight_id = get_fight_server_info(const.FIGHT_SERVER_TYPE.TASK_DUNGEON)
    if fight_server_id == nil then
        return
    end

    send_message_to_fight(fight_server_id, const.GD_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "on_create_task_dungeon",dungeon_id=input.dungeon_id,actor_id=self.actor_id, team_info = team_info,fight_server_id=fight_server_id,ip=ip,port=port,fight_id=fight_id,token=token,fight_type=const.FIGHT_SERVER_TYPE.TASK_DUNGEON})

    team.in_dungeon = true
end

function team_player.on_create_task_dungeon_complete(self,input)
    if input.team_id == nil or input.dungeon_id == nil or input.fight_id == nil or input.port == nil or input.ip == nil or input.token == nil or input.fight_server_id == nil or input.success == nil or input.fight_type == nil then
        return
    end
    local team_id = input.team_id
    local team = team_factory.get_team(team_id)
    if team == nil then
        return
    end
    send_to_all_member_game(team.members, {func_name = "on_create_task_dungeon_complete", dungeon_id = input.dungeon_id,fight_id=input.fight_id,port=input.port,ip=input.ip,token=input.token,fight_server_id=input.fight_server_id,fight_type=input.fight_type,success=input.success})
end

function team_player.send_message_to_game(self,data)
    data.actor_id = self.actor_id
    send_to_game(self.game_id, const.OG_MESSAGE_LUA_GAME_RPC, data)
end


function team_player.daily_cycle_task_check(self,input)
    flog("tmlDebug","team_player.daily_cycle_task_check")
    if input.flag == nil or input.actors == nil or input.captain_game_id == nil then
        return
    end
    local player = nil
    for actor_id,_ in pairs(input.actors) do
        player = onlineuser.get_user(actor_id)
        if player ~= nil then
            player:send_message_to_game({func_name="on_daily_cycle_task_check",flag=input.flag,captain_game_id=input.captain_game_id,captain_id = self.actor_id})
        end
    end
end


function team_player.on_daily_cycle_task_check_reply(self,input)
    flog("tmlDebug","team_player.on_daily_cycle_task_check_reply")
    if input.flag == nil or input.captain_id == nil or input.captain_game_id == nil or input.result == nil then
        return
    end
    local captain = onlineuser.get_user(input.captain_id)
    if captain ~= nil then
        captain:send_message_to_game({func_name="on_daily_cycle_task_check_reply",flag=input.flag,member_id=self.actor_id,result=input.result})
    end
end

function team_player.on_add_daily_cycle_task(self,input)
    flog("tmlDebug","team_player.on_add_daily_cycle_task")
    if input.daily_cycle_task_id == nil or input.actors == nil then
        return
    end
    local player = nil
    for actor_id,_ in pairs(input.actors) do
        player = onlineuser.get_user(actor_id)
        if player ~= nil then
            player:send_message_to_game({func_name="on_add_daily_cycle_task",daily_cycle_task_id=input.daily_cycle_task_id})
        end
    end
end

function team_player.daily_cycle_task_submit(self,input)
    flog("tmlDebug",'team_player.daily_cycle_task_submit')
    if input.task_id == nil or input.actors == nil then
        return
    end
    local player = nil
    for i=1,#input.actors,1 do
        player = onlineuser.get_user(input.actors[i])
        if player ~= nil then
            player:send_message_to_game({func_name="daily_cycle_task_submit",task_id=input.task_id})
        end
    end
end

function team_player.on_team_member_chat(self,input)
    local members = team_factory.get_team_members(input.team_id)
    if members == nil then
        return
    end

    local player = nil
    for i=1,#members,1 do
        player = onlineuser.get_user(members[i])
        if player ~= nil then
            player:send_message_to_game({func_name="on_team_member_chat",data=input.data})
        end
    end
end

function team_player.on_team_task_dungeon_end(self,input)
    flog("tmlDebug","team_player.on_team_task_dungeon_end team_id "..input.team_id)
    local team_id = input.team_id
    local team = team_factory.get_team(team_id)
    if team == nil then
        return
    end
    team.in_dungeon = false
end

function team_player.on_team_player_game_id_change(self,input)
    flog("tmlDebug","team_player.on_team_player_game_id_change")
    self.game_id = input.actor_game_id
    if input.team_id ~= 0 then
        team_factory.set_altar_spritual_update_flag(input.team_id)
    end
end

function team_player.on_player_session_changed(self, input)
    flog("syzDebug", "team_player.on_player_session_changed")
    local team_id = input.team_id
    local actor_id = input.actor_id
    local new_session_id = tonumber(input.new_session_id)

    if new_session_id == nil then
        flog("error", "on_player_session_changed "..tostring(input.new_session_id))
        return
    end
    self.session_id = new_session_id

    local team = team_factory.get_team(team_id)
    if team == nil then
        return
    end
    for _ , v in pairs(team.members) do
        if v.actor_id == actor_id then
            v.session_id = new_session_id
            break
        end
    end
end

function team_player.summon_single_member(self, input)
    flog("syzDebug", "team_player.summon_single_member")
    local member_id = input.member_id
    local team_id = input.team_id
    local actor_id = input.actor_id
    local country = input.country
    local rst = basic_check(team_id, actor_id, "captain_only", country)
    local output = {result = rst, func_name = "SummonSingleMemberRet"}
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    local team = team_factory.get_team(team_id)
    local is_find = false
    for _, member in pairs(team.members) do
        if member.actor_id == member_id then
            member.team_state = "follow"
            is_find = true
        end
    end
    if not is_find then
        output.result = const.error_team_member_not_exist
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    local team_info = {}
    team:team_write_to_sync_dict(team_info)
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, {actor_id=member_id, result = 0, func_name = "BeFollowCaptain", captain_id = team.captain_id, team_info = team_info, team_state = "follow"})
    send_to_all_member_client(team.members, const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetTeamInfoRet", team_info=team_info}, member_id)
end

function team_player.update_team_member_info(self,input)
    team_factory.update_team_member_info(input.team_id,input.actor_id,input.property_name,input.value)
end

function team_player.on_query_player_info_team_member_count(self,input)
    input.player_info.team_members_number = team_factory.get_team_members_number(input.team_id)
    input.func_name = "on_reply_query_player_info"
    self:send_message_to_game(input)
end

return team_player