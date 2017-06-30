--------------------------------------------------------------------
-- 文件名:	imp_faction.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/20 0020
-- 描  述:	帮会模块
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local online_user = require "onlinerole"
local onetime_refresher = require("helper/onetime_refresher")
local _get_now_time_second = _get_now_time_second
local is_command_cool_down = require("helper/command_cd").is_command_cool_down
local center_server_manager = require "center_server_manager"
local daily_refresher = require "helper/daily_refresher"
local common_parameter_formula_config = require "configs/common_parameter_formula_config"
local system_faction_config = require "configs/system_faction_config"

local scheme_param = require("data/system_faction").Parameter
local TRAITOR_PUNISH_HOUR = scheme_param[9].Value
local TRAITOR_PUNISH_SECOND = TRAITOR_PUNISH_HOUR * 3600
local CREATE_FACTION_LEVEL = scheme_param[15].Value
local CREATE_FACTION_COST = scheme_param[16].Value
local MAX_APPLY_NUM_ONE_HOUR = scheme_param[11].Value
local ONE_HOUR_SECOND = 3600
local ON_TOP_COST = scheme_param[17].Value
local SEARCH_COMMAND_CD = scheme_param[12].Value


local params = {
    faction_id = {db = true, sync = true},                                 --所在帮会的id
    traitor_debuff_time = {db = true, sync = false, default = -1},         --叛徒debuff时间
    apply_faction_num = {db = true, sync = false},                         --一小时内已申请帮会数目
    faction_name = {db = true, sync = true, default = ""},                  --所在帮会的名称
    last_refresh_investment_count_time = {db=true,sync=false,default = 0},
    faction_altar_level = {db=true,sync=false,default=1},
    faction_enabled = {db=true,sync=false,default=true},
}

local imp_faction = {}
imp_faction.__index = imp_faction

setmetatable(imp_faction, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_faction.__params = params

function imp_faction.__ctor(self)
    self.faction_scene_gameid = 0
    self.faction_building_investment_counts = {}
    self.faction_building_investment = false
    self.faction_altar_share_spritual = 0
end

local function _refresh_apply_number(self)
    self.apply_faction_num = 0
    self.apply_num_refresher = nil
end

local function _refresh_faction_building_investment_counts(self)
    self.faction_building_investment_counts = {}
end

--根据dict初始化
function imp_faction.imp_faction_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    self.faction_building_investment_counts = table.copy(dict.faction_building_investment_counts) or {}

    if dict.apply_num_last_refresh_time ~= nil then
        self.apply_num_refresher = onetime_refresher(_refresh_apply_number, dict.apply_num_last_refresh_time, ONE_HOUR_SECOND)
        self.apply_num_refresher:check_refresh(self)
    end

    self.faction_building_investment_count_refresh = daily_refresher(_refresh_faction_building_investment_counts, self.last_refresh_investment_count_time, common_parameter_formula_config.DAILY_REFRESH_HOUR, common_parameter_formula_config.DAILY_REFRESH_MIN)
end

function imp_faction.imp_faction_init_from_other_game_dict(self,dict)
    self:imp_faction_init_from_dict(dict)
    self.faction_scene_gameid = dict.faction_scene_gameid
    self.faction_building_investment = dict.faction_building_investment
    self.faction_altar_share_spritual = dict.faction_altar_share_spritual
end

function imp_faction.imp_faction_write_to_dict(self, dict, to_other_game)
    if self.apply_num_refresher ~= nil then
        local rst, last_refresh_time = self.apply_num_refresher:check_refresh(self)
        if rst == false then
            dict.apply_num_last_refresh_time = last_refresh_time
        end
    end
    if self.faction_building_investment_count_refresh ~= nil then
        local rst, last_refresh_investment_count_time = self.faction_building_investment_count_refresh:check_refresh(self)
        if rst == false then
            dict.last_refresh_investment_count_time = last_refresh_investment_count_time
        end
    end
    if to_other_game then
        for i, _ in pairs(params) do
            dict[i] = self[i]
        end
    else
        for i, v in pairs(params) do
            if v.db then
                dict[i] = self[i]
            end
        end
    end
end

function imp_faction.imp_faction_write_to_other_game_dict(self,dict)
    self:imp_faction_write_to_dict(dict, true)
    dict.faction_scene_gameid = self.faction_scene_gameid
    dict.faction_building_investment = self.faction_building_investment
    dict.faction_altar_share_spritual = self.faction_altar_share_spritual
end

function imp_faction.imp_faction_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
end

local function _make_basic_info(self, input)
    input.actor_id = self.actor_id
    input.actor_name = self.actor_name
    input.level = self.level
    input.country = self.country
    input.vocation = self.vocation
    input.faction_id = self.faction_id
    input.total_power = self.total_power
    input.sex = self.sex
end

local function _faction_joinable(self)
    if self.faction_id ~= 0 then
        return const.error_already_has_faction
    end

    local current_time = _get_now_time_second()
    if current_time > self.traitor_debuff_time + TRAITOR_PUNISH_SECOND then
        return 0
    else
        return const.error_traitor_debuff_time_can_not_join_faction
    end
end

local function _join_faction(self, faction_id, faction_name)
    self:_set("faction_id", faction_id)
    self:_set("faction_name", faction_name)
    local syn_data = {}
    self:imp_faction_write_to_sync_dict(syn_data)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE, syn_data)
    self:update_player_info_to_arena("union_name",self.faction_name)
end

local function _leave_faction(self, is_traitor)
    self:_set("faction_id", 0)
    self:_set("faction_name", "")
    if is_traitor then
        self.traitor_debuff_time = _get_now_time_second()
    end
    local syn_data = {}
    self:imp_faction_write_to_sync_dict(syn_data)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE, syn_data)
    self:update_player_info_to_arena("union_name","")
end


function imp_faction.join_faction(self, input)
    _join_faction(self, input.faction_id, input.faction_name)
end

function imp_faction.leave_faction(self, input, syn_data)
    _leave_faction(self, input.is_traitor)
end

local function faction_createable(self)
    if self.level < CREATE_FACTION_LEVEL then
        return const.error_level_not_match_create_faction
    end
    if not self:is_resource_enough("ingot", CREATE_FACTION_COST) then
        return const.error_item_not_enough
    end

    return 0
end

function imp_faction.on_create_faction(self, input)
    local result = _faction_joinable(self)
    if result == 0 then
        result = faction_createable(self)
    end

    if result == 0 then
        input.func_name = "create_faction"
        input.self_info = {}
        _make_basic_info(self, input.self_info)
        self:send_message_to_faction_server(input)
    else
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "CreateFactionRet"})
    end
end

function imp_faction.create_faction_success(self, input)
    local faction_info = input.faction_info
    self:remove_resource("ingot", CREATE_FACTION_COST)
    _join_faction(self, faction_info.faction_id, faction_info.faction_name)

    local output = {func_name = "CreateFactionRet", result = 0}
    output.faction_info = faction_info
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function imp_faction.on_dissolve_faction(self, input)
    input.func_name = "dissolve_faction"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_apply_join_faction(self, input)
    if self.apply_num_refresher == nil then
        _refresh_apply_number(self)
        self.apply_num_refresher = onetime_refresher(_refresh_apply_number, _get_now_time_second(), ONE_HOUR_SECOND)
    else
        self.apply_num_refresher:check_refresh(self)
    end

    if self.apply_faction_num >= MAX_APPLY_NUM_ONE_HOUR then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_apply_too_many_in_one_hour, func_name = "ApplyJoinFactionRet"})
    end
    self.apply_faction_num = self.apply_faction_num + 1

    local result = _faction_joinable(self)
    if result == 0 then
        input.func_name = "apply_join_faction"
        input.self_info = {}
        _make_basic_info(self, input.self_info)
        self:send_message_to_faction_server(input)
    else
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "ApplyJoinFactionRet"})
    end
end

function imp_faction.on_one_key_apply_join_faction(self, input)
    if self.apply_num_refresher == nil then
        _refresh_apply_number(self)
        self.apply_num_refresher = onetime_refresher(_refresh_apply_number, _get_now_time_second(), ONE_HOUR_SECOND)
    else
        self.apply_num_refresher:check_refresh(self)
    end

    local faction_id_list = input.faction_id_list
    local apply_num = #faction_id_list
    if self.apply_faction_num + apply_num > MAX_APPLY_NUM_ONE_HOUR then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_apply_too_many_in_one_hour, func_name = "OneKeyApplyJoinFactionRet"})
    end
    self.apply_faction_num = self.apply_faction_num + apply_num

    local result = _faction_joinable(self)
    if result == 0 then
        input.func_name = "one_key_apply_join_faction"
        input.self_info = {}
        _make_basic_info(self, input.self_info)
        self:send_message_to_faction_server(input)
    else
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "OneKeyApplyJoinFactionRet"})
    end
end

function imp_faction.on_reply_apply_join_faction(self, input)
    input.func_name = "reply_apply_join_faction"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_one_key_reply_all(self, input)
    input.func_name = "one_key_reply_all"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_kick_faction_member(self, input)
    input.func_name = "kick_faction_member"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_invite_faction_member(self, input)
    local member_id = input.member_id

    local rpc_data = {func_name = "be_invited_to_faction", actor_id = member_id }
    rpc_data.inviter_id = self.actor_id
    rpc_data.inviter_name = self.actor_name
    rpc_data.inviter_faction_id = self.faction_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, rpc_data)
end

function imp_faction.be_invited_to_faction(self, input)
    local inviter_id = input.inviter_id
    local inviter_name = input.inviter_name
    local inviter_faction_id = input.inviter_faction_id

    local result = _faction_joinable(self)
    if result == 0 then
        input.func_name = "be_invited_to_faction"
        input.member_info = {}
        _make_basic_info(self, input.member_info)
        input.operater_name = inviter_name
        input.operater_id = inviter_id
        input.faction_id = inviter_faction_id
        self:send_message_to_faction_server(input)
    else
        local rpc_data = {result = result, func_name = "InviteFactionMemberRet", actor_id = inviter_id}
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, rpc_data)
    end
end

function imp_faction.on_reply_faction_invite(self, input)
    input.func_name = "reply_faction_invite"
    input.player_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_member_leave_faction(self, input)
    input.func_name = "member_leave_faction"
    input.faction_id = self.faction_id
    input.member_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_get_faction_apply_list(self, input)
    input.func_name = "get_faction_apply_list"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_set_declaration(self, input)
    input.func_name = "set_declaration"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_set_enemy_faction(self, input)
    input.func_name = "set_enemy_faction"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_get_faction_members_info(self, input)
    input.func_name = "get_faction_members_info"
    input.faction_id = self.faction_id
    self:send_message_to_faction_server(input)
end

local function on_player_login(self, input)
    local output = {}
    output.func_name = "faction_player_login"
    output.faction_id = self.faction_id
    output.player_id = self.actor_id

    output.self_info = {}
    _make_basic_info(self, output.self_info)
    self:send_message_to_faction_server(output)
end

local function on_logout(self, input)
    local output = {}
    output.func_name = "faction_player_logout"
    output.faction_id = self.faction_id
    output.player_id = self.actor_id
    self:send_message_to_faction_server(output)
end

function imp_faction.on_change_position(self, input)
    input.func_name = "change_position"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_get_faction_list(self, input)
    input.func_name = "get_faction_list"
    input.country = self.country
    self:send_message_to_faction_server(input)
end

function imp_faction.on_get_random_faction_list(self, input)
    input.func_name = "get_random_faction_list"
    input.country = self.country
    self:send_message_to_faction_server(input)
end

function imp_faction.on_search_faction(self, input)
    local result = is_command_cool_down(self.actor_id, "search_faction", SEARCH_COMMAND_CD)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_search_not_cool_down, func_name = "SearchFactionRet"})
        return
    end

    input.func_name = "search_faction"
    input.country = self.country
    self:send_message_to_faction_server(input)
end

function imp_faction.on_buy_faction_on_top(self, input)
    if not self:is_resource_enough("ingot", ON_TOP_COST) then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_item_not_enough, func_name = "BuyFactionOnTopRet"})
    end

    self:remove_resource("ingot", ON_TOP_COST)
    input.func_name = "buy_faction_on_top"
    input.country = self.country
    input.faction_id = self.faction_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_get_basic_faction_info(self, input)
    input.func_name = "get_basic_faction_info"
    input.faction_id = self.faction_id
    self:send_message_to_faction_server(input)
end

function imp_faction.on_change_faction_name(self, input)
    input.func_name = "change_faction_name"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.is_have_faction(self)
    return self.faction_id ~= 0
end

function imp_faction.on_transfer_chief(self, input)
    input.func_name = "transfer_chief"
    input.faction_id = self.faction_id
    input.operater_id = self.actor_id
    self:send_message_to_faction_server(input)
end

function imp_faction.change_faction_name(self, input)
    local faction_name = input.faction_name
    flog("syzDebug", "change_faction_name "..faction_name)
    self:_set("faction_name", faction_name)
    self:update_player_info_to_arena("union_name",self.faction_name)
end

function imp_faction.on_query_faction_building(self,input)
    --一般情况下，只能在帮派领地投资
    if self.in_fight_server then
        return
    end
    if input.building_id == nil or system_faction_config.check_building(input.building_id) == false then
        flog("debug","imp_faction.on_query_faction_building building type error!")
        return
    end
    if not self:is_have_faction() then
        flog("debug","imp_faction.on_query_faction_building no faction!")
        return
    end

    self.faction_building_investment_count_refresh:check_refresh(self)
    input.faction_id = self.faction_id
    if self.faction_building_investment_counts[input.building_id] == nil then
        self.faction_building_investment_counts[input.building_id] = 0
    end
    input.investment_count = self.faction_building_investment_counts[input.building_id]
    self:send_message_to_faction_server(input)
end

function imp_faction.on_investment_faction_building(self,input)
    --一般情况下，只能在帮派领地投资
    if self.in_fight_server then
        return
    end
    if self.faction_building_investment then
        flog("debug","faction_building_investment is true")
        return
    end

    if input.building_id == nil or system_faction_config.check_building(input.building_id) == false or input.investment_type == nil then
        flog("debug","imp_faction.on_investment_faction_building building type error!")
        return
    end

    if not self:is_have_faction() then
        flog("debug","imp_faction.on_investment_faction_building no faction!")
        return
    end

    self.faction_building_investment_count_refresh:check_refresh(self)

    if self.faction_building_investment_counts[input.building_id] == nil then
        self.faction_building_investment_counts[input.building_id] = 0
    end
    --确认花费
    input.investment_count = self.faction_building_investment_counts[input.building_id] + 1

    local cost_config = system_faction_config.get_investment_config(input.investment_count)
    if cost_config == nil then
        flog("tmlDebug","imp_faction.on_investment_faction_building cost_config == nil coin_count "..(self.faction_building_investment_counts[input.building_id]+1))
        return
    end
    if input.investment_type == const.FACTION_BUILDING_INVESTMENT_TYPE.coin then
        if not self:is_enough_by_id(cost_config.Cost1[1],cost_config.Cost1[2]) then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnInvestmentFactionBuildingRet",error=const.error_item_not_enough})
            return
        end
        self:remove_item_by_id(cost_config.Cost1[1],cost_config.Cost1[2])
    end
    input.faction_id = self.faction_id
    input.actor_name = self.actor_name
    self.faction_building_investment = true
    self:send_message_to_faction_server(input)
end

function imp_faction.on_investment_faction_building_ret(self,input,sync_data)
    self.faction_building_investment = false
    local investment_count = self.faction_building_investment_counts[input.building_id] + 1
    local cost_config = system_faction_config.get_investment_config(investment_count)
    if cost_config == nil then
        return
    end
    if input.result ~= 0 then
        if input.investment_type == const.FACTION_BUILDING_INVESTMENT_TYPE.coin then
            local rewards = {}
            rewards[cost_config.Cost1[1]] = cost_config.Cost1[2]
            self:add_new_rewards(rewards)
        end
        return
    else
        self.faction_building_investment_count_refresh:check_refresh(self)
        self.faction_building_investment_counts[input.building_id] = self.faction_building_investment_counts[input.building_id] + 1
    end

    self:imp_assets_write_to_sync_dict(sync_data)
    --一般情况下，只能在帮派领地投资
    if self.in_fight_server then
        return
    end
    local puppet = self:get_puppet()
    if puppet == nil then
        return
    end
    local skill_manager = puppet.skillManager
    if skill_manager ~= nil then
        skill_manager:AddBuff(system_faction_config.get_investment_buff_id())
    end
end

function imp_faction.on_upgrade_faction_building(self,input)
    --一般情况下，只能在帮派领地投资
    if self.in_fight_server then
        return
    end
    if input.building_id == nil or system_faction_config.check_building(input.building_id) == false then
        flog("debug","imp_faction.on_query_faction_building building type error!")
        return
    end
    if not self:is_have_faction() then
        flog("debug","imp_faction.on_query_faction_building no faction!")
        return
    end

    self.faction_building_investment_count_refresh:check_refresh(self)
    input.faction_id = self.faction_id
    if self.faction_building_investment_counts[input.building_id] == nil then
        self.faction_building_investment_counts[input.building_id] = 0
    end
    input.investment_count = self.faction_building_investment_counts[input.building_id]
    self:send_message_to_faction_server(input)
end

function imp_faction.on_updete_faction_altar_level(self,input)
    self.faction_altar_level = input.level
    if self:is_in_team() then
        self:send_message_to_team_server({func_name="update_team_member_info",property_name="faction_altar_level",value=self:get_faction_altar_level()})
    end
end

function imp_faction.get_faction_altar_share_spritual(self)
    if not self:is_in_team() then
        return 0
    end
    return self.faction_altar_share_spritual
end

function imp_faction.on_update_faction_altar_share_spritual(self,input)
    self.faction_altar_share_spritual = input.spritual
    self:recalc()
end

function imp_faction.get_faction_altar_level(self)
    if not self.action_enabled then
        return 0
    end
    return self.faction_altar_level
end

function imp_faction.on_faction_player_init_complete(self,input)
    local notice_team = false
    if self.faction_altar_level ~= input.faction_altar_level then
        self.faction_altar_level = input.faction_altar_level
        notice_team = true
    end

    if self.faction_enabled ~= input.faction_enabled then
        self.action_enabled = input.faction_enabled
        notice_team = true
    end
    if notice_team and self:is_in_team() then
        self:send_message_to_team_server({func_name="update_team_member_info",property_name="faction_altar_level",value=self:get_faction_altar_level()})
    end
end

function imp_faction.on_faction_enable_change(self,input)
    self.faction_enabled = input.faction_enabled
    if self:is_in_team() then
        self:send_message_to_team_server({func_name="update_team_member_info",property_name="faction_altar_level",value=self:get_faction_altar_level()})
    end
    if self.faction_enabled then
        self:send_system_message_by_id(const.SYSTEM_MESSAGE_ID.system_faction_recovery,nil,nil,self.faction_name)
    else
        self:send_system_message_by_id(const.SYSTEM_MESSAGE_ID.system_faction_breakup,nil,nil,self.faction_name)
    end
end

register_message_handler(const.CS_MESSAGE_LUA_LOGIN, on_player_login)
register_message_handler(const.SS_MESSAGE_LUA_USER_LOGOUT, on_logout)

imp_faction.__message_handler = {}
imp_faction.__message_handler.on_player_login = on_player_login
imp_faction.__message_handler.on_logout = on_logout

return imp_faction