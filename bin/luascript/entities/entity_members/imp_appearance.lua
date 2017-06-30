--------------------------------------------------------------------
-- 文件名:	imp_appearance.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/28 0028
-- 描  述:	人物外观
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local scheme_fashion = require("data/growing_fashion").Fashion
local role_model_scheme = require("data/system_login_create").RoleModel

local APPEARANCE_TYPE_TO_NAME = const.APPEARANCE_TYPE_TO_NAME
local ONE_DAY_SECONDS = 86400
local TIME_FOREVER = const.TIME_FOREVER
local DYE_ITEM_ID = 4155
local PART_ID_INDEX_DIFF = 900

local params = {
}

local imp_appearance = {}
imp_appearance.__index = imp_appearance

setmetatable(imp_appearance, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_appearance.__params = params

function imp_appearance.__ctor(self)
    self.appearance = {}
    self.fashion_inventory = {}
end

function imp_appearance.imp_appearance_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.appearance = table.get(dict, "appearance", {})
    self.fashion_inventory = table.get(dict, "fashion_inventory", {})
end

function imp_appearance.imp_appearance_init_from_other_game_dict(self,dict)
    self:imp_appearance_init_from_dict(dict)
end

function imp_appearance.imp_appearance_write_to_dict(self, dict, to_other_game)
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
    dict.appearance = self.appearance
    dict.fashion_inventory = self.fashion_inventory
end

function imp_appearance.imp_appearance_write_to_other_game_dict(self,dict)
    self:imp_appearance_write_to_dict(dict, true)
end

function imp_appearance.imp_appearance_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
    dict.appearance = self.appearance
    dict.fashion_inventory = self.fashion_inventory
end

function imp_appearance.get_appearance_aoi_index(part_id)
    return part_id - PART_ID_INDEX_DIFF
end

local function _get_init_fashion(self)
    local config = role_model_scheme[self.vocation]
    if config == nil then
        flog("error", "imp_appearance.init_new_player_fashion get config error!")
    end
    local suit_name = "MaleSuit"
    if self.sex == const.PLAYER_SEX_NAME_TO_INDEX.female then
        suit_name = "FemaleSuit"
    end
    return config[suit_name]
end

function imp_appearance.init_new_player_fashion(self)
    local suit_list =  _get_init_fashion(self)
    for i, fashion_id in pairs(suit_list) do
        local scheme_config = scheme_fashion[fashion_id]
        if scheme_config == nil then
            flog("error", "imp_appearance.init_new_player_fashion find scheme_config error")
            return
        end
        local part_id = scheme_config.Part
        self.appearance[part_id] = fashion_id
        local fashion_item = {expire_time = TIME_FOREVER }
        self.fashion_inventory[fashion_id] = fashion_item
    end
end

local function _appearance_changed(self, part_id)
    if self.in_fight_server then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_change_appearance",part_id=part_id,appearance=table.copy(self.appearance)})
        return
    end
    self:change_appearance(part_id,self.appearance)
end

function imp_appearance.use_fashion_item(self, fashion_id, last_days)
    local scheme_config = scheme_fashion[fashion_id]
    if scheme_config == nil then
        flog("error", "imp_appearance.use_fashion_item find config error")
    end
    local is_vocation_match = false
    for _, v in pairs(scheme_config.Faction) do
        if v == self.vocation then
            is_vocation_match = true
            break
        end
    end
    if not is_vocation_match then
        return const.error_vocation_not_match
    end

    if scheme_config.Gender ~= const.PLAYER_SEX_NAME_TO_INDEX.both and scheme_config.Gender ~= self.sex then
        return const.error_gender_not_match
    end

    local part_id = scheme_config.Part
    local fashion_item = self.fashion_inventory[fashion_id]
    local current_time = _get_now_time_second()
    if fashion_item == nil then
        fashion_item = {expire_time = current_time }
        self.fashion_inventory[fashion_id] = fashion_item
    else
        fashion_item.expire_time = fashion_item.expire_time or current_time
        if fashion_item.expire_time < current_time then
            fashion_item.expire_time = current_time
        end
        --[[if fashion_item.expire_time > TIME_FOREVER then
            return const.error_already_buy_forever
        end]]
    end
    fashion_item.expire_time = fashion_item.expire_time + last_days * ONE_DAY_SECONDS

    self.appearance[part_id] = fashion_id
    local output = {func_name = "ChangeFashionRet", result = 0, fashion_id = fashion_id}
    self:imp_appearance_write_to_sync_dict(output)
    _appearance_changed(self, part_id)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    self:update_task_system_operation(const.TASK_SYSTEM_OPERATION.fashion)
    return 0
end

function imp_appearance.on_change_fashion(self, input)
    local fashion_id = input.fashion_id
    local fashion_item = self.fashion_inventory[fashion_id]

    local current_time = _get_now_time_second()
    local output = {func_name = "ChangeFashionRet", fashion_id = fashion_id}
    if fashion_item == nil then
        output.result = const.error_not_unlock_this_fashion_yet
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end
    if fashion_item.expire_time < current_time then
        output.result = const.error_already_out_of_time
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end

    local scheme_config = scheme_fashion[fashion_id]
    if scheme_config == nil then
        flog("error", "imp_appearance.on_change_fashion find config error")
        return
    end
    local part_id = scheme_config.Part
    self.appearance[part_id] = fashion_id
    output.result = 0

    self:imp_appearance_write_to_sync_dict(output)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    _appearance_changed(self, part_id)
    self:update_task_system_operation(const.TASK_SYSTEM_OPERATION.fashion)
end

function imp_appearance.check_fashion_validity(self)
    local not_valid_fashion = {}
    for part_id, fashion_id in pairs(self.appearance) do
        local fashion_item = self.fashion_inventory[fashion_id]
        local current_time = _get_now_time_second()
        if fashion_item == nil then
            fashion_id = fashion_id or "nil"
            flog("error", "check_fashion_validity no item "..fashion_id)
            return
        end
        if fashion_item.expire_time < current_time then
            not_valid_fashion[part_id] = fashion_id
            self.appearance[part_id] = nil
        end
    end
    if not table.isEmptyOrNil(not_valid_fashion) then
        local output = {func_name = "FashionOutOfTime", not_valid_fashion = not_valid_fashion }
        local suit_list =  _get_init_fashion(self)
        for i, original_fashion_id in pairs(suit_list) do
            local scheme_config = scheme_fashion[original_fashion_id]
            if scheme_config == nil then
                flog("error", "imp_appearance.init_new_player_fashion find scheme_config error")
                return
            end
            local part_id = scheme_config.Part
            if not_valid_fashion[part_id] ~= nil then
                self.appearance[part_id] = original_fashion_id
            end
        end

        self:imp_appearance_write_to_sync_dict(output)
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
end

function imp_appearance.on_save_fashion_dye(self, input)
    local color = input.color
    local index = input.index
    local fashion_id = input.fashion_id

    local output = {func_name = "SaveFashionDyeRet"}
    local fashion_item = self.fashion_inventory[fashion_id]
    if fashion_item == nil then
        output.result = const.error_not_unlock_this_fashion_yet
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end
    local current_time = _get_now_time_second()
    if fashion_item.expire_time < current_time then
        output.result = const.error_already_out_of_time
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end

    if index < 1 or index > 3 or math.floor(index) ~= index then
        output.result = const.error_impossible_param
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end

    local scheme_config = scheme_fashion[fashion_id]
    if scheme_config == nil then
        flog("error", "imp_appearance.use_fashion_item find config error")
    end
    local cost = scheme_config.DyeComsumtion
    if not self:is_enough_by_id(DYE_ITEM_ID, cost) then
        output.result = const.error_item_not_enough
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end

    fashion_item.color_index = index
    fashion_item.color_moudle = fashion_item.color_moudle or {}
    fashion_item.color_moudle[index] = color
    output.result = 0
    self:imp_appearance_write_to_sync_dict(output)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_appearance.on_use_fashion_dye(self, input)
    local index = input.index
    local fashion_id = input.fashion_id

    local output = {func_name = "UseFashionDyeRet"}
    local fashion_item = self.fashion_inventory[fashion_id]
    if fashion_item == nil then
        output.result = const.error_not_unlock_this_fashion_yet
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end
    local current_time = _get_now_time_second()
    if fashion_item.expire_time < current_time then
        output.result = const.error_already_out_of_time
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end

    if index < 1 or index > 3 or math.floor(index) ~= index then
        output.result = const.error_impossible_param
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end

    fashion_item.color_moudle = fashion_item.color_moudle or {}
    if fashion_item.color_moudle[index] == nil then
        output.result = const.error_not_define_dye_moudle
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return
    end

    fashion_item.color_index = index
    output.result = 0
    self:imp_appearance_write_to_sync_dict(output)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_appearance.on_get_fashion(self, input)
    local output = {func_name = "GetFashionRet" }
    self:imp_appearance_write_to_sync_dict(output)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_appearance.is_equip_fashion(self)
    local suit_list =  _get_init_fashion(self)
    for i, fashion_id in pairs(suit_list) do
        local scheme_config = scheme_fashion[fashion_id]
        if scheme_config == nil then
            flog("error", "imp_appearance.init_new_player_fashion find scheme_config error")
            return
        end
        local part_id = scheme_config.Part
        if self.appearance[part_id] ~= fashion_id then
            return true
        end
    end
    return false
end

return imp_appearance