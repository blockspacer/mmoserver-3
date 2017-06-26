--------------------------------------------------------------------
-- 文件名:	faction.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/17 0017
-- 描  述:	帮会
--------------------------------------------------------------------

local id_manager = require "idmanager"
local const = require "Common/constant"
local flog = require "basic/log"
local scheme_param = require("data/system_faction").Parameter
local string_utf8len = require("basic/scheme").string_utf8len
local recreate_scheme_table_with_key = require("basic/scheme").recreate_scheme_table_with_key
local pairs = pairs
local onetime_refresher = require("helper/onetime_refresher")
local _get_now_time_second = _get_now_time_second
local table_copy = table.copy
local db_hiredis = require "basic/db_hiredis"
local system_faction_config = require "configs/system_faction_config"
local online_role = require "global_faction/faction_online_user"
local timer = require "basic/timer"

local FACTION_DATABASE_TABLE_NAME = "faction_info"
local INITIAL_FACTION_LEVEL = scheme_param[1].Value
local FACTION_POSITION_NAME_TO_INDEX = const.FACTION_POSITION_NAME_TO_INDEX
local INITIAL_MAX_CONTAIN_NUM = scheme_param[3].Value
local TOTAL_MAX_CONTAIN_NUM = scheme_param[4].Value
local DECLARATION_MAX_WORDS_NUM = scheme_param[7].Value
local MAX_APPLY_NUM = scheme_param[14].Value
local SEVEN_DAYS_SECOND = 604800
local ON_TOP_LAST_HOUR = scheme_param[18].Value
local ON_TOP_LAST_SECOND = ON_TOP_LAST_HOUR * 3600

local faction_global_data = require("global_faction/faction_global_data")
local player_faction_index = faction_global_data.get_player_faction_index()
local player_last_logout_time = faction_global_data.get_player_last_logout_time()


-- 职位对应的操作名
local POSITION_OPERATE_NAME = {
    [20] = "Deputy",
    [30] = "Dhammapala",
    [40] = "Elder",
    [50] = "Starflex",
    [60] = "Elite",
    [70] = "Member",
}
local CHIEF_POSTION = 10
local FACTION_VALUE_LIST = const.FACTION_VALUE_LIST


--- 职位数据初始化
local scheme_position = require("data/system_faction").Authority
scheme_position = recreate_scheme_table_with_key(scheme_position, "Position")

local params = {
    faction_name = {db = true, basic = true, brief = true},
    creater_id = {db = true, basic = false, brief = false},
    creater_name = {db = true, basic = false, brief = false},
    chief_id = {db = true, basic = true, brief = true},
    country = {db = true, basic = true, brief = false},
    visual_id = {db = true, basic = true, brief = true},
    faction_id = {db = true, basic = true, brief = true},
    faction_level = {db = true, basic = true, brief = true},
    max_contain_num = {db = true, basic = true, brief = true},
    members_num = {db = true, basic = true, brief = true},
    declaration = {db = true, basic = true, brief = true},
    enemy_faction_id = {db = true, basic = true, brief = false},
    enemy_faction_name = {db = true, basic = true, brief = true},
    activity = {db = true, basic = false, brief = false},
    on_top = {db = true, basic = true, brief = true},
    on_top_expire_time = {db = true, basic = true, brief = false},
    faction_fund = {db = true, basic = true, brief = false},
    total_power = {db = true, basic = true, brief = true},
    faction_enabled = {db=true,basic=true,brief = false,default=true},
    faction_beakup_dissolve_time = {db=true,basic=true,brief = false,deault = 0},
}


local faction = {}
faction.__index = faction

setmetatable(faction, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function faction.__ctor(self)
    self.scene_gameid = 0
    self.members = {}
    self.apply_list = {}
    self.invite_list = {}
    self.buildings = {}

    for i, v in pairs(params) do
        if v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
end

local function check_building_unlock(self)
    if table.isEmptyOrNil(self.buildings) then
        self.buildings = {}
        self.buildings[const.FACTION_BUILDING_TYPE.HALL] = {level=1,progress=0,next_upgrade_time=_get_now_time_second(),ranks={} }
    end
    for i=1,self.buildings[const.FACTION_BUILDING_TYPE.HALL].level,1 do
        local cfg = system_faction_config.get_hall_config(i)
        if cfg ~= nil and self.buildings[cfg.UnlockID] == nil then
            for j=1,#cfg.UnlockID,1 do
                if self.buildings[cfg.UnlockID[j]] == nil then
                    self.buildings[cfg.UnlockID[j]] = {level=1,progress=0,next_upgrade_time=_get_now_time_second(),ranks = {} }
                end
            end
        end
    end
end

function faction.create_new_faction(self, creater, faction_name, declaration, visual_id)
    if player_faction_index[creater.actor_id] ~= nil then
        return const.error_already_in_other_faction
    end

    self.faction_name = faction_name
    self.creater_id = creater.actor_id
    self.creater_name = creater.actor_name
    self.chief_id = creater.actor_id
    self.country = creater.country
    self.visual_id = visual_id
    self.faction_id = id_manager.get_valid_uid()
    self.faction_level = INITIAL_FACTION_LEVEL
    local hall_config = system_faction_config.get_hall_config(INITIAL_FACTION_LEVEL)
    self.max_contain_num = hall_config.Number
    self.members_num = 0
    self:add_member(creater)
    self.declaration = declaration
    self.enemy_faction_id = 0
    self.enemy_faction_name = ""
    self.total_power = creater.total_power
    self.faction_fund = system_faction_config.get_faction_init_fund()
    check_building_unlock(self)

    creater.position = FACTION_POSITION_NAME_TO_INDEX.chief
    return 0
end

local function _refresh_enemy_faction(self)
    self.enemy_faction_id = 0
    self.enemy_faction_name = ""
    self.enemy_faction_refresher = nil
end

local function faction_beakup_dissolve_time_handle(self)
    local faction_factory = require "global_faction/faction_factory"
    faction_factory.dissolve_faction(self.faction_id,nil,true)
end

local function remove_faction_breakup_dissolve_timer(self)
    if self.faction_beakup_dissolve_timer ~= nil then
        timer.destroy_timer(self.faction_beakup_dissolve_timer)
        self.faction_beakup_dissolve_timer = nil
    end
    self.faction_beakup_dissolve_time = 0
end

local function add_faction_breakup_dissolve_timer(self)
    if self.faction_beakup_dissolve_timer ~= nil then
        return
    end
    local function dissolve_handle(self)
        faction_beakup_dissolve_time_handle(self)
        remove_faction_breakup_dissolve_timer(self)
    end
    if self.faction_beakup_dissolve_time ~= 0 then
        self.faction_beakup_dissolve_timer = timer.create_timer(dissolve_handle,(self.faction_beakup_dissolve_time-_get_now_time_second())*1000,0)
    end
end

function faction.init_from_dict(self, dict)
    self.members = table_copy(dict.members) or {}
    self.apply_list = table_copy(dict.apply_list) or {}
    self.buildings = table_copy(dict.buildings)
    check_building_unlock(self)

    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    if dict.enemy_faction_last_refresh_time ~= nil then
        self.enemy_faction_refresher = onetime_refresher(_refresh_enemy_faction, dict.enemy_faction_last_refresh_time, SEVEN_DAYS_SECOND)
        self.enemy_faction_refresher:check_refresh(self)
    end
    add_faction_breakup_dissolve_timer(self)
end

function faction.write_to_dict(self, dict)
    if self.enemy_faction_refresher ~= nil then
        local rst, last_refresh_time = self.enemy_faction_refresher:check_refresh(self)
        if rst == false then
            dict.enemy_faction_last_refresh_time = last_refresh_time
        end
    end

    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
    dict.members = table.copy(self.members) or {}
    dict.apply_list = table.copy(self.apply_list) or {}
    dict.buildings = table_copy(self.buildings)
end

function faction.recalc_faction_info(self)
    self.total_power = 0
    for i, v in pairs(self.members) do
        v.total_power = v.total_power or 0
        self.total_power = self.total_power + v.total_power
    end
    self:update_faction_value_to_rank_list("total_power")
end

function faction.get_basic_faction_info(self)
    if self.enemy_faction_refresher ~= nil then
        self.enemy_faction_refresher:check_refresh(self)
    end

    local dict = {}
    for i, v in pairs(params) do
        if v.basic then
            dict[i] = self[i]
        end
    end

    dict.chief_name = self.members[self.chief_id].actor_name

    return dict
end

function faction.get_brief_faction_info(self)
    local dict = {}
    for i, v in pairs(params) do
        if v.brief then
            dict[i] = self[i]
        end
    end

    dict.chief_name = self.members[self.chief_id].actor_name
    return dict
end


function faction.faction_member_addable(self, member_id, country)
    if self.members_num >= self.max_contain_num then
        return const.error_faction_members_is_full
    end

    if player_faction_index[member_id] ~= nil then
        if player_faction_index[member_id] == self.faction_id then
            return const.error_already_in_this_faction
        else
            return const.error_already_in_other_faction
        end
    end
    return 0
end

function faction.add_member(self, new_member)
    local member_id = new_member.actor_id
    local member_country = new_member.country
    local rst = self:faction_member_addable(member_id, member_country)
    if rst ~= 0 then
        return rst
    end

    self.members[member_id] = new_member
    self.members_num = self.members_num + 1
    new_member.position = FACTION_POSITION_NAME_TO_INDEX.crew
    player_faction_index[member_id] = self.faction_id
    return 0
end

local function _remove_member(self, member_id)
    flog("syzDebug", "remove_member "..member_id)

    self.members[member_id] = nil
    self.members_num = self.members_num - 1
    player_faction_index[member_id] = nil
    return 0
end


function faction.add_to_apply_list(self, new_member)
    local rst = self:faction_member_addable(new_member.actor_id, new_member.country)
    if rst ~= 0 then
        return rst
    end
    local num = table.getnum(self.apply_list)
    if num >= MAX_APPLY_NUM then
        return const.error_apply_number_in_list_is_full
    end

    self.apply_list[new_member.actor_id] = new_member

    return 0
end

function faction.is_authority_allow(self, operater_id, operate_name, member_id)
    local operater = self.members[operater_id]
    if operater == nil then
        operater_id = operater_id or nil
        flog("error", "is_authority_allow get wrong operater_id "..operater_id)
        return false
    end
    if member_id ~= nil then
        local member = self.members[member_id]
        if member == nil then
            member_id = member_id or nil
            flog("error", "is_authority_allow get wrong member_id "..member_id)
            return false
        end

        if member.position <= operater.position then
            return false
        end
    end

    local position_config = scheme_position[operater.position]
    if position_config == nil then
        operater.position = operater.position or nil
        flog("error", "is_authority_allow get position_config error, "..operater.position)
        return false
    end

    if position_config[operate_name] == 0 then
        return false
    end

    return true
end


function faction.reply_apply_join_faction(self, operater_id, is_agree, player_id)
    if not self:is_authority_allow(operater_id, "Allaowance") then
        return const.error_no_permission_to_operate
    end

    if is_agree then
        if self.apply_list[player_id] == nil then
            return const.error_applyer_not_in_apply_list
        end

        local rst = self:add_member(self.apply_list[player_id])
        if rst ~= const.error_faction_members_is_full then
            self.apply_list[player_id] = nil
        end

        return rst, self.apply_list
    else
        self.apply_list[player_id] = nil
        return 0, self.apply_list
    end
end

function faction.one_key_reply_all(self, operater_id, is_agree)
    if not self:is_authority_allow(operater_id, "Allaowance") then
        return const.error_no_permission_to_operate
    end

    local new_members = {}
    if is_agree then
        for id, member in pairs(self.apply_list) do
            local rst = self:add_member(member)
            if rst ~= const.error_faction_members_is_full then
                self.apply_list[id] = nil
            end
            if rst == 0 then
                new_members[id] = true
            end
        end
    else
        self.apply_list = {}
    end
    return 0, new_members
end

function faction.kick_faction_member(self, operater_id, member_id)
    if operater_id == member_id then
        return const.error_you_can_not_kick_yourself
    end
    if not self:is_authority_allow(operater_id, "Kick", member_id) then
        return const.error_no_permission_to_operate
    end

    return _remove_member(self, member_id)
end

function faction.invite_faction_member(self, operater_id, new_member)
    if not self:is_authority_allow(operater_id, "Invite") then
        return const.error_no_permission_to_operate
    end

    local rst = self:faction_member_addable(new_member.actor_id, new_member.country)
    if rst ~= 0 then
        return rst
    end
    self.invite_list[new_member.actor_id] = new_member
    return 0, self.faction_name
end

function faction.reply_faction_invite(self, player_id, is_agree)
    if is_agree then
        local be_invited_player = self.invite_list[player_id]
        if be_invited_player == nil then
            return const.error_can_not_find_player_in_invite_list
        end
        self.invite_list[player_id] = nil
        return self:add_member(be_invited_player)
    else
        self.invite_list[player_id] = nil
        return 0
    end
end

function faction.get_player_faction_id(player_id)
    return player_faction_index[player_id]
end

local function release_all_members(self)
    local members = {}
    for id, _ in pairs(self.members) do
        members[id] = true
        _remove_member(self, id)
    end
    return 0, members
end

function faction.dissolve_faction(self, operater_id, is_force)
    flog("info", string.format("dissolve_faction %s by %s", tostring(self.faction_id), tostring(operater_id)))
    if is_force then
        flog("info", "dissolve_faction with force")
    else
        if not self:is_authority_allow(operater_id, "Dissolve") then
            return const.error_no_permission_to_operate
        end

        if self.members_num + self.members_num >= self.max_contain_num then
            return const.error_can_not_dissolve_while_member_more_than_half
        end
    end

    return release_all_members(self)
end

function faction.member_leave_faction(self, member_id)
    if self.chief_id == member_id then
        return const.error_faction_chief_can_not_leave
    end

    return _remove_member(self, member_id)
end

function faction.get_faction_apply_list(self, operater_id)
    if not self:is_authority_allow(operater_id, "Allaowance") then
        return const.error_no_permission_to_operate
    end

    return 0, self.apply_list
end

function faction.set_declaration(self, new_declaration, operater_id)
    if not self:is_authority_allow(operater_id, "Declaration") then
        return const.error_no_permission_to_operate
    end

    if string_utf8len(new_declaration) > DECLARATION_MAX_WORDS_NUM then
        return const.error_too_many_words_num
    end

    self.declaration = new_declaration or ""
    return 0, self:get_basic_faction_info()
end

function faction.set_enemy_faction(self, enemy_faction_id, operater_id, enemy_faction_name)
    if not self:is_authority_allow(operater_id, "SetHostility") then
        return const.error_no_permission_to_operate
    end

    if self.enemy_faction_refresher == nil then
        self.enemy_faction_refresher = onetime_refresher(_refresh_enemy_faction, _get_now_time_second(), SEVEN_DAYS_SECOND)
    else
        self.enemy_faction_refresher:check_refresh(self)
    end

    if self.enemy_faction_id ~= 0 then
        return const.error_already_has_enemy_faction
    end

    self.enemy_faction_id = enemy_faction_id
    self.enemy_faction_name = enemy_faction_name

    return 0, self:get_basic_faction_info()
end

function faction.get_faction_members_info(self)
    local members_info = {}
    for id, member in pairs(self.members) do
        local info = table_copy(member)
        info.last_logout_time = player_last_logout_time[id] or -1
        members_info[id] = info
    end

    return members_info
end

function faction.faction_player_login(player_id)
    player_last_logout_time[player_id] = -1
end

function faction.faction_player_logout(player_id)
    player_last_logout_time[player_id] = _get_now_time_second()
end

local function _get_faction_position_num(self, position)
    local num = 0
    for _, v in pairs(self.members) do
        if v.position == position then
            num = num + 1
        end
    end
    return num
end

function faction.change_position(self, operater_id, member_id, position)
    local operate_name = POSITION_OPERATE_NAME[position]
    if operate_name == nil then
        position = position or "nil"
        flog("warn", "change_position wrong position "..position)
        return const.error_impossible_param
    end

    if not self:is_authority_allow(operater_id, operate_name, member_id) then
        return const.error_no_permission_to_operate
    end

    local max_position_num = scheme_position[position].PositionNum
    local current_position_num = _get_faction_position_num(self, position)
    if current_position_num >= max_position_num then
        return const.error_faction_position_number_full
    end

    local member = self.members[member_id]
    if member == nil then
        member_id = member_id or "nil"
        flog("error", "change_position no member here "..member_id)
        return const.error_impossible_param
    end
    member.position = position
    return 0, self:get_faction_members_info()
end

function faction.buy_faction_on_top(self)
    local current_time = _get_now_time_second()
    if self.on_top_expire_time < current_time then
        self.on_top_expire_time = current_time + ON_TOP_LAST_SECOND
    else
        self.on_top_expire_time = self.on_top_expire_time + ON_TOP_LAST_SECOND
    end

    self.on_top = 1
    return self.on_top_expire_time
end

function faction.check_on_top_time(self)
    local current_time = _get_now_time_second()
    if self.on_top_expire_time < current_time then
        self.on_top = 0
    end
end

function faction.on_inital_global_data()
    player_faction_index = faction_global_data.get_player_faction_index()
    player_last_logout_time = faction_global_data.get_player_last_logout_time()

    for actor_id, _ in pairs(player_last_logout_time) do
        if actor_id ~= "info_name" then
            db_hiredis.hset("actor_all", actor_id, 1)
        end
    end
end

function faction.transfer_chief(self, operater_id, member_id)
    if operater_id ~= self.chief_id then
        return const.error_no_permission_to_operate
    end

    local member = self.members[member_id]
    if member == nil then
        member_id = member_id or "nil"
        flog("error", "transfer_chief no member here "..member_id)
        return const.error_impossible_param
    end
    local old_chief = self.members[operater_id]
    if old_chief == nil then
        operater_id = operater_id or "nil"
        flog("error", "transfer_chief no cheif here "..operater_id)
        return const.error_impossible_param
    end
    old_chief.position = FACTION_POSITION_NAME_TO_INDEX.crew
    member.position = CHIEF_POSTION
    self.chief_id = member_id
    return 0, self:get_faction_members_info()
end

local function _get_max_faction_fund(self)
    local cfg = system_faction_config.get_treasary_config(self.buildings[const.FACTION_BUILDING_TYPE.TREASARY].level)
    if cfg ~= nil then
        return cfg.FundMax
    end
    return 10000000
end

function faction.add_faction_fund(self, count)
    if self.faction_fund >= _get_max_faction_fund() then
        return
    end
    self.faction_fund = self.faction_fund + count
    if self.faction_fund >= _get_max_faction_fund() then
        self.faction_fund = _get_max_faction_fund()
    end
    self:update_faction_value_to_rank_list("faction_fund")
    if not self.faction_enabled then
        self:maintain_handle()
    end
end

function faction.change_faction_name(self, operater_id, new_faction_name)
    if operater_id ~= self.chief_id then
        return const.error_no_permission_to_operate
    end

    self.faction_name = new_faction_name
    return 0, self:get_basic_faction_info()
end

function faction.update_member_info(self, member_info)
    local member_id = member_info.actor_id
    local member = self.members[member_id]
    for i, v in pairs(member_info) do
        member[i] = v
    end
end

function faction.update_faction_value_to_rank_list(self, key)
    local config = FACTION_VALUE_LIST[key]
    if config == nil then
        key = key or "nil"
        flog("error", "faction.update_faction_value_to_rank_list not configed key "..key)
    end
    local value = self[key]
    local rank_set_name = "faction_rank_set_"..key
    db_hiredis.zadd(rank_set_name, value, self.faction_id)
end

function faction.remove_faction_from_rank_list(self)
    for key, _ in pairs(FACTION_VALUE_LIST) do
        local rank_set_name = "faction_rank_set_"..key
        db_hiredis.zrem(rank_set_name, self.faction_id)
    end
end

function faction.get_members(self)
    local members = {}
    for actor_id, _ in pairs(self.members) do
        table.insert(members,actor_id)
    end
    return members
end

local function _get_faction_building_info(self,building_id,actor_id)
    local data = {}
    data.level = self.buildings[building_id].level
    data.progress = self.buildings[building_id].progress
    data.my_rank = 0
    data.next_upgrade_time= self.buildings[building_id].next_upgrade_time or _get_now_time_second()
    data.ranks = {}
    if not table.isEmptyOrNil(self.buildings[building_id].ranks) then
        for _,v in pairs(self.buildings[building_id].ranks) do
            if actor_id == v.actor_id then
                data.my_rank = v.rank
            end
            if v.rank <= 10 then
                data.ranks[v.rank] = table_copy(v)
            end
        end
    end
    return 0,data
end

function faction.on_query_faction_building(self,building_id,actor_id)
    if self.buildings[building_id] == nil then
        return const.error_faction_building_lock
    end
    return _get_faction_building_info(self,building_id,actor_id)
end

function faction.on_investment_faction_building(self,building_id,actor_id,investment_type,investment_count,actor_name)
    flog("tmlDebug","faction.on_investment_faction_building building_id "..building_id..",actor_id "..actor_id)
    if self.buildings[building_id] == nil then
        return const.error_faction_building_lock
    end
    local investment_config = system_faction_config.get_investment_config(investment_count)
    if investment_type == const.FACTION_BUILDING_INVESTMENT_TYPE.fund then
        local member = self.members[actor_id]
        if member == nil then
            return const.error_faction_not_member
        end
        local authority_config = system_faction_config.get_authority_config(member.position)
        if authority_config == nil or investment_count > authority_config.Investment then
            return const.error_faction_fund_invest_count_limit
        end

        if self.faction_fund < investment_config.Cost2[2] then
            return const.error_item_not_enough
        end
        self.faction_fund = self.faction_fund - investment_config.Cost2[2]
    end
    self.buildings[building_id].progress = self.buildings[building_id].progress + investment_config.Exp

    local data = {}
    data.level = self.buildings[building_id].level
    data.progress = self.buildings[building_id].progress
    data.ranks = {}
    data.next_upgrade_time= self.buildings[building_id].next_upgrade_time or _get_now_time_second()

    if investment_type == const.FACTION_BUILDING_INVESTMENT_TYPE.coin then
        local old_investment = 0
        local new_investment = 0
        if self.buildings[building_id].ranks[actor_id] == nil then
            self.buildings[building_id].ranks[actor_id] = {}
            self.buildings[building_id].ranks[actor_id].actor_id = actor_id
            self.buildings[building_id].ranks[actor_id].investment = investment_config.Cost1[2]
            self.buildings[building_id].ranks[actor_id].actor_name = actor_name
        else
            self.buildings[building_id].ranks[actor_id].actor_name = actor_name
            old_investment = self.buildings[building_id].ranks[actor_id].investment
            self.buildings[building_id].ranks[actor_id].investment = old_investment + investment_config.Cost1[2]
        end
         new_investment = self.buildings[building_id].ranks[actor_id].investment

        if self.buildings[building_id].ranks[actor_id].rank == nil then
            local my_rank = 0
            local max_rank = 0
            for aid,rank in pairs(self.buildings[building_id].ranks) do
                if aid ~= actor_id then
                    if rank.investment < new_investment then
                        if my_rank == 0 or my_rank > rank.rank then
                            my_rank = rank.rank
                        end
                        rank.rank = rank.rank + 1
                    end
                    if rank.rank <= 10 then
                        data.ranks[rank.rank] = table_copy(rank)
                    end
                    if max_rank == 0 or max_rank < rank.rank then
                        max_rank = rank.rank
                    end
                end
            end
            if my_rank == 0 then
                my_rank = max_rank + 1
            end
            self.buildings[building_id].ranks[actor_id].rank = my_rank
        else
            local my_rank = self.buildings[building_id].ranks[actor_id].rank
            for aid,rank in pairs(self.buildings[building_id].ranks) do
                if aid ~= actor_id then
                    if rank.investment < new_investment and rank.investemt >= old_investment and rank.rank <= self.buildings[building_id].ranks[actor_id].rank then
                        if my_rank > rank.rank then
                            my_rank = rank.rank
                        end
                        rank.rank = rank.rank + 1
                    end
                    if rank.rank <= 10 then
                        data.ranks[rank.rank] = table_copy(rank)
                    end
                end
            end
            self.buildings[building_id].ranks[actor_id].rank = my_rank
        end
        data.my_rank = self.buildings[building_id].ranks[actor_id].rank
        if data.my_rank <= 10 then
            data.ranks[data.my_rank] = table_copy(self.buildings[building_id].ranks[actor_id])
        end
    else
        data.my_rank = 0
        if not table.isEmptyOrNil(self.buildings[building_id].ranks) then
            for _,v in pairs(self.buildings[building_id].ranks) do
                if actor_id == v.actor_id then
                    data.my_rank = v.rank
                end
                if v.rank <= 10 then
                    data.ranks[v.rank] = table_copy(v)
                end
            end
        end
    end
    return 0,data
end

function faction.on_upgrade_faction_building(self,building_id,actor_id)
    if self.buildings[building_id] == nil then
        return const.error_faction_building_lock
    end
    local building_basic_config = system_faction_config.get_building_basic_config(building_id)
    if building_basic_config == nil then
        return const.error_faction_building_lock
    end

    if self.buildings[building_id].level > building_basic_config.MaxLevel then
        return const.error_faction_upgrade_max_level
    end

    local member = self.members[actor_id]
    if member == nil then
        return const.error_faction_not_member
    end
    local authority_config = system_faction_config.get_authority_config(member.position)
    if authority_config == nil or authority_config.Update ~= 1 then
        return const.error_faction_upgrade_authority
    end

    if self.buildings[building_id].next_upgrade_time ~= nil and _get_now_time_second() < self.buildings[building_id].next_upgrade_time then
        return const.error_faction_upgrade_cd
    end

    local building_config = nil
    if building_id == const.FACTION_BUILDING_TYPE.HALL then
        building_config = system_faction_config.get_hall_config(self.buildings[building_id].level)
        if building_config == nil then
            return const.error_faction_upgrade_max_level
        end
        local total_level = 0
        for _,building in pairs(self.buildings) do
            total_level = total_level + building.level
        end
        if total_level < building_config.TotalLevel then
            return const.error_faction_upgrade_total_level
        end
    elseif building_id == const.FACTION_BUILDING_TYPE.TREASARY then
        building_config = system_faction_config.get_treasary_config(self.buildings[building_id].level)
    elseif building_id == const.FACTION_BUILDING_TYPE.ALTAR then
        building_config = system_faction_config.get_altar_config(self.buildings[building_id].level)
    else
        return const.error_data
    end
    if self.buildings[building_id].progress < building_config.Exp then
        return const.error_faction_upgrade_progress_not_enough
    end
    self.buildings[building_id].progress = self.buildings[building_id].progress - building_config.Exp
    self.buildings[building_id].level = self.buildings[building_id].level + 1
    self.buildings[building_id].next_upgrade_time = _get_now_time_second() + building_config.Cd

    if building_id == const.FACTION_BUILDING_TYPE.HALL then
        building_config = system_faction_config.get_hall_config(self.buildings[building_id].level)
        if building_config ~= nil then
            self.faction_level = self.buildings[building_id].level
            self.max_contain_num = building_config.Number
        end
        check_building_unlock(self)
    elseif building_id == const.FACTION_BUILDING_TYPE.TREASARY then

    elseif building_id == const.FACTION_BUILDING_TYPE.ALTAR then
        for member_id,_ in pairs(self.members) do
            local member = online_role.get_user(member_id)
            if member ~= nil then
                member:send_message_to_game({func_name="on_updete_faction_altar_level",levle=self.buildings[building_id].level})
            end
        end
    else
        return const.error_data
    end

    return _get_faction_building_info(self,building_id,actor_id)
end

function faction.on_faction_player_init(self,actor_id)
    if self.members[actor_id] == nil then
        return
    end
    if self.buildings[const.FACTION_BUILDING_TYPE.ALTAR] == nil then
        return
    end
    local faction_player = online_role.get_user(actor_id)
    if faction_player ~= nil then
        faction_player:send_message_to_game({func_name="on_faction_player_init_complete",faction_altar_level=self.buildings[const.FACTION_BUILDING_TYPE.ALTAR].level,faction_enabled=self.faction_enabled})
    end
end

function faction.maintain_handle(self)
    local total_maintain_fund = 0
    local building_config = nil
    for id,building in pairs(self.buildings) do
        building_config = nil
        if id == const.FACTION_BUILDING_TYPE.HALL then
            building_config = system_faction_config.get_hall_config(building.level)
        elseif id == const.FACTION_BUILDING_TYPE.TREASARY then
            building_config = system_faction_config.get_treasary_config(building.level)
        elseif id == const.FACTION_BUILDING_TYPE.ALTAR then
            building_config = system_faction_config.get_hall_config(building.level)
        end
        if building_config ~= nil then
            total_maintain_fund = total_maintain_fund + building_config.Cost
        end
    end
    local notice = false
    if self.faction_fund < total_maintain_fund then
        if self.faction_enabled then
            self.faction_enabled = false
            notice = true
            self.faction_beakup_dissolve_time = _get_now_time_second() + system_faction_config.get_faction_breakup_dissolve_time()
            add_faction_breakup_dissolve_timer(self)
        end
    else
        self.faction_fund =  self.faction_fund - total_maintain_fund
        if not self.faction_enabled then
            self.faction_enabled = true
            notice = true
            self.faction_beakup_dissolve_time = 0
            remove_faction_breakup_dissolve_timer(self)
        end
    end
    if notice then
        for member_id,_ in pairs(self.members) do
            local faction_player = online_role.get_user(member_id)
            if faction_player then
                faction_player:send_message_to_game({func_name="on_faction_enable_change",faction_enabled=self.faction_enabled})
            end
        end
    end
end

return faction