----------------------------------------------------------------------
-- 文件名:	imp_seal.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/21
-- 描  述:	宝印模块
--------------------------------------------------------------------
local entity_factory = require "entity_factory"
local const = require "Common/constant"
local flog = require "basic/log"
local timer = require "basic/timer"
local pet_attrib = require("data/growing_pet").Attribute
local scheme_catch_cost = require("data/growing_pet").CatchPet
local scheme_param = require("data/common_parameter_formula").Parameter
local seal_scheme = require("data/growing_pet").BaoWuUpgrade
local hp_grow_table = require("data/growing_pet").HpGrow
local devour_table = require("data/growing_pet").Devour
local item_scheme = require("data/common_item").Item
local dichotomy_get_index = require("basic/scheme").dichotomy_get_index

local CAPTURE_CD_TIME = scheme_param[4].Parameter  --抓宠cd时间（s）
local MAX_NUM_ON_FIGHT = 2          --最大出战宠物数目
local MAX_DEVOURALBE_STARLV = 100   --最大可吞噬星级
local MERGE_ADDTION_COEFFICIENT = scheme_param[18].Parameter
local MIN_BASE_HP_ADD = scheme_param[19].Parameter --吞噬初始血量成长下限
local MAX_BASE_HP_ADD = scheme_param[20].Parameter --吞噬初始血量成长上限
local table = table
local string_format = string.format
local SECOND_ONE_HOUR = 3600          --一个小时的秒数

local params = {
    capture_energy = {db = true, sync = true, default = 1000},   --灵力值
    capture_energy_last_refresh_time = {db = true, sync = false},   --灵力值上一次刷新时间
    seal_level = {db = true, sync = true, default = 1},          --宝印等级
    seal_phase = {db = true, sync = true, default = 1},          --宝印阶段
    seal_ratio = {sync = true},                                             --宝印提升的抓宠概率(百分比)
    seal_level_limit = {sync = true},                                       --宝印可抓宠等级限制
    energy_ceiling = {sync = true},                                         --灵力值上限
    energy_recover_speed = {sync = true},                                   --灵力值恢复速度
    last_capture_time = {sync = true},                                         --上一次抓宠时间
    seal_size = {sync = true},                                         --宝印可容纳宠物数目
}

local imp_seal = {}
imp_seal.__index = imp_seal

setmetatable(imp_seal, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_seal.__params = params

local function _get_new_pet(self,output_type, pet_id, level)
    local init_info = {pet_id = pet_id, pet_level = level,output_type= output_type}

    local output = {func_name = "generate_new_pet", init_info = init_info}
    self:send_message_to_ranking_server(output)
end

local function _remove_pet(self, pet_index, is_ban_fight)
    if is_ban_fight == false then
        local pet = table.remove(self.pet_list, pet_index)

        local output = {func_name = "remove_pet_info_from_list" }
        output.pet_id = pet.pet_id
        output.pet_uid = pet.entity_id
        self:send_message_to_ranking_server(output)
        self:imp_redis_rank_remove_pet(pet.entity_id)

        flog("salog", string.format("Remove pet %d, uid %s", pet.pet_id, pet.entity_id), self.actor_id)
    else
        table.remove(self.ban_fight_pet_list, pet_index)
    end
end

local function on_player_login(self, input, syn_data)
    self:get_pet_rank_info()
end

local function _calc_capture_energy(self)
    local delta_time = _get_now_time_second() - self.capture_energy_last_refresh_time

    local sec_per_energy
    if self.energy_recover_speed == 0 then
        flog("error", "self.energy_recover_speed is 0")
        sec_per_energy = 0
    else
        sec_per_energy = SECOND_ONE_HOUR / self.energy_recover_speed
    end

    local energy_addition
    if sec_per_energy == 0 then
        flog("error", "sec_per_energy is 0")
        energy_addition = 0
    else
        energy_addition = math.floor(delta_time / sec_per_energy)
    end

    local truly_addition = energy_addition
    if energy_addition + self.capture_energy > self.energy_ceiling then
        truly_addition = self.energy_ceiling - self.capture_energy
    end
    self.capture_energy = self.capture_energy + truly_addition
    if self.capture_energy < 0 then
        self.capture_energy = 0
    end
    self.capture_energy_last_refresh_time = self.capture_energy_last_refresh_time + energy_addition * sec_per_energy
end

local function _get_pet_capture_energy_cost(pet_id)
    local rarity = pet_attrib[pet_id].Rarity
    local index = dichotomy_get_index(scheme_catch_cost, "RarityLowerDegree", rarity)
    if index == nil then
        pet_id = pet_id or "nil"
        flog("error", "_get_pet_capture_energy_cost get index error "..pet_id)
        return
    end
    return scheme_catch_cost[index].NimbusNeed
end

local function _is_pet_captureable(self, pet_id, current_time, is_prepare)
    local result = 0

    if current_time - self.last_capture_time < CAPTURE_CD_TIME then
        result = const.error_pet_capture_not_cool_down
    end

    if self.pet_id_capturing ~= nil and is_prepare then
        result = const.error_one_pet_one_time
    end
    _calc_capture_energy(self)
    local energy_cost = _get_pet_capture_energy_cost(pet_id)
    if self.capture_energy < energy_cost then
        result = const.error_pet_capture_energy_require
    end
    if #self.pet_list >= self.seal_size then
        result = const.error_pet_overflow
    end

    return result, energy_cost
end


local function on_prepare_capture(self, input)
    local pet_id = input.pet_id
    local pet_uid_in_capture = input.pet_uid

    local current_time = _get_now_time_second()

    local result, energy_cost = _is_pet_captureable(self, pet_id, current_time, true)
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_PREPARE_CAPTURE_PET , {result = result})
    end

    self:_dec("capture_energy", energy_cost)
    local output = {func_name="on_fight_avatar_prepare_capture", pet_uid = pet_uid_in_capture, pet_id = pet_id}
    if self.in_fight_server then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, output)
    else
        self:on_prepare_capture_wild_pet(output)
    end
end

local function on_start_capture(self, input, syn_data)
    input.seal_ratio = self.seal_ratio
    if self.in_fight_server then
        input.func_name = "on_fight_avatar_start_capture"
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, input)
    else
        self:on_start_capture_wild_pet(input)
    end
end

local function on_capture(self, input, syn_data)
    input.seal_ratio = self.seal_ratio

    local max_radius = input.max_radius
    local radius = input.radius
    if max_radius ~= 0 then
        input.radius = math.floor(radius / max_radius * 100)
        input.max_radius = 100
    else
        flog("error", "imp_seal on_capture: max_radius can not be 0")
        return
    end

    if self.in_fight_server then
        input.func_name = "on_fight_avatar_capture"
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, input)
    else
        self:on_capture_wild_pet(input)
    end
end

local function on_cancel_capture(self, input, syn_data)
    if self.in_fight_server then
        input.func_name = "on_fight_avatar_cancel_capture"
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, input)
    else
        self:on_cancel_capture_wild_pet(input)
    end
end

function imp_seal.capture_pet_success(self, input)
    _get_new_pet(self, const.PET_OUTPUT_TYPE.Wild, input.pet_id, 1)

    flog("salog", string.format("Capture pet %d", self.pet_id_capturing), self.actor_id)
    self:update_task_system_operation(const.TASK_SYSTEM_OPERATION.capture_pet)
    self:finish_activity("catch_pet")

    local info = {}
    self:imp_seal_write_to_sync_dict(info, true)
    self:send_message(const.SC_MESSAGE_LUA_START_CAPTURE_PET , {result = 0, rate = 100, info=info})
end

local function update_params(self, seal_phase, seal_level)
    local key = string_format("%d_%d", seal_phase, seal_level)
    local params = seal_scheme[key]
    if params == nil then
        flog("error", "update_params: no key : "..key)
    end
    self.seal_ratio = params.SuccessRate
    self.seal_level_limit = params.SealLv
    self.energy_ceiling = params.NimbusLimit
    self.energy_recover_speed = params.NimbusRecoverSpeed
    self.seal_size = params.CarryingLimit
    _calc_capture_energy(self)
end

local function on_seal_upgrade(self, input, syn_data)
    local key = string_format("%d_%d", self.seal_phase, self.seal_level)
    local items_need = seal_scheme[key].Prop1
    local length = #items_need
    if length < 0 or length % 2 ~= 0 then
        flog("error", "on_seal_level_up: error items_need length :"..length)
    end

    local is_enough = true
    for i = 1, length - 1, 2 do
        local item_id = items_need[i]
        local count = items_need[i+1]
        if not self:is_enough_by_id(item_id, count) then
            is_enough = false
            break
        end
    end
    if is_enough then
        --扣除材料
        for i = 1, length - 1, 2 do
            local item_id = items_need[i]
            local count = items_need[i+1]
            self:remove_item_by_id(item_id, count)
        end

        local new_phase = self.seal_phase
        local new_level = self.seal_level
        new_level = new_level + 1
        if new_level > 10 then
            new_level = new_level - 10
            new_phase = new_phase + 1
        end

        self:_set("seal_phase", new_phase)
        self:_set("seal_level", new_level)
        update_params(self, self.seal_phase, self.seal_level)

        local info = {}
        self:imp_seal_write_to_sync_dict(info, true)
        self:send_message(const.SC_MESSAGE_LUA_SEAL_UPGRADE , {result = 0, info = info})
        self:update_task_system_operation(const.TASK_SYSTEM_OPERATION.seal)
        self:imp_assets_write_to_sync_dict(syn_data)
    else
        self:send_message(const.SC_MESSAGE_LUA_SEAL_UPGRADE , {result = const.error_item_not_enough})
    end
end

local function on_pet_devour(self, input, syn_data)
    --由于新增非出战宠物，取消直接传索引
    --local main_index = input.main_index
    --local assist_index = input.assist_index
    local main_uid = input.main_uid
    local assist_uid = input.assist_uid

    local result = 0
    if main_uid == assist_uid then
        result = const.error_pet_can_not_devour
    end

    local main_pet,main_ban_fight,main_index = self:find_pet_and_index(main_uid)
    local assist_pet,assist_ban_fight,assist_index = self:find_pet_and_index(assist_uid)

    if main_pet == nil or assist_pet == nil or main_ban_fight == true  then
        self:send_message(const.SC_MESSAGE_LUA_PET_DEVOUR , {result = const.error_pet_not_exist})
        return
    end

    if assist_ban_fight == false and #self.pet_list <= 2 then
        result = const.error_pet_less_than_two
    end

    for i, v in pairs(self.pet_on_fight) do
        if assist_uid == v then
            result = const.error_pet_is_on_fight
            break
        end
    end

    --计算血量资质，读表查找
    local pet_attrib_main = pet_attrib[main_pet:get("pet_id")]
    if pet_attrib_main == nil or pet_attrib_main.HpQuality == 0 then
        flog("error", "on_pet_devour : pet_attrib_main.HpQuality cannot be 0")
        result = const.error_server_error
    end

    local hp_quality_rate = main_pet:get("hp_max_quality") * 100 / pet_attrib_main.HpQuality
    --计算吞噬所需要的星级以及星级加成
    local devour_need
    for i, v in ipairs(devour_table) do
        if v.StarLv > hp_quality_rate then
            devour_need = devour_table[i - 1]
            break
        end
    end
    if devour_need == nil then
        devour_need = devour_table[#devour_table]
    end
    --副宠星级小于需要星级或大于最大可吞噬星级
    if devour_need.NeedStarLv > assist_pet:get("pet_star") or MAX_DEVOURALBE_STARLV < assist_pet:get("pet_star")  then
        result = const.error_pet_can_not_devour
    end
    if devour_need.NeedLv > assist_pet:get("pet_level") then
        result = const.error_pet_can_not_devour
    end

    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_PET_DEVOUR , {result = result})
        return
    end

    local main_star_coefficient = devour_need.Coefficient / 100
    local assist_star_coefficient
    for i, v in ipairs(devour_table) do
        if v.NeedStarLv > assist_pet.pet_star then
            assist_star_coefficient = devour_table[i - 1].Coefficient / 100
            break
        end
    end
    if assist_star_coefficient == nil then
        assist_star_coefficient = devour_table[#devour_table].Coefficient / 100
    end

    --血量资质比，百分制
    local hp_grow
    for i, v in ipairs(hp_grow_table) do
        if v.HpLower > hp_quality_rate then
            hp_grow = hp_grow_table[i - 1]
            break
        end
    end
    if hp_grow == nil then
        hp_grow = hp_grow_table[#hp_grow_table]
    end
    local addition_quality_rate = hp_grow.HpAdvance  --万分制

    local rand_rate = math.random(80, 120) / 100
    addition_quality_rate = addition_quality_rate * rand_rate * (1 + assist_star_coefficient - main_star_coefficient)

    local new_quality = addition_quality_rate / 10000 + hp_quality_rate --统一为百分制
    local new_quality = math.floor(new_quality * pet_attrib_main.HpQuality / 100)

    --初始血量提升
    local base_hp_add = math.random(MIN_BASE_HP_ADD, MAX_BASE_HP_ADD)
    local base_hp = main_pet:get("base_hp_max")

    _remove_pet(self, assist_index, assist_ban_fight)

    local old_hp_quality = main_pet:get("hp_max_quality")
    main_pet:set("hp_max_quality", new_quality)
    main_pet:set("base_hp_max", base_hp + base_hp_add)

    main_pet.devour_times = main_pet.devour_times + 1
    main_pet:recalc()

    if main_pet:random_field_unlock("Devourpro") then
        if main_pet:field_unlock() then
            self:send_message(const.SC_MESSAGE_LUA_SERVER_INFO , {type = "pet_field_unlock", pet_uid = main_pet:get("entity_id")})
        end
    end
    local upgrad_skill_array = main_pet:devour_random_skill_upgrade(assist_pet)
    if not table.isEmptyOrNil(upgrad_skill_array) then
        for _, v in upgrad_skill_array do
            main_pet:add_skill_level(v, 1)
        end

        self:send_message(const.SC_MESSAGE_LUA_SERVER_INFO , {type = "pet_skill_upgrade", pet_uid = main_pet:get("entity_id"), skill_array = upgrad_skill_array})
    end

    --检查竞技场防守宠物
    self:check_arena_defend_pet(assist_uid)
    self:imp_seal_write_to_sync_dict(syn_data)
    self:send_message(const.SC_MESSAGE_LUA_PET_DEVOUR , {result = 0, hp_quality_add = new_quality - old_hp_quality, base_hp_add = base_hp_add, data = syn_data})
    self:update_pet_info_to_pet_rank_list(main_pet, {pet_score = true})

end

local function on_pet_merge(self, input, syn_data)
    local main_index = input.main_index
    local assist_index = input.assist_index
    local main_uid = input.main_uid
    local assist_uid = input.assist_uid

    local result = 0
    if assist_index == main_index then
        result = const.error_pet_can_not_merge
    end

    if #self.pet_list <= 2 then
        result = const.error_pet_less_than_two
    end

    local main_pet = self.pet_list[main_index]
    local assist_pet = self.pet_list[assist_index]

    if main_pet == nil or assist_pet == nil then
        self:send_message(const.SC_MESSAGE_LUA_PET_MERGE , {result = const.error_pet_not_exist})
        return
    end

    if main_pet:get("entity_id") ~= main_uid or assist_pet:get("entity_id") ~= assist_uid then
        if not input.debug then
            result = const.error_pet_uid_not_match
        end
    end

    for i, v in pairs(self.pet_on_fight) do
        if assist_uid == v then
            result = const.error_pet_is_on_fight
            break
        end
    end

    -- 判断是否同一种宠物
    if main_pet:get("pet_id") ~= assist_pet:get("pet_id") then
        result = const.error_pet_can_not_merge
    end

    -- 副宠不能超过100星
    if assist_pet:get("pet_star") > 100 then
        result = const.error_pet_can_not_merge
    end

    local pet_attrib_main = pet_attrib[main_pet:get("pet_id")]
    local pet_attrib_assist = pet_attrib[assist_pet:get("pet_id")]
    local adv_propertys = assist_pet:get_advantage_property(main_pet)
    if table.isEmptyOrNil(adv_propertys) then
        result = const.error_pet_can_not_merge
        return
    end

    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_PET_MERGE , {result = result})
        return
    end

    _remove_pet(self, assist_index, false)
    local addtion = {}
    for i, v in pairs(adv_propertys) do
        addtion[v] = (assist_pet:get(v) - main_pet:get(v)) * MERGE_ADDTION_COEFFICIENT / 100
        if string.match(v, "_quality") then
            addtion[v] = math.ceil(addtion[v])
        else
            addtion[v] = math.floor(addtion[v])
        end

        main_pet:set(v, main_pet:get(v) + addtion[v])
    end

    main_pet.merge_times = main_pet.merge_times + 1
    main_pet:recalc()
    if main_pet:random_field_unlock("Fusepro") then
        if main_pet:field_unlock() then
            self:send_message(const.SC_MESSAGE_LUA_SERVER_INFO , {type = "pet_field_unlock", pet_uid = main_pet:get("entity_id")})
        end
    end

    --检查竞技场防守宠物
    self:check_arena_defend_pet(assist_uid)
    self:imp_seal_write_to_sync_dict(syn_data)
    self:send_message(const.SC_MESSAGE_LUA_PET_MERGE , {result = 0, addtion = addtion, data = syn_data})
    addtion.pet_score = true
    self:update_pet_info_to_pet_rank_list(main_pet, addtion)
end

local function on_pet_free(self, input, syn_data)
    local pet_index = input.pet_index
    local free_uid = input.pet_uid
    local result = 0

    local free_pet = self.pet_list[pet_index]

    if free_pet == nil then
        self:send_message(const.SC_MESSAGE_LUA_PET_MERGE , {result = const.error_pet_not_exist})
        return
    end

    if free_pet:get("entity_id") ~= free_uid then
        if not input.debug then
            result = const.error_pet_uid_not_match
        end
    end

    for i, v in pairs(self.pet_on_fight) do
        if free_uid == v  then
            result = const.error_pet_is_on_fight
            break
        end
    end

    -- 放生宠物不能超过50星
    if free_pet:get("pet_star") > 50 then
        result = const.error_pet_star_too_high
    end

    local num_higer_score = 0
    local free_score = free_pet:get("pet_score")
    for _, pet in pairs(self.pet_list) do
        if pet:get("pet_score") > free_score then
            num_higer_score = num_higer_score + 1
        end
    end
    -- 比放生宠物分数大的不能小于2
    if num_higer_score < 2 then
        result = const.error_pet_score_too_high
    end

    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_PET_FREE , {result = result})
        return
    end

    _remove_pet(self, pet_index, false)
    --检查竞技场防守宠物
    self:check_arena_defend_pet(free_uid)
    self:imp_seal_write_to_sync_dict(syn_data)
    self:send_message(const.SC_MESSAGE_LUA_PET_FREE , {result = 0, data = syn_data})
end

local function on_get_seal_info(self, input, syn_data)
    local info = {}
    self:imp_seal_write_to_sync_dict(info)
    self:send_message(const.SC_MESSAGE_LUA_GET_SEAL_INFO , info)
    self:get_pet_rank_info()
end

local function on_pet_on_fight(self, input, syn_data)
    local pet_index = input.pet_index
    local pet_uid = input.pet_uid
    local result = 0
    local empty_index
    for i = 1, MAX_NUM_ON_FIGHT do
        if self.pet_on_fight[i] == nil  then
            empty_index = i
        elseif self.pet_on_fight[i] == pet_uid then
            result = const.error_pet_already_on_fight
            return self:send_message(const.SC_MESSAGE_LUA_PET_ON_FIGHT , {result = result})
        end
    end

    if empty_index == nil then
        result = const.error_no_pet_on_fight_place
        return self:send_message(const.SC_MESSAGE_LUA_PET_ON_FIGHT , {result = result})
    end

    local pet = self.pet_list[pet_index]
    if pet == nil then
        self:send_message(const.SC_MESSAGE_LUA_PET_MERGE , {result = const.error_pet_not_exist})
        return
    end

    if pet:get("entity_id") ~= pet_uid then
        if not input.debug then
            result = const.error_pet_uid_not_match
            return self:send_message(const.SC_MESSAGE_LUA_PET_ON_FIGHT , {result = result})
        end
    end

    self.pet_on_fight[empty_index] = pet_uid
    self.pet_on_fight_entity[pet_uid] = pet
    pet:set('fight_index', empty_index)
    self:imp_seal_write_to_sync_dict(syn_data, true)
    self:send_message(const.SC_MESSAGE_LUA_PET_ON_FIGHT , {result = 0, data = syn_data})
    --进入场景
    pet:enter_scene(self)
    self:recalc()
    self:imp_property_write_to_sync_dict(syn_data)

    if self.in_fight_server then
        local output = {}
        output.func_name = "on_fight_avatar_pet_on_fight"
        output.data = syn_data
        self:send_to_fight_server( const.GD_MESSAGE_LUA_GAME_RPC, output)
    end
end

local function on_pet_on_rest(self, input, syn_data)
    local pet_index = input.pet_index
    local pet_uid = input.pet_uid
    local result = const.error_pet_not_on_fight
    local on_fight_index

    local pet = self.pet_list[pet_index]
    if pet == nil then
        self:send_message(const.SC_MESSAGE_LUA_PET_MERGE , {result = const.error_pet_not_exist})
        return
    end

    if pet:get("entity_id") ~= pet_uid then
        if not input.debug then
            result = const.error_pet_uid_not_match
        end
    end

    for i = 1, MAX_NUM_ON_FIGHT do
        if self.pet_on_fight[i] == pet_uid  then
            result = 0
            on_fight_index = i
            break
        end
    end

    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_PET_ON_REST , {result = result})
        return
    end

    self.pet_on_fight[on_fight_index] = nil
    self.pet_on_fight_entity[pet_uid] = nil
    pet:set('fight_index', -1)
    self:imp_seal_write_to_sync_dict(syn_data, true)
    self:send_message(const.SC_MESSAGE_LUA_PET_ON_REST , {result = 0, data = syn_data})
    --离开场景
    pet:leave_scene()

    self:recalc()
    self:imp_property_write_to_sync_dict(syn_data)
    if self.in_fight_server then
        local output = {}
        output.func_name = "on_fight_avatarpet_on_rest"
        output.data = syn_data
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, output)
    end
end

local function on_pet_skill_upgrade(self, input, syn_data)
    local pet_index = input.pet_index
    local pet_uid = input.pet_uid
    local skill_index = input.skill_index
    local book_id = input.book_id
    local study_mode = input.study_mode

    local pet = self.pet_list[pet_index]
    if pet == nil then
        self:send_message(const.SC_MESSAGE_LUA_PET_SKILL_UPGRADE , {result = const.error_pet_not_exist, study_mode = study_mode})
        return
    end
    if pet:get("entity_id") ~= pet_uid then
        if not input.debug then
            self:send_message(const.SC_MESSAGE_LUA_PET_SKILL_UPGRADE , {result = const.error_pet_uid_not_match, study_mode = study_mode})
            return
        end
    end

    local book_attrib = item_scheme[book_id]
    if book_attrib == nil then
        flog("error", "on_pet_skill_upgrade: book id is wrong "..book_id)
        self:send_message(const.SC_MESSAGE_LUA_PET_SKILL_UPGRADE , {result = const.error_impossible_param, study_mode = study_mode})
        return
    end
    local book_skill_type = math.floor(tonumber(book_attrib.Para1))
    local book_skill_id = math.floor(tonumber(book_attrib.Para2))

    local rst, items_need, self_skill_index = pet:pet_skill_upgrade_cost(skill_index, book_id, book_skill_id, book_skill_type, study_mode)
    if rst ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_PET_SKILL_UPGRADE , {result = rst, study_mode = study_mode})
        return
    end

    local items_lack = {}
    local is_enough = true
    for item_id, count in pairs(items_need) do
        if not self:is_enough_by_id(item_id, count) then
            is_enough = false
            table.insert(items_lack, item_id)
        end
    end

    if not is_enough then
        self:send_message(const.SC_MESSAGE_LUA_PET_SKILL_UPGRADE , {result = const.error_item_not_enough, items_lack = items_lack, study_mode = study_mode})
        return
    end

    --扣除材料
    for item_id, count in pairs(items_need) do
        self:remove_item_by_id(item_id, count)
    end
    local final_skill_index = pet:pet_skill_upgrade(skill_index, self_skill_index, book_skill_id, book_skill_type, study_mode)
    self:send_message(const.SC_MESSAGE_LUA_PET_SKILL_UPGRADE , {result = 0, study_mode = study_mode, skill_index = final_skill_index})

    local unlock_name
    if study_mode == "study" then
        unlock_name = "Studypro"
    elseif study_mode == "upgrade" then
        unlock_name = "SkillUppro"
    else
        flog("error", "pet_skill_upgrade_cost : error study_mode "..study_mode)
    end
    if pet:random_field_unlock(unlock_name) then
        if pet:field_unlock() then
            self:send_message(const.SC_MESSAGE_LUA_SERVER_INFO , {type = "pet_field_unlock", pet_uid = pet:get("entity_id")})
        end
    end

    self:imp_seal_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
end

local function on_pet_field_unlock(self, input, syn_data)
    local pet_index = input.pet_index
    local pet_uid = input.pet_uid

    local pet = self.pet_list[pet_index]
    if pet == nil then
        self:send_message(const.SC_MESSAGE_LUA_PET_FIELD_UNLOCK , {result = const.error_pet_not_exist})
        return
    end
    if pet:get("entity_id") ~= pet_uid then
        if not input.debug then
            self:send_message(const.SC_MESSAGE_LUA_PET_FIELD_UNLOCK , {result = const.error_pet_uid_not_match})
            return
        end
    end

    local rst, items_need = pet:pet_field_unlock_cost()
    if rst ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_PET_FIELD_UNLOCK , {result = rst})
        return
    end

    local items_lack = {}
    local is_enough = true
    for item_id, count in pairs(items_need) do
        if not self:is_enough_by_id(item_id, count) then
            is_enough = false
            table.insert(items_lack, item_id)
        end
    end

    if not is_enough then
        self:send_message(const.SC_MESSAGE_LUA_PET_FIELD_UNLOCK , {result = const.error_item_not_enough, items_lack = items_lack})
        return
    end

    --扣除材料
    for item_id, count in pairs(items_need) do
        self:remove_item_by_id(item_id, count)
    end
    local is_success, field = pet:field_unlock()
    self:send_message(const.SC_MESSAGE_LUA_PET_FIELD_UNLOCK , {result = 0, field = field})
    self:imp_seal_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
end


local function on_scene_loaded(self, input, syn_data)
    self.last_capture_time = 0
end

function imp_seal.__ctor(self)
    self.pet_list = {}
    self.pet_on_fight = {}
    self.pet_id_capturing = nil
    self.pet_level_capturing = nil
    self.start_time = nil
    self.cap_timer = nil
    self.capture_times = 0
    self.addition_rate_total = 0
    self.pet_on_fight_entity = {}
end

function imp_seal.imp_seal_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    self.pet_on_fight = table.copy(table.get(dict, "pet_on_fight", {}))

    local dict_pet_list = table.get(dict, "pet_list", {})
    for i, v in ipairs(dict_pet_list) do
        local entity = entity_factory.create_entity(const.ENTITY_TYPE_PET)
        if entity ==  nil then
            flog("error", "imp_seal_init_from_dict: Failed create pet ")
            return const.error_create_pet_fail
        end
        entity:init_from_dict(v)
        entity:set_owner_id(self.actor_id)
        table.insert(self.pet_list, entity)
    end

    local ban_fight_pet_list = table.get(dict,"ban_fight_pet_list",{})
    self.ban_fight_pet_list = {}
    for i, v in ipairs(ban_fight_pet_list) do
        local entity = entity_factory.create_entity(const.ENTITY_TYPE_PET)
        if entity ==  nil then
            flog("error", "imp_seal_init_from_dict: Failed create ban fight pet ")
            return const.error_create_pet_fail
        end
        entity:init_from_dict(v)
        entity:set_owner_id(self.actor_id)
        table.insert(self.ban_fight_pet_list, entity)
    end

    for _, pet_entity_id in pairs(self.pet_on_fight) do
        local pet,is_ban_fight,index = self:find_pet_and_index(pet_entity_id)
        self.pet_on_fight_entity[pet_entity_id] = pet
    end

    update_params(self, self.seal_phase, self.seal_level)

end

function imp_seal.imp_seal_init_from_other_game_dict(self,dict)
    self:imp_seal_init_from_dict(dict)
end

function imp_seal.imp_seal_write_to_dict(self, dict, to_other_game)
    _calc_capture_energy(self)
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

    dict.pet_on_fight = table.copy(self.pet_on_fight)

    local dict_pet_list = {}
    for i, v in ipairs(self.pet_list) do
        local t = {}
        v:write_to_dict(t)
        table.insert(dict_pet_list, t)
    end
    dict.pet_list = dict_pet_list

    local dict_ban_fight_pet_list = {}
    for i,v in ipairs(self.ban_fight_pet_list) do
        local _pet_info = {}
        v:write_to_dict(_pet_info)
        table.insert(dict_ban_fight_pet_list,_pet_info)
    end
    dict.ban_fight_pet_list = dict_ban_fight_pet_list
end

function imp_seal.imp_seal_write_to_other_game_dict(self,dict)
    self:imp_seal_write_to_dict(dict, true)
end

function imp_seal.imp_seal_write_to_sync_dict(self, dict, no_pet)
    _calc_capture_energy(self)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end

    dict.pet_on_fight = table.copy(self.pet_on_fight)

    if no_pet then
        dict.pet_on_fight_entity = {}
        for pet_uid, pet in pairs(self.pet_on_fight_entity) do
            local t = {}
            pet:write_to_sync_dict(t)
            dict.pet_on_fight_entity[pet_uid] = t
        end
        return
    end

    local dict_pet_list = {}
    for i, v in ipairs(self.pet_list) do
        local t = {}
        v:write_to_sync_dict(t)
        table.insert(dict_pet_list, t)
    end
    dict.pet_list = dict_pet_list

    local dict_ban_fight_pet_list = {}
    for i,v in ipairs(self.ban_fight_pet_list) do
        local _pet_info = {}
        v:write_to_dict(_pet_info)
        table.insert(dict_ban_fight_pet_list,_pet_info)
    end
    dict.ban_fight_pet_list = dict_ban_fight_pet_list
    dict.defend_pet = self.defend_pet
end

function imp_seal.gm_pet_upgrade(self, pet_pos, new_level)
    if pet_pos == "all" then
        for _, pet in self.pet_list do
            pet:upgrade(new_level)
            if pet:random_field_unlock("Upgradepro") then
                if pet:field_unlock() then
                    self:send_message(const.SC_MESSAGE_LUA_SERVER_INFO , {type = "pet_field_unlock", pet_uid = pet:get("entity_id")})
                end
            end
        end
    else
        local pet = self.pet_list[pet_pos]
        pet:upgrade(new_level)
        if pet:random_field_unlock("Upgradepro") then
            if pet:field_unlock() then
                self:send_message(const.SC_MESSAGE_LUA_SERVER_INFO , {type = "pet_field_unlock", pet_uid = pet:get("entity_id")})
            end
        end
    end

    local info = {}
    self:imp_seal_write_to_sync_dict(info)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
    return 0
end

function imp_seal.gm_add_pet(self, pet_id, level)
    _get_new_pet(self,const.PET_OUTPUT_TYPE.Wild, pet_id, level)

    local info = {}
    self:imp_seal_write_to_sync_dict(info)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
    return 0
end

function imp_seal.add_pet(self,output_type,pet_id,level)
    if #self.pet_list >= self.seal_size then
        return const.error_pet_overflow
    end
    flog("salog", "Use egg add pet "..pet_id, self.actor_id)
     _get_new_pet(self, output_type,pet_id, level)
    return 0
end

function imp_seal.pet_enter_scene(self)
    for _, pet in pairs(self.pet_on_fight_entity) do
        pet:enter_scene(self)
    end
end

function imp_seal.pet_leave_scene(self)
    flog("tmlDebug","imp_seal.pet_leave_scene")
    for _, pet in pairs(self.pet_on_fight_entity) do
        flog("tmlDebug","imp_seal.pet_leave_scene entity_id "..pet.entity_id)
        pet:leave_scene()
    end
end

--谨慎使用，只有在玩家进入场景异常时使用
function imp_seal.pet_leave_scene_by_id(self,scene_id)
    flog("tmlDebug","imp_seal.pet_leave_scene")
    for _, pet in pairs(self.pet_on_fight_entity) do
        flog("tmlDebug","imp_seal.pet_leave_scene entity_id "..pet.entity_id)
        pet:leave_scene_by_id(scene_id)
    end
end

function imp_seal.get_pet_info(self,entity_id)
    for i,pet in pairs(self.pet_list) do
        if pet.entity_id == entity_id then
            local pet_info = {}
            pet:write_to_dict(pet_info)
            return pet_info
        end
    end
    return nil
end

function imp_seal.is_have_pet(self,entity_id)
    for i,pet in pairs(self.pet_list) do
        if pet.entity_id == entity_id then
            return true
        end
    end
    return false
end

function imp_seal.find_pet_and_index(self,entity_id)
    for i=1,#self.pet_list,1 do
        local pet = self.pet_list[i]
        if pet.entity_id == entity_id then
            return pet,false,i
        end
    end
    for i=1,#self.ban_fight_pet_list,1 do
        local pet = self.ban_fight_pet_list[i]
        if pet.entity_id == entity_id then
            return pet,true,i
        end
    end
    return nil
end

function imp_seal.is_seal_energy_full(self)
    return self.energy_ceiling <= self.capture_energy
end

function imp_seal.add_capture_energy(self,addon)
    self.capture_energy = self.capture_energy + addon
    if self.capture_energy < 0 then
        self.capture_energy = 0
    end
end

function imp_seal.refresh_pet_rank_info(self, input)
    local pet_rank_info = input.pet_rank_info

    local changed_pet = {}
    local is_changed = false
    for i,pet in pairs(self.pet_list) do
        local pet_info = pet_rank_info[pet.entity_id]
        if pet_info ~= nil then
            if pet.highest_property_rank ~= pet_info.highest_property_rank or pet.pet_score_rank ~= pet_info.pet_score_rank then
                is_changed = true
                pet.highest_property_rank = pet_info.highest_property_rank
                pet.pet_score_rank = pet_info.pet_score_rank
            end
        end

        local is_still_avaliable = pet:is_pet_appearance_available(pet.pet_appearance)
        if not is_still_avaliable then
            pet.pet_appearance = 1
            changed_pet[pet.entity_id] = pet.pet_appearance
        end
    end
    if not table.isEmptyOrNil(changed_pet) then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "PetAppearanceChanged", changed_pet = changed_pet})
    end

    if is_changed then
        local info = {}
        self:imp_seal_write_to_sync_dict(info)
        self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
    end
end

function imp_seal.get_pet_rank_info(self)
    local pet_info_list = {}
    for i,pet in pairs(self.pet_list) do
        if pet.highest_property_rank ~= -1 or pet.pet_score_rank ~= -1 then
            local pet_info = {}
            pet_info.pet_id = pet.pet_id
            pet_info.entity_id = pet.entity_id
            table.insert(pet_info_list, pet_info)
        end
    end

    local output = {func_name = "get_pet_rank_info" }
    output.pet_list = pet_info_list
    self:send_message_to_ranking_server(output)
end

function imp_seal.update_pet_info_to_pet_rank_list(self, pet, key_list)
    local output = {func_name = "update_to_pet_rank_list" }
    pet:imp_pet_write_to_dict(output)
    output.owner_name = self.actor_name
    output.owner_id = self.actor_id
    self:send_message_to_ranking_server(output)
    self:update_pet_value_to_rank_list(pet, key_list)
end

function imp_seal.on_get_pet_rank_list(self, input)
    local entity_id = input.pet_uid
    local rank_name = input.rank_name
    local pet = self:find_pet_and_index(entity_id)
    local self_data = {}
    self_data.value = pet:get(rank_name)
    self_data.owner_name = self.actor_name
    self_data.owner_id = self.actor_id
    self_data.id = entity_id
    self_data.pet_name = pet.pet_name
    input.func_name = "get_pet_rank_list"
    input.self_data = self_data
    self:send_message_to_ranking_server(input)
end

function imp_seal.on_buy_pet_appearance(self, input, syn_data)
    local appearance_rank = input.appearance_rank
    local time_mode = input.time_mode
    local pet_uid = input.pet_uid

    local pet = self:find_pet_and_index(pet_uid)

    if pet == nil then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "BuyPetAppearanceRet", result = const.error_pet_not_exist})
        return
    end

    local result = pet:pet_appearance_buyable(appearance_rank)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "BuyPetAppearanceRet", result = result})
        return
    end

    local cost = pet:get_pet_appearance_cost(appearance_rank, time_mode)
    local is_enough, items_lack = self:is_all_cost_enough(cost)
    if not is_enough then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "BuyPetAppearanceRet", result = const.error_item_not_enough, items_lack = items_lack})
        return
    end

    for item_id, count in pairs(cost) do
        self:remove_item_by_id(item_id, count)
    end
    pet:buy_pet_appearance_success(appearance_rank, time_mode)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "BuyPetAppearanceRet", result = 0})
    --self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "PetAppearanceChanged", changed_pet = {[pet.entity_id] = pet.pet_appearance}})
    self:imp_assets_write_to_sync_dict(syn_data)
    self:imp_seal_write_to_sync_dict(syn_data)
end


function imp_seal.on_change_pet_appearance(self, input, syn_data)
    local appearance_rank = input.appearance_rank
    local pet_index = input.pet_index
    local pet_uid = input.pet_uid

    local pet = self:find_pet_and_index(pet_uid)
    if pet == nil then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "ChangePetAppearanceRet", result = const.error_pet_not_exist})
        return
    end

    local is_avaliable = pet:is_pet_appearance_available(appearance_rank)
    if not is_avaliable then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "ChangePetAppearanceRet", result = const.error_pet_appearance_condition_not_fulfilled})
        return
    end
    pet.pet_appearance = appearance_rank
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "PetAppearanceChanged", changed_pet = {[pet.entity_id] = pet.pet_appearance}})
    self:imp_seal_write_to_sync_dict(syn_data)
end

function imp_seal.gm_set_capture_energy(self, capture_energy)
    self.capture_energy = capture_energy
end

function imp_seal.generate_new_pet_with_type(self, input)
    local init_info = input.init_info
    local output_type = init_info.output_type
    local pet_create_type = input.pet_create_type

    local entity = entity_factory.create_entity(const.ENTITY_TYPE_PET)
    if entity ==  nil then
        flog("error", "generate_new_pet_with_type : Failed create pet ")
        return const.error_create_pet_fail
    end
    init_info.entity_id = entity.entity_id
    flog("salog", string.format("Get pet %d, uid %s, create type %s", init_info.pet_id, init_info.entity_id, pet_create_type), self.actor_id)

    entity:init_from_dict(init_info)
    entity:set_owner_id(self.actor_id)
    entity:create_new_pet(pet_create_type)
    if output_type == const.PET_OUTPUT_TYPE.Stuff then
        table.insert(self.ban_fight_pet_list, entity)
    else
        table.insert(self.pet_list, entity)
        self:update_pet_info_to_pet_rank_list(entity)
    end

    local info = {}
    self:imp_seal_write_to_sync_dict(info)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
end

function imp_seal.fight_pet_get_exp(self, exp)
    for _, pet in pairs(self.pet_on_fight_entity) do
        pet:get_exp(exp, self.level)
    end
end

function imp_seal.get_pet_number(self)
    return #self.pet_list
end

function imp_seal.get_seal_level(self)
    return self.seal_level + (self.seal_phase - 1)*10
end

function imp_seal.on_pet_use_exp_pill(self, input, syn_data)
    local item_id = input.item_id
    local pet_uid = input.pet_uid

    local pill_attrib = item_scheme[item_id]
    local output = {func_name = "PetUseExpPillRet", result = 0}
    if pill_attrib == nil or pill_attrib.Type ~= const.TYPE_EXP_PILL then
        output.result = const.error_not_pet_exp_pill
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    local pet = self:find_pet_and_index(pet_uid)
    if pet == nil then
        output.result = const.error_pet_not_exist
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    if not pet:is_pet_upgradeable(self.level) then
        output.result = const.error_pet_level_too_high
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    if self.level < pill_attrib.LevelLimit then
        output.result = const.error_level_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    if not self:is_enough_by_id(item_id, 1) then
        output.result = const.const.error_item_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    self:remove_item_by_id(item_id, 1)
    pet:get_exp(tonumber(pill_attrib.Para1), self.level)
    self:imp_assets_write_to_sync_dict(syn_data)
    self:imp_seal_write_to_sync_dict(syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function imp_seal.gm_get_pet_score_detail(self, pos)
    local pet = self.pet_list[pos]
    if pet == nil then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "ServerTipsMessage", message = "No pet in position "..pos})
    end
    local message = string.format("pet_name is %s, pet score detail is %s", pet.pet_name, pet.score_debug_detail)
    self:imp_chat_send_gm_message(message, false, false)
end

function imp_seal.gm_get_pet_property(self, pos)
    local pet = self.pet_list[pos]
    if pet == nil then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "ServerTipsMessage", message = "No pet in position "..pos})
    end
    local message = self:get_property_str()
    self:imp_chat_send_gm_message(message, false, false)
end

function imp_seal.rebirth_pet(self,entity_id)
    if self.pet_on_fight_entity[entity_id] ~= nil then
        self.pet_on_fight_entity[entity_id]:reset_rebirth_time()
        self.pet_on_fight_entity[entity_id]:enter_scene(self)
    else
        for i=1,#self.pet_list,1 do
            if self.pet_list[i].entity_id == entity_id then
                self.pet_list[i]:reset_rebirth_time()
                break
            end
        end
    end
    return true
end

function imp_seal.send_fight_pet_to_client(self)
    local dict = {}
    dict.result = 0
    dict.pet_on_fight_entity = {}
    for pet_uid, pet in pairs(self.pet_on_fight_entity) do
        local t = {}
        pet:write_to_sync_dict(t)
        dict.pet_on_fight_entity[pet_uid] = t
    end
    self:send_message(const.SC_MESSAGE_LUA_UPDATE,dict)
end

register_message_handler(const.CS_MESSAGE_LUA_START_CAPTURE_PET, on_start_capture)
register_message_handler(const.CS_MESSAGE_LUA_CAPTURE_RET, on_capture)
register_message_handler(const.CS_MESSAGE_LUA_CANCEL_CAPTURE, on_cancel_capture)
register_message_handler(const.CS_MESSAGE_LUA_SEAL_UPGRADE, on_seal_upgrade)
register_message_handler(const.CS_MESSAGE_LUA_PET_DEVOUR, on_pet_devour)
register_message_handler(const.CS_MESSAGE_LUA_PET_MERGE, on_pet_merge)
register_message_handler(const.CS_MESSAGE_LUA_GET_SEAL_INFO, on_get_seal_info)
register_message_handler(const.CS_MESSAGE_LUA_PET_FREE, on_pet_free)
register_message_handler(const.CS_MESSAGE_LUA_PET_ON_FIGHT, on_pet_on_fight)
register_message_handler(const.CS_MESSAGE_LUA_PET_ON_REST, on_pet_on_rest)
register_message_handler(const.CS_MESSAGE_LUA_PET_SKILL_UPGRADE, on_pet_skill_upgrade)
register_message_handler(const.CS_MESSAGE_LUA_PET_FIELD_UNLOCK, on_pet_field_unlock)
register_message_handler(const.CS_MESSAGE_LUA_LOADED_SCENE,on_scene_loaded)
register_message_handler(const.CS_MESSAGE_LUA_LOGIN, on_player_login)
register_message_handler(const.CS_MESSAGE_LUA_PREPARE_CAPTURE_PET, on_prepare_capture)

imp_seal.__message_handler = {}
imp_seal.__message_handler.on_start_capture = on_start_capture
imp_seal.__message_handler.on_capture = on_capture
imp_seal.__message_handler.on_cancel_capture = on_cancel_capture
imp_seal.__message_handler.on_seal_upgrade = on_seal_upgrade
imp_seal.__message_handler.on_pet_devour = on_pet_devour
imp_seal.__message_handler.on_pet_merge = on_pet_merge
imp_seal.__message_handler.on_get_seal_info = on_get_seal_info
imp_seal.__message_handler.on_pet_free = on_pet_free
imp_seal.__message_handler.on_pet_on_fight = on_pet_on_fight
imp_seal.__message_handler.on_pet_on_rest = on_pet_on_rest
imp_seal.__message_handler.on_pet_skill_upgrade = on_pet_skill_upgrade
imp_seal.__message_handler.on_pet_field_unlock = on_pet_field_unlock
imp_seal.__message_handler.on_scene_loaded = on_scene_loaded
imp_seal.__message_handler.on_player_login = on_player_login
imp_seal.__message_handler.on_prepare_capture = on_prepare_capture

return imp_seal