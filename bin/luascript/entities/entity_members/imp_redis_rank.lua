--------------------------------------------------------------------
-- 文件名:	imp_redis_rank.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/17 0017
-- 描  述:	redis排行榜组件
--------------------------------------------------------------------
local params = {}
local db_hiredis = require "basic/db_hiredis"
local data_base = require "basic/db_mongo"
local flog = require "basic/log"
local timer = require "basic/timer"
local const = require "Common/constant"
local math_random = math.random
local table_insert = table.insert
local string_format = string.format
local table_copy = table.copy
local is_command_cool_down = require("helper/command_cd").is_command_cool_down
local dichotomy_get_index_ascending = require("basic/scheme").dichotomy_get_index_ascending
local set_global_data = require("helper/global_server_data").set_global_data

local VOCATION_ID_TO_NAME = const.VOCATION_ID_TO_NAME
local common_parameter_formula_config = require "configs/common_parameter_formula_config"


local RANDOM_RANGE = 60000                                                              --排行榜刷新时间随机值
local PLAYER_VALUE_LIST = {
    fight_power = {vocation = true},
    total_power = {vocation = true},
    war_rank = {vocation = true },
    wealth = {vocation = true},
    level = {vocation = true},
    equipment_score = {vocation = true},
    present_friend_flower_count = {},
    receive_friend_flower_count = {},
    karma_value = {},
    liveness_history = {},
    country_war_score = {},
}
local PET_VALUE_LIST = {
    pet_score = true,                         --宠物评分
    base_physic_attack = true,                --基础物理攻击
    base_magic_attack = true,                 --基础魔法攻击
    base_physic_defence = true,               --基础物理防御
    base_magic_defence = true,                --基础魔法防御
    physic_attack_quality = true,             --物理攻击资质
    magic_attack_quality = true,              --魔法攻击资质
    physic_defence_quality = true,            --物理防御资质
    magic_defence_quality = true,             --魔法防御资质
}

local PLAYER_DATA_FIELD = {actor_name = 1, actor_id = 1, sex = 1, vocation = 1, country = 1, faction_name = 1}
local PET_DATA_FIELD = { entity_id = 1, pet_name = 1, pet_id = 1, pet_level = 1,}

local redis_rank_timer


local player_rank_data_cache = {}
local player_normal_data_cache = {}
local player_id_to_index = {}

local pet_rank_data_cache = {}
local pet_normal_data_cache = {}
local pet_id_to_index = {}


local imp_redis_rank = {}
imp_redis_rank.__index = imp_redis_rank

setmetatable(imp_redis_rank, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_redis_rank.__params = params

function imp_redis_rank.__ctor(self)
    self.hide_list = {}
end

function imp_redis_rank.imp_redis_rank_init_from_dict(self, dict)
    self.hide_list = table.copy(dict.hide_list) or {}
end

function imp_redis_rank.imp_redis_rank_init_from_other_game_dict(self,dict)
    self:imp_redis_rank_init_from_dict(dict)
end

function imp_redis_rank.imp_redis_rank_write_to_dict(self, dict)
    dict.hide_list = table.copy(self.hide_list)
end

function imp_redis_rank.imp_redis_rank_write_to_other_game_dict(self,dict)
    self:imp_redis_rank_write_to_dict(dict)
end

local function _remove_from_pet_rank_list(pet_entity_id)
    for key, _ in pairs(PET_VALUE_LIST) do
        local rank_set_name = "pet_rank_set_"..key
        db_hiredis.zrem(rank_set_name, pet_entity_id)
    end
    db_hiredis.hdel("pet_rank_cache", pet_entity_id)
end

function imp_redis_rank.update_player_value_to_rank_list(self, key)
    local config = PLAYER_VALUE_LIST[key]
    if config == nil then
        key = key or "nil"
        flog("error", "imp_redis_rank.update_player_value_to_rank_list not configed key "..key)
    end
    local value = self[key]
    flog("syzDebug", "update_player_value_to_rank_list value "..value)
    local rank_set_name = "player_rank_set_"..key
    if not self.hide_list[rank_set_name] then
        db_hiredis.zadd(rank_set_name, value, self.actor_id)
    end
    if config.vocation then
        local vocation_rank_set_name = string_format("player_vocation_rank_set_%d_%s", self.vocation, key)
        if not self.hide_list[vocation_rank_set_name] then
            db_hiredis.zadd(vocation_rank_set_name, value, self.actor_id)
        end
    end
end

function global_get_player_rank_list_data(key, vocation)
    local rank_set_name = "player_rank_set_"..key
    if vocation then
        rank_set_name = string_format("player_vocation_rank_set_%d_%s", vocation, key)
    end
    local redis_data = player_rank_data_cache[rank_set_name] or {}
    return redis_data
end

function global_clear_player_rank_list_data(key, vocation)
    local rank_set_name = "player_rank_set_"..key
    if vocation then
        rank_set_name = string_format("player_vocation_rank_set_%d_%s", vocation, key)
    end
    player_rank_data_cache[rank_set_name] = {}
    db_hiredis.del(rank_set_name)
end

function imp_redis_rank.on_get_player_rank_list(self, input)
    local key = input.rank_name
    local vocation = input.vocation
    local start_index = input.start_index
    local end_index = input.end_index

    local rank_set_name = "player_rank_set_"..key
    if vocation then
        rank_set_name = string_format("player_vocation_rank_set_%d_%s", vocation, key)
    end
    local is_hide = self.hide_list[rank_set_name]

    local output = {func_name = "GetPlayerRankListRet", rank_name = key, vocation = vocation, is_hide = is_hide}
    local redis_data = player_rank_data_cache[rank_set_name] or {}
    if start_index == nil or end_index == nil or end_index < start_index or start_index < 1 then
        output.result = const.error_impossible_param
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    local list_length = #redis_data
    if end_index > list_length then
        end_index = list_length
    end
    if start_index > end_index then
        start_index = end_index
    end

    --flog("info", table.serialize(redis_data))
    local rank_list = {}
    for i = start_index, end_index do
        if i < 1 then
            break
        end
        local v = redis_data[i]
        local data = table_copy(player_normal_data_cache[v.key]) or {}
        data[key] = v.value
        rank_list[i] = data
    end

    local self_data = {}
    if vocation == nil or self.vocation == vocation then
        for i, _ in pairs(PLAYER_DATA_FIELD) do
            self_data[i] = self[i]
        end
        self_data[key] = self[key]
        if is_hide then
            self_data.self_index = dichotomy_get_index_ascending(redis_data, "value", self_data[key])
        else
            self_data.self_index = player_id_to_index[rank_set_name][self.actor_id]
        end
    end

    output.result = 0
    output.rank_list = rank_list
    output.self_data = self_data
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    self:send_message_to_ranking_server({func_name = "get_hide_name_number", rank_set_name = rank_set_name, rank_name = key, class = "player", vocation = vocation})
end

function imp_redis_rank.update_pet_value_to_rank_list(self, pet_entity, key_list)
    key_list = key_list or PET_VALUE_LIST
    for key, _ in pairs(key_list) do
        repeat
            local config = PET_VALUE_LIST[key]
            if config == nil then
                break
            end
            local value = pet_entity[key]
            local rank_set_name = "pet_rank_set_"..key
            if not self.hide_list[rank_set_name] then
                local result = db_hiredis.zadd(rank_set_name, value, pet_entity.entity_id)
                result = result or "nil"
                flog("info", "zadd result "..result)
            end
        until(true)
    end
    local pet_data = {}
    pet_data.owner_name = self.actor_name
    pet_data.country = self.country
    for i, _ in pairs(PET_DATA_FIELD) do
        pet_data[i] = pet_entity[i]
    end
    pet_normal_data_cache[pet_entity.entity_id] = pet_data
    db_hiredis.hset("pet_rank_cache", pet_entity.entity_id, pet_data)
end

function imp_redis_rank.on_get_total_pet_rank_list(self, input)
    local key = input.rank_name
    local start_index = input.start_index
    local end_index = input.end_index

    local rank_set_name = "pet_rank_set_"..key
    local is_hide = self.hide_list[rank_set_name]
    local output = {func_name = "GetTotalPetRankListRet", rank_name = key, is_hide = is_hide}
    local redis_data = pet_rank_data_cache[rank_set_name] or {}
    if start_index == nil or end_index == nil or end_index < start_index or start_index < 1 then
        output.result = const.error_impossible_param
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    local list_length = #redis_data
    if end_index > list_length then
        end_index = list_length
    end
    if start_index > end_index then
        start_index = end_index
    end

    local rank_list = {}
    for i = start_index, end_index do
        if i < 1 then
            break
        end
        local v = redis_data[i]
        local data = table_copy(pet_normal_data_cache[v.key]) or {}
        data[key] = v.value
        rank_list[i] = data
    end

    local pet_entity
    local max_value = -1
    local pet_list = self.pet_list
    for i, pet in pairs(pet_list) do
        if pet[key] > max_value then
            max_value = pet[key]
            pet_entity = pet_list[i]
        end
    end
    if pet_entity == nil then
        output.result = 0
        output.rank_list = rank_list
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    local self_data = {}
    self_data.owner_name = self.actor_name
    self_data.country = self.country
    for i, _ in pairs(PET_DATA_FIELD) do
        self_data[i] = pet_entity[i]
    end
    self_data[key] = pet_entity[key]

    if is_hide then
        self_data.self_index = dichotomy_get_index_ascending(redis_data, "value", self_data[key])
    else
        self_data.self_index = pet_id_to_index[rank_set_name][pet_entity.entity_id]
    end

    output.result = 0
    output.rank_list = rank_list
    output.self_data = self_data
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    self:send_message_to_ranking_server({func_name = "get_hide_name_number", rank_set_name = rank_set_name, rank_name = key, class = "pet"})
end

function imp_redis_rank.imp_redis_rank_remove_pet(self, pet_entity_id)
    _remove_from_pet_rank_list(pet_entity_id)
end

function imp_redis_rank.on_get_faction_rank_list(self, input)
    input.func_name = "get_faction_rank_list"
    input.faction_id = self.faction_id
    self:send_message_to_faction_server(input)
end

function imp_redis_rank.on_hide_my_name(self, input)
    local key = input.rank_name
    local vocation = input.vocation
    local is_hide = input.is_hide or false

    local rank_set_name = "player_rank_set_"..key
    if vocation then
        rank_set_name = string_format("player_vocation_rank_set_%d_%s", self.vocation, key)
    end

    local output = {func_name = "HideMyNameRet" }
    self.hide_list[rank_set_name] = self.hide_list[rank_set_name] or false
    if self.hide_list[rank_set_name] == is_hide then
        output.result = const.error_alread_in_this_hide_name_state
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    --[[local cd_rst = is_command_cool_down(self.actor_id, rank_set_name, common_parameter_formula_config.HIDE_NAME_CD)
    if cd_rst ~= 0 then
        output.result = cd_rst
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end]]
    self.hide_list[rank_set_name] = is_hide

    if is_hide then
        db_hiredis.zrem(rank_set_name, self.actor_id)
    else
        self:update_player_value_to_rank_list(key)
    end
    --self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    self:send_message_to_ranking_server({func_name = "hide_name_from_rank_list", rank_set_name = rank_set_name, class = "player", is_hide = is_hide})
end

function imp_redis_rank.on_hide_my_pet_name(self, input)
    local key = input.rank_name
    local is_hide = input.is_hide or false

    local rank_set_name = "pet_rank_set_"..key
    local output = {func_name = "HideMyPetNameRet" }
    self.hide_list[rank_set_name] = self.hide_list[rank_set_name] or false
    if self.hide_list[rank_set_name] == is_hide then
        output.result = const.error_alread_in_this_hide_name_state
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    local cd_rst = is_command_cool_down(self.actor_id, rank_set_name, common_parameter_formula_config.HIDE_NAME_CD)
    if cd_rst ~= 0 then
        output.result = cd_rst
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
    self.hide_list[rank_set_name] = is_hide

    if is_hide then
        for i, pet in pairs(self.pet_list) do
            db_hiredis.zrem(rank_set_name, pet.entity_id)
        end
    else
        for i, pet in pairs(self.pet_list) do
            self:update_pet_value_to_rank_list(pet, {[key] = true})
        end
    end
    output.result = 0
    --return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    self:send_message_to_ranking_server({func_name = "hide_name_from_rank_list", rank_set_name = rank_set_name, class = "pet", is_hide = is_hide})
end


local function _refresh_player_normal_cache_callback(caller, status, doc)
    if status == 0 or doc == nil then
        flog("error", "_refresh_player_normal_cache_callback: get data fail!")
        return
    end

    for _, v in pairs(doc) do
        player_normal_data_cache[v.actor_id] = v
    end
end

local function _update_server_level(rank_set_name)
    if rank_set_name == "player_rank_set_level" then
        local rank_data = player_rank_data_cache[rank_set_name]
        local total_level = 0
        local count = 0
        for i, data in ipairs(rank_data) do
            if i > common_parameter_formula_config.SERVER_LEVEL_IN_COUNT_NUM then
                break
            end
            count = count + 1
            total_level = total_level + data.value
        end
        local avg_level = 0
        if count > 0 then
            avg_level = math.floor(total_level / count)
        end
        if avg_level < common_parameter_formula_config.MIN_SERVER_LEVEL then
            avg_level = common_parameter_formula_config.MIN_SERVER_LEVEL
        end
        set_global_data("average_level", avg_level)
        --set_global_data("average_level", 1)
    end
end


local function _refresh_player_normal_cache(set_name)
    local id_list = {}
    if set_name == nil then
        local r_id_list = {}
        for _set_name, set_data in pairs(player_rank_data_cache) do
            for index, data in ipairs(set_data) do
                if index <= common_parameter_formula_config.RANK_LIST_DISPLAY_NUMBER then
                    r_id_list[data.key] = 1
                end
                player_id_to_index[_set_name][data.key] = index
            end
        end
        for _id, _ in pairs(r_id_list) do
            table_insert(id_list, _id)
        end
    else
        for index, data in ipairs(player_rank_data_cache[set_name]) do
            if index <= common_parameter_formula_config.RANK_LIST_DISPLAY_NUMBER then
                table_insert(id_list, data.key)
            end
            player_id_to_index[set_name][data.key] = index
        end
    end

    if not table.isEmptyOrNil(id_list) then
        local index = 1
        local page_size = 20
        local length = #id_list
        for i = index, length, page_size do
            local id_list_one_page = {}
            for j = i, i + page_size do
                if id_list[j] == nil then
                    break
                end
                table_insert(id_list_one_page, id_list[j])
            end
            data_base.db_find_n(0, _refresh_player_normal_cache_callback, "actor_info", {actor_id = {["$in"] = id_list_one_page}}, PLAYER_DATA_FIELD)
        end
    end
end

local function _refresh_pet_normal_cache(set_name)
    local id_list = {}
    if set_name == nil then
        local r_id_list = {}
        for _set_name, set_data in pairs(pet_rank_data_cache) do
            for index, data in ipairs(set_data) do
                if index <= common_parameter_formula_config.RANK_LIST_DISPLAY_NUMBER then
                    r_id_list[data.key] = 1
                    pet_id_to_index[_set_name][data.key] = index
                end
            end
        end
        for _id, _ in pairs(r_id_list) do
            table_insert(id_list, _id)
        end
    else
        for index, data in ipairs(pet_rank_data_cache[set_name]) do
            if index <= common_parameter_formula_config.RANK_LIST_DISPLAY_NUMBER then
                table_insert(id_list, data.key)
                pet_id_to_index[set_name][data.key] = index
            end
        end
    end
    local result_table = db_hiredis.hmget("pet_rank_cache", id_list)

    for i, v in pairs(result_table) do
        if pet_normal_data_cache[i] == nil then
            pet_normal_data_cache[i] = v
        end
    end
end


local function _server_start()
    for key, config in pairs(PLAYER_VALUE_LIST) do
        local rank_set_name = "player_rank_set_"..key
        player_id_to_index[rank_set_name] = {}
        local function timer_callback()
            player_rank_data_cache[rank_set_name] = db_hiredis.zrevrange(rank_set_name, 0, common_parameter_formula_config.RANK_LIST_NUMBER - 1, true)
            _refresh_player_normal_cache(rank_set_name)
            _update_server_level(rank_set_name)
        end
        player_rank_data_cache[rank_set_name] = db_hiredis.zrevrange(rank_set_name, 0, common_parameter_formula_config.RANK_LIST_NUMBER - 1, true)
        timer.create_timer(timer_callback, common_parameter_formula_config.REFREASH_INTERVAL + math_random(RANDOM_RANGE), const.INFINITY_CALL)

        if config.vocation then
            for vocation, _ in pairs(VOCATION_ID_TO_NAME) do
                local vocation_rank_set_name = string_format("player_vocation_rank_set_%d_%s", vocation, key)
                player_id_to_index[vocation_rank_set_name] = {}

                local function vocation_timer_callback()
                    player_rank_data_cache[vocation_rank_set_name] = db_hiredis.zrevrange(vocation_rank_set_name, 0, common_parameter_formula_config.RANK_LIST_NUMBER - 1, true)
                    _refresh_player_normal_cache(vocation_rank_set_name)
                end
                player_rank_data_cache[vocation_rank_set_name] = db_hiredis.zrevrange(vocation_rank_set_name, 0, common_parameter_formula_config.RANK_LIST_NUMBER - 1, true)
                timer.create_timer(vocation_timer_callback, common_parameter_formula_config.REFREASH_INTERVAL + math_random(RANDOM_RANGE), const.INFINITY_CALL)
            end
        end
    end

    _refresh_player_normal_cache()
    _update_server_level("player_rank_set_level")

    for key, _ in pairs(PET_VALUE_LIST) do
        local rank_set_name = "pet_rank_set_"..key
        pet_id_to_index[rank_set_name] = {}
        local function timer_callback()
            pet_rank_data_cache[rank_set_name] = db_hiredis.zrevrange(rank_set_name, 0, common_parameter_formula_config.RANK_LIST_NUMBER - 1, true)
            _refresh_pet_normal_cache(rank_set_name)
        end
        --db_hiredis.clear_set(rank_set_name)
        pet_rank_data_cache[rank_set_name] = db_hiredis.zrevrange(rank_set_name, 0, common_parameter_formula_config.RANK_LIST_NUMBER - 1, true)
        timer.create_timer(timer_callback, common_parameter_formula_config.REFREASH_INTERVAL + math_random(RANDOM_RANGE), const.INFINITY_CALL)
    end
    _refresh_pet_normal_cache()
end

function imp_redis_rank.gm_refresh_all_player_rank()
    for key, config in pairs(PLAYER_VALUE_LIST) do
        local rank_set_name = "player_rank_set_"..key
        player_id_to_index[rank_set_name] = {}
        player_rank_data_cache[rank_set_name] = db_hiredis.zrevrange(rank_set_name, 0, common_parameter_formula_config.RANK_LIST_NUMBER - 1, true)

        if config.vocation then
            for vocation, _ in pairs(VOCATION_ID_TO_NAME) do
                local vocation_rank_set_name = string_format("player_vocation_rank_set_%d_%s", vocation, key)
                player_id_to_index[vocation_rank_set_name] = {}
                player_rank_data_cache[vocation_rank_set_name] = db_hiredis.zrevrange(vocation_rank_set_name, 0, common_parameter_formula_config.RANK_LIST_NUMBER - 1, true)
            end
        end
    end

    _refresh_player_normal_cache()
end

register_function_on_start(_server_start)

imp_redis_rank.__message_handler = {}
imp_redis_rank.__message_handler._server_start = _server_start

return imp_redis_rank