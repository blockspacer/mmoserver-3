----------------------------------------------------------------------
-- 文件名:	imp_teamup.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/2
-- 描  述:	组队模块
--------------------------------------------------------------------
local const = require "Common/constant"
local net_work = require "basic/net"
local send_to_global = net_work.forward_message_to_global
local send_to_client = net_work.send_to_client
local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"
local flog = require "basic/log"
local online_user = require "onlinerole"
local INVITE_PLAYER_CD = require("data/challenge_team_dungeon").Parameter[4].Value[1]
local GET_TEAM_INFO_CD = 3      --获取队伍信息cd
local is_command_cool_down = require("helper/command_cd").is_command_cool_down
local fight_data_statistics = require "helper/fight_data_statistics"
--local team_follow = require "helper/team_follow"
local center_server_manager = require "center_server_manager"
local db_hiredis = require "basic/db_hiredis"
local self_game_id = _get_serverid()
local line = require "global_line/line"
local table = table

local params = {
    team_id = {db = true, sync = true},                                 --所在team的id
    auto_apply_target = {db = false, sync = true},                      --正在自动匹配的目标
    team_state = {db = false, sync = true, default = "auto"},           --队伍状态（"follow" 为跟随队长模式，"auto"为自主行动，"on_hook"为挂机）
}

local imp_teamup = {}
imp_teamup.__index = imp_teamup

setmetatable(imp_teamup, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_teamup.__params = params

function imp_teamup.__ctor(self)
    self.apply_team_list = {}
    self.team_members = {}
end

function imp_teamup.get_team_members(self)
    local team_members = {}
    for member_id, _ in pairs(self.team_members) do
        team_members[member_id] = -1
    end
    return team_members
end

local function _make_basic_info(self, input)
    input.actor_id = self.actor_id
    input.actor_name = self.actor_name
    input.level = self.level
    input.country = self.country
    input.vocation = self.vocation
    input.sex = self.sex
    if self.in_fight_server then
        input.scene_id = nil
        input.dungeon_id = self.dungeon_in_playing
    else
        input.scene_id = self:get_aoi_scene_id()
        input.dungeon_id = nil
    end
    input.current_hp = self.current_hp
    input.hp_max = self.hp_max
    input.team_state = self.team_state
    input.faction_id = self.faction_id
    input.faction_altar_level = self:get_faction_altar_level()
    input.real_spritual = self.real_spritual
end

local function _update_member_info(self)
    if self.team_id == 0 then
        return
    end
    local output = {}
    output.func_name = "update_member_info"
    _make_basic_info(self, output)
    output.team_id = self.team_id
    self:send_message_to_team_server(output)
end

local function _tranport_to_team_dungeon_server(self, func_name, output)
    if self.in_fight_server then
        output = output or {}
        output.func_name = func_name
        output.team_id = self.team_id
        _make_basic_info(self, output)
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, output)
        return true
    end
    return false
end

local function _update_members(self, team_info)
    local team_members = team_info.members
    self.team_members = {}
    for i, v in pairs(team_members) do
        self.team_members[v.actor_id] = i
    end
end

local function _left_team(self)
    --team_follow.remove_team_follower(self:get_team_captain(), self)
    _tranport_to_team_dungeon_server(self, "on_fight_avatar_leave_team")
    self.team_id = 0
    self.team_members = {}

    --[[local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:SetTeamId(self.team_id)
    end]]
    self:send_message_to_friend_server({func_name="on_global_left_team"})
    --灵力共享
    self:recalc()
end

local function _join_team(self, team_id)
    self.team_id = team_id
    --[[local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:SetTeamId(self.team_id)
    end]]
    self:send_message_to_friend_server({func_name="on_global_join_team",team_id=team_id})

    --[[if self.team_state == "follow" then
        team_follow.add_team_follower(self:get_team_captain(), self)
    end]]
end

--根据dict初始化
function imp_teamup.imp_teamup_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
end

function imp_teamup.imp_teamup_init_from_other_game_dict(self,dict)
    self:imp_teamup_init_from_dict(dict)
    self.team_state = dict.team_state
    self.apply_team_list = table.copy(dict.apply_team_list)
    self.team_members = table.copy(dict.team_members)
end

function imp_teamup.imp_teamup_write_to_dict(self, dict)
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
end

function imp_teamup.imp_teamup_write_to_other_game_dict(self,dict)
    self:imp_teamup_write_to_dict(dict)
    dict.team_state = self.team_state
    dict.apply_team_list = table.copy(self.apply_team_list)
    dict.team_members = table.copy(self.team_members)
end

function imp_teamup.imp_teamup_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
end

local function on_logout(self, input, syn_data)
    if self.team_id ~= 0 then
        input.func_name = "on_team_player_logout"
        input.team_id = self.team_id
        input.apply_team_list = self.apply_team_list
        input.auto_apply_target = self.auto_apply_target
        _make_basic_info(self, input)
        self:send_message_to_team_server(input)
        --退出时统一退出战斗服
        --_tranport_to_team_dungeon_server(self, "on_logout")
        --[[if self:is_team_captain() then
            team_follow.end_team_follow(self)
        else
            team_follow.remove_team_follower(self:get_team_captain(), self)
        end]]
    end
end

local function on_player_login(self, input, syn_data)
    fight_data_statistics.add_player_data(self.actor_id, self.actor_name, self.vocation)
    if self.team_id ~= 0 then
        local input = {}
        input.func_name = "team_reconnect"
        input.team_id = self.team_id
        _make_basic_info(self, input)
        self:send_message_to_team_server(input)
    end
end

function imp_teamup.team_reconnect_ret(self, input, syn_data)
    if input.result ~= 0 then
        _left_team(self)
    else
        local team_info = input.team_info
        _update_members(self, team_info)
        _join_team(self, team_info.team_id)
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = input.result, func_name = "GetTeamInfoRet", team_info = team_info})
    end
end

function imp_teamup.on_make_team(self, input, syn_data)
    local result = self:is_operation_allowed("make_team")
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "MakeTeamRet"})
    end

    input.func_name = "make_team"
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.MakeTeamRet(self, input, syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    if input.result == 0 then
        self.team_members[self.actor_id] = 1
        _join_team(self, input.team_info.team_id)
    end
end

function imp_teamup.on_dissolve_team(self, input, syn_data)
    if true then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_interface_is_closed, func_name = "AutoApplyTeamRet"})
    end
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "DissolveTeamRet"})
        return
    end
    input.func_name = "dissolve_team"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.DissolveTeamRet(self, input, syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    if input.result == 0 then
        self.team_id = 0
        self.team_members = {}
    end
end

function imp_teamup.on_apply_team(self, input, syn_data)
    local result = self:is_operation_allowed("apply_team")
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "ApplyTeamRet"})
    end

    input.func_name = "apply_team"
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.ApplyTeamRet(self, input, syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    if input.result == 0 then
        self.apply_team_list[input.team_id] = true
    end
end

function imp_teamup.on_agree_apply(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "AgreeApplyRet"})
        return
    end
    input.func_name = "agree_apply"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

--确认加入队伍
function imp_teamup.on_ensure_join_team(self, input, syn_data)
    local result = self:is_operation_allowed("ensure_join_team")
    if result ~= 0 then
        return
    end

    input.func_name = "ensure_join_team"
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end


function imp_teamup.JoinTeamRet(self, input, syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    if input.result == 0 then
        _update_members(self, input.team_info)
        _join_team(self, input.team_info.team_id)
    end
end

function imp_teamup.on_exit_team(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "ExitTeamRet"})
        return
    end
    input.func_name = "exit_team"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.ExitTeamRet(self, input, syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    if input.result == 0 then
        _left_team(self)
    end
end

function imp_teamup.on_kick_member(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "KickMemberRet"})
        return
    end
    input.func_name = "kick_member"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.BeKickedFromTeam(self, input, syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    _left_team(self)
end


function imp_teamup.on_summon_member(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "SummonMemberRet"})
        return
    end
    input.func_name = "summon_member"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_summon_single_member(self, input)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "SummonSingleMemberRet"})
        return
    end
    input.func_name = "summon_single_member"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_follow_captain(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "FollowCaptainRet"})
        return
    end
    if self.team_state == "follow" then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_already_in_follow_state, func_name = "FollowCaptainRet"})
        return
    end
    input.func_name = "follow_captain"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.BeFollowCaptain(self, input, syn_data)
    if input.result == 0 then
        self.team_state = input.team_state
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)

    --[[if input.result == 0 then
        if _tranport_to_team_dungeon_server(self, "on_follow_captain") then
            return
        end
        team_follow.add_team_follower(self:get_team_captain(), self)
    end]]
end

function imp_teamup.on_release_summon(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "ReleaseSummonRet"})
        return
    end
    input.func_name = "release_summon"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_cancel_follow(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "CancelFollowRet"})
        return
    end
    if self.team_state ~= "follow" then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_not_in_follow_state, func_name = "CancelFollowRet"})
        return
    end

    input.func_name = "cancel_follow"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.CancelFollowCaptain(self, input, syn_data)
    --[[if input.result == 0 then

        if _tranport_to_team_dungeon_server(self, "on_cancel_follow") then
            return
        end
        team_follow.remove_team_follower(self:get_team_captain(), self)
    end]]
    if input.result == 0 then
        self.team_state = input.team_state
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
end


function imp_teamup.on_set_target(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "SetTargetRet"})
        return
    end
    input.func_name = "apply_set_target"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_agree_set_target(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "SetTargetRet"})
        return
    end
    input.func_name = "agree_set_target"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_set_auto_join(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "SetAutoJoinRet"})
        return
    end
    input.func_name = "set_auto_join"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end


function imp_teamup.on_change_captain(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "ChangeCaptainRet"})
        return
    end
    input.func_name = "change_captain"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.team_captain_changed(self, input)
    _tranport_to_team_dungeon_server(self, "team_captain_changed", input)
end

function imp_teamup.on_get_team_info(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "GetTeamInfoRet"})
        return
    end

    local result = is_command_cool_down(self.actor_id, "get_team_info", GET_TEAM_INFO_CD)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "GetTeamInfoRet"})
        return
    end
    input.func_name = "get_team_info"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_get_team_list(self, input, syn_data)
    if self.team_id ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_already_in_team, func_name = "GetTeamListRet"})
    end

    input.func_name = "get_team_list"
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_get_team_apply_list(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "GetTeamApplyListRet"})
        return
    end
    input.func_name = "get_team_apply_list"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_clean_team_apply_list(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "CleanTeamApplyListRet"})
        return
    end
    input.func_name = "clean_team_apply_list"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_auto_apply_team(self, input, syn_data)
    if true then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_interface_is_closed, func_name = "AutoApplyTeamRet"})
    end

    if self.team_id ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_already_in_team, func_name = "AutoApplyTeamRet"})
    end
    if self.auto_apply_target ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_already_in_apply, func_name = "AutoApplyTeamRet"})
    end

    input.func_name = "auto_apply_team"
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.AutoApplyTeamRet(self, input, syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    if input.result == 0 then
        self.auto_apply_target = input.target
    end
end

function imp_teamup.on_cancel_auto_apply(self, input, syn_data)
    if self.auto_apply_target == 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_not_in_auto_apply_team, func_name = "CancelAutoApplyRet"})
    end

    input.func_name = "cancel_auto_apply"
    input.target = self.auto_apply_target
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.CancelAutoApplyRet(self, input, syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    if input.result == 0 then
        self.auto_apply_target = 0
    end
end

function imp_teamup.on_change_on_hook(self, input, syn_data)
    if self.team_state == "follow" then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_already_in_follow_state, func_name = "ChangeOnHookRet"})
        return
    end
    if self.team_id ~= 0 then
        input.func_name = "change_on_hook"
        input.team_id = self.team_id
        _make_basic_info(self, input)
        self:send_message_to_team_server(input)
    else
        if input.b_on_hook then
            self.team_state = "on_hook"
        else
            self.team_state = "auto"
        end
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "ChangeOnHookRet"})
    end
end

function imp_teamup.ChangeOnHookRet(self, input, syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    if input.result == 0 then
        self.team_state = input.team_state
    end
end

function imp_teamup.on_team_invite_player(self, input, syn_data)
    --[[ocal result = is_command_cool_down(self.actor_id, "invite_player", INVITE_PLAYER_CD)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "TeamInvitePlayerRet"})
        return
    end]]
    local invite_player_id = input.invite_player_id
    local player = online_user.get_user(invite_player_id)
    local output = {func_name = "TeamInvitePlayerRet"}
    if player == nil then
        output.result = const.error_player_has_left
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    if player.team_id ~= 0 then
        output.result = const.error_already_in_anothor_team
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    if self.country ~= player.country then
        output.result = const.error_country_different
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    input.func_name = "team_invite_player"
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_be_team_invited(self, input, syn_data)
    flog("syzDebug","imp_teamup.on_be_team_invited")
    local team_info = input.team_info
    local rpc_data = {func_name = "TeamInvitePlayerRet", actor_id = input.inviter_id, result = 0}
    if self.team_id ~= 0 then
        rpc_data.result = const.error_already_in_anothor_team
        return center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, rpc_data)
    end

    if self.level < team_info.min_level or self.level > team_info.max_level then
        rpc_data.result = const.error_level_not_match_team
        return center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, rpc_data)
    end
    if self.country ~= team_info.country then
        rpc_data.result = const.error_country_different
        return center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, rpc_data)
    end
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, rpc_data)

    input.func_name = "BeTeamInvited"
    input.result = 0
    input.actor_id = input.invite_player_id
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
end

function imp_teamup.on_reply_team_invite(self, input, syn_data)
    if self.team_id ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_already_in_anothor_team, func_name = "ReplyTeamInviteRet"})
        return
    end

    input.func_name = "reply_team_invite"
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.on_enter_team_dungeon(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "EnterTeamDungeonRet"})
        return
    end
    input.func_name = "enter_team_dungeon"
    _make_basic_info(self, input)
    input.team_id = self.team_id
    self:send_message_to_team_server(input)
end

function imp_teamup.captain_make_sure(self, input, syn_data)
    local team_info = input.team_info
    local new_target = input.new_target
    local output = {func_name = "ensure_enter_dungeon", is_captain = true, new_target = new_target}
    output.team_id = self.team_id
    local result, failed_player = challenge_team_dungeon_config.is_dungeon_enterable(self, team_info, new_target)
    output.result = result
    if result ~= 0 then
        output.sure_sign = -1
        output.failed_player = failed_player
    else
        output.sure_sign = team_info.sure_sign
        _make_basic_info(self, output)
    end

    self:send_message_to_team_server(output)

    if result == 0 then
        for _, v in pairs(team_info.members) do
            local player = online_user.get_user(v.actor_id)
            local enable_reward = player:enable_get_reward(new_target)
            player:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "EnterDungeonMakeSure",
                sure_sign = team_info.sure_sign, enable_reward = enable_reward, new_target = new_target})
        end
    end
end

function imp_teamup.on_ensure_enter_dungeon(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "EnsureEnterDungeonRet"})
        return
    end
    input.func_name = "ensure_enter_dungeon"
    input.team_id = self.team_id
    _make_basic_info(self, input)

    self:send_message_to_team_server(input)
end

function imp_teamup.on_team_member_changed(self, input, syn_data)
    _update_members(self, input.team_info)
end

function imp_teamup.on_set_team_level(self, input, syn_data)
    if self.team_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_team_not_exist, func_name = "SetTeamLevelRet"})
        return
    end
    input.func_name = "set_team_level"
    input.team_id = self.team_id
    _make_basic_info(self, input)
    self:send_message_to_team_server(input)
end

function imp_teamup.imp_teamup_update_current_hp(self)
    _update_member_info(self)
end

function imp_teamup.is_team_captain(self)
    if self.team_members[self.actor_id] == 1 then
        return true
    end
    return false
end

function imp_teamup.get_team_members_number(self)
    return table.getnum(self.team_members)
end

function imp_teamup.is_has_team_member(self)
    local team_num = self:get_team_members_number()
    if team_num > 1 then
        return true
    end
    return false
end

function imp_teamup.get_team_captain(self)
    for id, index in pairs(self.team_members) do
        if index == 1 then
            local player = online_user.get_user(id)
            return player
        end
    end
end

function imp_teamup.get_team_captain_id(self)
    if self.team_id == 0 then
        return nil
    end
    for id, index in pairs(self.team_members) do
        if index == 1 then
            return id
        end
    end
    return nil
end

function imp_teamup.on_init_fight_data_statistics(self, input)
    local init_data = input.init_data
    local start_time = input.start_time
    fight_data_statistics.init_fight_data_statistics(init_data, start_time)
end

function imp_teamup.team_member_fight_data_statistics(self, data_type, value)
    fight_data_statistics.update_fight_data_statistics(self.actor_id, data_type, value)
end

function imp_teamup.on_get_fight_data_statistics(self)
    local team_members = self.team_members
    local captain_id = self.actor_id
    if table.isEmptyOrNil(team_members) then
        team_members = {[self.actor_id] = 1 }
    else
        local captain = self:get_team_captain()
        captain_id = captain.actor_id
    end

    local statistics, start_time = fight_data_statistics.get_fight_data_statistics(team_members, captain_id)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GetFightDataStatisticsRet", statistics = statistics, start_time = start_time})
end

function imp_teamup.on_reset_fight_data_statistics(self)
    if not self:is_team_captain() then
        return
    end
    local team_members = self.team_members
    if table.isEmptyOrNil(team_members) then
        team_members = {[self.actor_id] = 1 }
    end
    local statistics, start_time = fight_data_statistics.reset_fight_data_statistics(team_members)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GetFightDataStatisticsRet", statistics = statistics, start_time = start_time})
end

function imp_teamup.on_captain_relieved(self, input)
    --team_follow.end_team_follow(self)
end

function imp_teamup.is_in_team(self)
    if self.team_id == 0 then
        return false
    else
        return true
    end
end

local function on_scene_loaded(self, input, syn_data)
    _update_member_info(self)
end

--是否跟随
function imp_teamup.is_follow(self)
    if not self:is_in_team() then
        return false
    end

    if self.team_state == "follow" then
        return true
    end
    return false
end

register_message_handler(const.CS_MESSAGE_LUA_LOGIN, on_player_login)
register_message_handler(const.SS_MESSAGE_LUA_USER_LOGOUT, on_logout)
register_message_handler(const.CS_MESSAGE_LUA_LOADED_SCENE, on_scene_loaded)

imp_teamup.__message_handler = {}
imp_teamup.__message_handler.on_player_login = on_player_login
imp_teamup.__message_handler.on_logout = on_logout
imp_teamup.__message_handler.on_scene_loaded = on_scene_loaded

return imp_teamup