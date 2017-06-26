--------------------------------------------------------------------
-- 文件名:	imp_talent.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/6/20 0020
-- 描  述:	天赋
--------------------------------------------------------------------
local const = require "Common/constant"
local growing_talent_config = require "configs/growing_talent_config"
local talent_scheme = growing_talent_config.talent_scheme
local pairs = pairs
local common_parameter_formula_config = require "configs/common_parameter_formula_config"
local math_floor = math.floor

local params = {
    talent_level = {db = true,sync = true, default = 0},  --天赋等级
    talent_sect = {db = true,sync = true, default = -1},  --天赋流派
    exp_consumed = {db = true,sync = false},  --消耗经验
    coin_consumed = {db = true,sync = false},  --消耗铜钱
}

local imp_talent = {}
imp_talent.__index = imp_talent

setmetatable(imp_talent, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_talent.__params = params

function imp_talent.__ctor(self)
    self.actived_talent = {}
end

--根据dict初始化
function imp_talent.imp_talent_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.actived_talent = dict.actived_talent or {}
end

function imp_talent.imp_talent_init_from_other_game_dict(self,dict)
    self:imp_talent_init_from_dict(dict)
end

function imp_talent.imp_talent_write_to_dict(self, dict)
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
    dict.actived_talent = self.actived_talent
end

function imp_talent.imp_talent_write_to_other_game_dict(self,dict)
    self:imp_talent_write_to_dict(dict)
end

function imp_talent.imp_talent_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
    dict.actived_talent = self.actived_talent
end

function imp_talent.on_select_talent_sect(self, input, syn_data)
    local sect = input.sect
    local output = {func_name = "SelectTalentSectRet", sect = sect}
    if self.talent_sect ~= -1 then
        output.result = const.error_already_has_sect
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    self.talent_sect = sect
    output.result = 0
    local talent_info = {}
    self:imp_talent_write_to_dict(talent_info)
    output.talent_info = talent_info
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_talent.on_reselect_talent_sect(self, input, syn_data)
    local new_sect = input.sect
    local output = {func_name = "ReselectTalentSectRet", sect = new_sect}
    if self.talent_sect == -1 then
        output.result = const.error_not_select_sect_yet
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    if self.talent_sect == new_sect then
        output.result = const.error_reselect_same_sect
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    self.talent_sect = new_sect
    self.actived_talent = {}
    self:on_get_talent_info()

    local rewards_back = {}
    local percent = common_parameter_formula_config.talent_consume_return_percent
    rewards_back[const.RESOURCE_NAME_TO_ID.bind_coin] = self.coin_consumed * percent
    rewards_back[const.RESOURCE_NAME_TO_ID.exp] = self.exp_consumed * percent
    self.coin_consumed = 0
    self.exp_consumed = 0
    self:add_new_rewards(rewards_back)
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards_back)
    self:imp_assets_write_to_sync_dict(syn_data)

    local talent_info = {}
    self:imp_talent_write_to_dict(talent_info)
    output.talent_info = talent_info
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end


local function _get_talent_info_from_id(talent_id)
    local itr = math.floor(talent_id / 10)
    local page_index = itr % 10
    itr = math.floor(itr / 10)
    local sect = itr % 10
    itr = math.floor(itr / 10)
    local vocation = itr
    return vocation, sect, page_index
end

local function _is_page_unlock(self, page_index)
    local level_need, talent_level_need = growing_talent_config.get_page_unlock_condition(page_index)
    if self.level < level_need or self.talent_level < talent_level_need then
        return false
    end
    return true
end

function imp_talent.on_upgrade_talent_skill(self, input, syn_data)
    local talent_id = input.talent_id
    local vocation, sect, page_index = _get_talent_info_from_id(talent_id)
    local output = {func_name = "UpgradeTalentSkillRet", result = 0}
    if self.vocation ~= vocation then
        output.result = const.error_vocation_not_match
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    if self.talent_sect ~= sect then
        output.result = const.error_sect_not_match
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    if not _is_page_unlock(self, page_index) then
        output.result = const.error_talent_page_not_unlock
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    local talent_config = talent_scheme[talent_id]
    if talent_config == nil then
        output.result = const.error_no_talent_of_this_id
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    if talent_config.GetLockLevel ~= 0 and self.level < talent_config.GetLockLevel then
        output.result = const.error_talent_not_unlock_yet
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    if talent_config.NeedTalentLv ~= 0 and self.talent_level < talent_config.NeedTalentLv then
        output.result = const.error_talent_not_unlock_yet
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    local slot_level = self.actived_talent[talent_id] or 0
    local consume = growing_talent_config.get_talent_upgrade_consume(talent_id, slot_level)

    local is_enough = true
    for item_id, count in pairs(consume) do
        if not self:is_enough_by_id(item_id, count) then
            is_enough = false
            break
        end
    end
    if not is_enough then
        output.result = const.error_item_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    for item_id, count in pairs(consume) do
        self:remove_item_by_id(item_id, count)
    end
    self.coin_consumed = self.coin_consumed + consume[const.RESOURCE_NAME_TO_ID.bind_coin]
    self.exp_consumed = self.exp_consumed + consume[const.RESOURCE_NAME_TO_ID.exp]
    self.talent_level = growing_talent_config.get_talent_level(self.exp_consumed)
    self.actived_talent[talent_id] = slot_level + 1

    local talent_info = {}
    self:imp_talent_write_to_dict(talent_info)

    output.talent_info = talent_info
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    self:imp_assets_write_to_sync_dict(syn_data)
    self:recalc()
end

function imp_talent.on_get_talent_info(self, input)
    local talent_info = {}
    self:imp_talent_write_to_dict(talent_info)
    local output = {func_name = "GetTalentInfoRet", talent_info = talent_info}
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_talent.get_talent_attrib(self)
    local base_addition = {}
    local percent_addition = {}
    for talent_id, talent_level in pairs(self.actived_talent) do
        local talent_config = talent_scheme[talent_id]
        for attrib_name, value in pairs(talent_config.base_addition) do
            base_addition[attrib_name] = base_addition[attrib_name] or 0
            base_addition[attrib_name] = base_addition[attrib_name] + value * talent_level
        end
        for attrib_name, value in pairs(talent_config.percent_addition) do
            percent_addition[attrib_name] = percent_addition[attrib_name] or 0
            percent_addition[attrib_name] = math_floor(percent_addition[attrib_name] + value * talent_level)
        end
    end
    return base_addition, percent_addition
end

return imp_talent