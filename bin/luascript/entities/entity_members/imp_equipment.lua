--------------------------------------------------------------------
-- 文件名:	imp_quipment.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/26
-- 描  述:	装备模块
--------------------------------------------------------------------
require "math"
local const = require "Common/constant"
local flog = require "basic/log"
local create_item = require "entities/items/item"
local equipment_strengthen_scheme = require "data/equipment_strengthen"
local equipment_star_scheme = require "data/equipment_star"
local equipment_refine = require "data/equipment_refine"
local equipment_gem_table = require "data/equipment_jewel"
local equipment_attributes = require("data/equipment_base").Attribute
local equipment_template = require("data/equipment_base").equipTemplate
local item_scheme = require("data/common_item").Item
local common_parameter_formula = require "data/common_parameter_formula"
local common_parameter_formula_config = require "configs/common_parameter_formula_config"
local equipment_strengthen_config = require "configs/equipment_strengthen_config"

local scheme_fun = require "basic/scheme"
local create_add_up_table = scheme_fun.create_add_up_table
local get_random_index_with_weight_by_count = scheme_fun.get_random_index_with_weight_by_count
local string_split = scheme_fun.string_split
local gem_shape_configs = equipment_gem_table.GemShape
local system_parameter = common_parameter_formula.Parameter
local tonumber = tonumber
local math = math

local params = {
    equipment_score = {db=true,sync=true,default=0}
}

local equip_name_to_type = const.equip_name_to_type

local equip_type_to_name = const.equip_type_to_name

local PROPERTY_INDEX_TO_NAME = const.PROPERTY_INDEX_TO_NAME
local PROPERTY_NAME_TO_INDEX = const.PROPERTY_NAME_TO_INDEX

local property_name_to_index = const.PROPERTY_NAME_TO_INDEX
local gem_slot_state = const.GEM_SLOT_STATE
local equipment_attribute_value_type = const.EQUIPMENT_ATTRIBUTE_VALUE_TYPE

--装备基础
--属性汇总
local equipment_base_attibutes = {}
for _,attribute in pairs(equipment_attributes) do
    equipment_base_attibutes[attribute.ID] = attribute
end

--强化、升星常数
local MAX_STRENGTHEN_LEVEL = 9
local MAX_EQUIPMENT_STAR = 9
local MAX_GEM_SLOT = 9
local MIN_GEM_SLOT = 4

--强化失败等级掉落
local weight_table_equip_strengthen_drop = {}
for i, v in ipairs(equipment_strengthen_scheme.DropLevel) do
    table.insert(weight_table_equip_strengthen_drop, v.weight)
end
local add_up_equip_strengthen_drop = create_add_up_table(weight_table_equip_strengthen_drop)
local function get_equip_strengthen_drop(max_level)
    local index = get_random_index_with_weight_by_count(add_up_equip_strengthen_drop,max_level)
    return index
end

--洗练消耗
local equip_refine_cost = {}
for i,v in pairs(equipment_refine.Cost) do
    if equip_refine_cost[v.part] == nil then
        equip_refine_cost[v.part] = {}
    end
    equip_refine_cost[v.part][v.levelmin] = v
end

local equipment_attribute_table = {}
for i,v in pairs(equipment_attributes) do
    equipment_attribute_table[v.ID] = v
end

--开孔消耗
local equip_gem_open = {}
for _,v in pairs(equipment_gem_table.Openings) do
    equip_gem_open[v.GemGroove] = v
end

--宝石加工产生格子数
local carve_gem_grid_number = {}
local carve_gem_grid_weight = {}
for _,v in pairs(equipment_gem_table.Machining) do
    if carve_gem_grid_number[v.Level] == nil then
        carve_gem_grid_number[v.Level] = {}
    end
    carve_gem_grid_number[v.Level][v.Grid] = {}
    if carve_gem_grid_weight[v.Level] == nil then
        carve_gem_grid_weight[v.Level] = {}
    end
    carve_gem_grid_weight[v.Level][v.Grid] = {}
    local tmp_carve_gem_grid_weight = {}
    table.insert(carve_gem_grid_number[v.Level][v.Grid],1)
    table.insert(tmp_carve_gem_grid_weight,v.weight1)
    table.insert(carve_gem_grid_number[v.Level][v.Grid],2)
    table.insert(tmp_carve_gem_grid_weight,v.weight2)
    table.insert(carve_gem_grid_number[v.Level][v.Grid],3)
    table.insert(tmp_carve_gem_grid_weight,v.weight3)
    table.insert(carve_gem_grid_number[v.Level][v.Grid],4)
    table.insert(tmp_carve_gem_grid_weight,v.weight4)
    carve_gem_grid_weight[v.Level][v.Grid] = create_add_up_table(tmp_carve_gem_grid_weight)
end

--宝石格子数-形状配置
local gem_shape_grid_number = {}
local gem_shape_shape_express = {}
for _,v in pairs(equipment_gem_table.GemShape) do
    if gem_shape_grid_number[v.Grid] == nil then
        gem_shape_grid_number[v.Grid] = {}
    end
    table.insert(gem_shape_grid_number[v.Grid],v.ShapeID)
end

--宝石产生格子数权重
local gem_grid_number = {}
local gem_grid_number_weight = {}
for _,v in pairs(equipment_gem_table.GemLevel) do
    if gem_grid_number[v.Level] == nil then
        gem_grid_number[v.Level] = {}
        local tmp_gem_grid_number = {}
        table.insert(gem_grid_number[v.Level],1)
        table.insert(tmp_gem_grid_number,v.weight1)
        table.insert(gem_grid_number[v.Level],2)
        table.insert(tmp_gem_grid_number,v.weight2)
        table.insert(gem_grid_number[v.Level],3)
        table.insert(tmp_gem_grid_number,v.weight3)
        table.insert(gem_grid_number[v.Level],4)
        table.insert(tmp_gem_grid_number,v.weight4)
        gem_grid_number_weight[v.Level] = create_add_up_table(tmp_gem_grid_number)
    end
end

local function get_gem_grid_number(level)
    local grid_num = 0
    if gem_grid_number_weight[level] ~= nil then
        grid_num = gem_grid_number[level][get_random_index_with_weight_by_count(gem_grid_number_weight[level])]
    end
    return grid_num
end

--宝石类型配置
local gem_type_configs = {}
local gem_type_normal = {}
local gem_type_special = {}
--混沌石鉴定结果权重
local chaos_stone_identify_results = {}
local chaos_stone_identify_results_weight = {}
local tmp_chaos_stone_identify_results_weight = {}
for _,v in pairs(equipment_gem_table.GemType) do
    gem_type_configs[v.GemID] = v
    table.insert(chaos_stone_identify_results,v.GemID)
    table.insert(tmp_chaos_stone_identify_results_weight,v.Checkweight)
    if v.type == const.GEM_BIG_TYPE.normal then
        table.insert(gem_type_normal,v.GemID)
    else
        table.insert(gem_type_special,v.GemID)
    end
end
chaos_stone_identify_results_weight = create_add_up_table(tmp_chaos_stone_identify_results_weight)
local function get_chaos_stone_identify_result()
    return chaos_stone_identify_results[get_random_index_with_weight_by_count(chaos_stone_identify_results_weight)]
end

--宝石数值（属性等）配置
local gem_value_configs = {}
for _,v in pairs(equipment_gem_table.GemValue) do
    if gem_value_configs[v.GemID] == nil then
        gem_value_configs[v.GemID] = {}
    end
    gem_value_configs[v.GemID][v.Level] = v
end

--宝石最大等级
local max_gem_level = 1
--混沌石与等级对应表
local chaos_stone_level = {}
--宝石等级配置表
local gem_level_configs = {}
for _,v in pairs(equipment_gem_table.GemLevel) do
    gem_level_configs[v.Level] = v
    chaos_stone_level[v.TestItem] = v
    if v.Level > max_gem_level then
        max_gem_level = v.Level
    end
end

--宝石配置文件
local gem_configs = {}
local item_scheme_params = {}
--物品id对应宝石数据
local item_gem_configs = {}
for _,v in pairs(item_scheme) do
    if v.Type == const.TYPE_GEM then
        item_scheme_params = string_split(v.Para1,"|")
        if #item_scheme_params ~= 2 then
            _error(string.format("equipment gem config error!id=%d",v.ID))
        else
            local gid = tonumber(item_scheme_params[1])
            local glevel = tonumber(item_scheme_params[2])
            local gshape = tonumber(v.Para2)
            if gid == nil or glevel == nil or gshape == nil then
                _error(string.format("equipment gem config error!id=%d",v.ID))
            else
                local gid_cfg = gem_type_configs[gid]
                local glevel_cfg = gem_level_configs[glevel]
                local gshape_cfg = gem_shape_configs[gshape]
                if gid_cfg == nil or glevel_cfg == nil or gshape_cfg == nil then
                    _error(string.format("equipment gem config error!item_id=%d,gid=%d,glevel=%d,gshape=%d",v.ID,gid,glevel,gshape))
                else
                    if gem_configs[gid] == nil then
                        gem_configs[gid] = {}
                    end
                    if gem_configs[gid][glevel] == nil then
                        gem_configs[gid][glevel] = {}
                    end
                    gem_configs[gid][glevel][gshape] = v.ID
                    item_gem_configs[v.ID] = {}
                    item_gem_configs[v.ID].gem_id = gid
                    item_gem_configs[v.ID].gem_level = glevel
                    item_gem_configs[v.ID].gem_shape = gshape
                    item_gem_configs[v.ID].attribute_index = gid_cfg.AttriID --宝石是logic id
--                    if equipment_base_attibutes[gid_cfg.AttriID] ~= nil then
--                        item_gem_configs[v.ID].attribute_index = equipment_base_attibutes[gid_cfg.AttriID].LogicID
--                    end

                    item_gem_configs[v.ID].attribute_value_type = equipment_attribute_value_type.normal
--                    if equipment_base_attibutes[gid_cfg.AttriID] ~= nil then
--                        item_gem_configs[v.ID].attribute_value_type = equipment_base_attibutes[gid_cfg.AttriID].ValueType
--                    end
                    item_gem_configs[v.ID].attribute_value = 0
                    if gem_value_configs[gid] ~= nil and gem_value_configs[gid][glevel] ~= nil then
                        item_gem_configs[v.ID].attribute_value = gem_value_configs[gid][glevel].Num
                    end
                end
            end

        end
    end
end

local imp_equipment = {}
imp_equipment.__index = imp_equipment

setmetatable(imp_equipment, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_equipment.__params = params

local function recalculate_equipment_score(self)
    local property_addtion = {}
    for ename, _ in pairs(equip_name_to_type) do
        if self[ename] ~= nil then
            local single_addition = {}
            local percent_addition = {}
            local strengthen_additional = {} --强化加成

            --计算基础属性加成
            local base_prop = self[ename]:get_base_prop()
            if base_prop ~= nil then
                for j, p in pairs(base_prop) do
                    --基础属性
                    if single_addition[j] ~= nil then
                        single_addition[j] = single_addition[j] + p
                    else
                        single_addition[j] = p
                    end
                end
            end

            --计算洗练属性加成
            local additional_prop = self[ename]:get_additional_prop()
            if additional_prop ~= nil then
                --洗练属性结构(1 属性索引，2 属性值，3是否稀有，4属性值类型)
                for j, p in pairs(additional_prop) do
                    if p[4] == 2 then       --value_type为2的是正常属性加成
                        if single_addition[p[1]] ~= nil then
                            single_addition[p[1]] = single_addition[p[1]] + p[2]
                        else
                            single_addition[p[1]] = p[2]
                        end
                    elseif p[4] ==1 then        --value_type为1的是百分比属性加成
                        if percent_addition[p[1]] ~= nil then
                            percent_addition[p[1]] = percent_addition[p[1]] + p[2]
                        else
                            percent_addition[p[1]] = p[2]
                        end
                    end
                end
            end

            --洗练属性中万分比加成
            for j, p in pairs(percent_addition) do
                local s_value = single_addition[j]
                if s_value ~= nil then
                    single_addition[j] = s_value + math.floor(s_value * p / 10000)
                end
            end

            for j,p in pairs(strengthen_additional) do
                if single_addition[j] == nil then
                    single_addition[j] = p
                else
                    single_addition[j] = single_addition[j] + p
                end
            end

            --单装备属性加成加入总表
            for j,p in pairs(single_addition) do
                if property_addtion[j] ~= nil then
                    property_addtion[j] = property_addtion[j] + p
                else
                    property_addtion[j] = p
                end
            end
        end
    end
    local hp = 0
	local mp = 0
	local attack = 0
	local defence = 0
	local fight_property = 0
	local element_attack = 0
	local element_defence = 0
	for property,value in pairs(property_addtion) do
		if property == PROPERTY_NAME_TO_INDEX.hp_max then
			hp = hp + value
		end
		if property == PROPERTY_NAME_TO_INDEX.mp_max then
			mp = mp + value
		end
		if property == PROPERTY_NAME_TO_INDEX.physic_attack or property == PROPERTY_NAME_TO_INDEX.magic_attack then
			attack = attack + value
		end
		if property == PROPERTY_NAME_TO_INDEX.physic_defence or property == PROPERTY_NAME_TO_INDEX.magic_defence then
			defence = defence + value
		end
		if property >= PROPERTY_NAME_TO_INDEX.hit and property <= PROPERTY_NAME_TO_INDEX.guardian then
			fight_property = fight_property + value
		end
		if property >= PROPERTY_NAME_TO_INDEX.gold_attack and property <= PROPERTY_NAME_TO_INDEX.dark_attack then
			element_attack = element_attack + value
		end
		if property >= PROPERTY_NAME_TO_INDEX.gold_defence and property <= PROPERTY_NAME_TO_INDEX.dark_defence then
			element_defence = element_defence + value
		end
	end
	self.equipment_score = common_parameter_formula_config.calculate_equip_score(hp,mp,attack,defence,fight_property,element_attack,element_defence)
end

local function on_load_equipment(self, input, syn_data)
    local item_pos = input.item_pos
    local item = self:get_item_by_pos(item_pos)
    local result = 0
    if item == nil then
        result = const.error_no_item_in_pos
        self:send_message(const.SC_MESSAGE_LUA_LOAD_EQUIPMENT , {result = result})
        return result
    end
    local part_name = item:get_equipment_part_name()
    if part_name == nil then
        flog("error", "on_load_equipment: this is not a equipment ,pos "..item_pos)
        result = const.error_item_can_not_equip
        return
    end

    local equipable_rst = item:is_equipable(self.level, self.vocation)
    if result == 0 then
        result = equipable_rst
    end

    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_LOAD_EQUIPMENT , {result = result})
        return result
    end
    self:clear_by_pos(item_pos)
    if self[part_name] ~= nil then
        self:add_item(item_pos, self[part_name])
    end
    self[part_name] = item

    self:send_message(const.SC_MESSAGE_LUA_LOAD_EQUIPMENT , {result = result})
    recalculate_equipment_score(self)
    self:recalc()
    self:imp_property_write_to_sync_dict(syn_data)
    self:imp_equipment_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
    self:update_task_system_operation(const.TASK_SYSTEM_OPERATION.dress_equipment)
    self:update_player_value_to_rank_list("equipment_score")
end

local function on_unload_equipment(self, input, syn_data)
    local empty_pos = self:get_first_empty()
    local result = 0
    if empty_pos == nil then
        result = const.error_no_empty_cell
    end

    local equip_type = input.equip_type
    local part_name = equip_type_to_name[equip_type]
    if part_name == nil then
        result = const.error_equip_type_wrong
    end
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_UNLOAD_EQUIPMENT , {result = result})
        return result
    end

    self:add_item(empty_pos, self[part_name])
    self[part_name] = nil

    self:send_message(const.SC_MESSAGE_LUA_UNLOAD_EQUIPMENT , {result = result})
    self:recalc()
    self:imp_property_write_to_sync_dict(syn_data)
    self:imp_equipment_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
end

local function on_strengthen_equipment(self,input,syn_data)
    local result = 0
    local equip_type = input.equip_type
    local part_name = equip_type_to_name[equip_type]
    if part_name == nil then
        result = const.error_equip_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result})
        return result
    end

    --没有装备
    if self[part_name] == nil then
        result =const.error_equip_unload
        self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result,equip_type = input.equip_type})
        return result
    end

    local current_stage = 1
    local current_level = 0
    local old_stage = current_stage
    local old_level = current_level
    if self.equipment_strengthen[part_name] ~= nil then
        current_stage = self.equipment_strengthen[part_name].stage
        current_level = self.equipment_strengthen[part_name].level
    end

    --升到最高级了
    if current_stage >= equipment_strengthen_config.get_max_strengthen_stage() and current_level >= MAX_STRENGTHEN_LEVEL then
        result = const.error_equipment_strengthen_max_level
        self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result,equip_type = input.equip_type})
        return result
    end

    local success = 0
    local drop_level = 0
    if current_level >= MAX_STRENGTHEN_LEVEL then
        local need_items = {}
        if equipment_strengthen_scheme.Cost[current_stage] == nil then
            return result
        end
        if #equipment_strengthen_scheme.Cost[current_stage].cost1 == 2 then
            table.insert(need_items,{item_id=equipment_strengthen_scheme.Cost[current_stage].cost1[1],item_count=equipment_strengthen_scheme.Cost[current_stage].cost1[2]})
        end
        if #equipment_strengthen_scheme.Cost[current_stage].cost2 == 2 then
            table.insert(need_items,{item_id=equipment_strengthen_scheme.Cost[current_stage].cost2[1],item_count=equipment_strengthen_scheme.Cost[current_stage].cost2[2]})
        end
        if #equipment_strengthen_scheme.Cost[current_stage].cost3 == 2 then
            table.insert(need_items,{item_id=equipment_strengthen_scheme.Cost[current_stage].cost3[1],item_count=equipment_strengthen_scheme.Cost[current_stage].cost3[2]})
        end
        --是否有足够资源
        for i,v in pairs(need_items) do
            if not self:is_enough_by_id(v.item_id,v.item_count) then
                result = const.error_item_not_enough
                self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result,success = success, item_id = v.item_id})
                return result
            end
        end

        --消耗资源
        for i,v in pairs(need_items) do
            self:remove_item_by_id(v.item_id,v.item_count)
        end
        success = 1
        current_stage = current_stage + 1
        current_level = 0
    else
        local strenghten_cost_config = equipment_strengthen_config.get_equip_strengthen_cost(current_stage,current_level)
        if strenghten_cost_config == nil then
            return
        end
        local probability = strenghten_cost_config.score

        --强化石
        local strengthen_item = item_scheme[input.strengthen_id]
        if strengthen_item == nil then
            return result
        end

        if strengthen_item.Type ~= const.TYPE_EQUIP_STRENGTHEN then
            return
        end

        local need_count = strenghten_cost_config.number
        if not self:is_enough_by_id(input.strengthen_id,need_count) then
            result = const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result,success = success, item_id = input.strengthen_id})
            return result
        end

        probability = probability + tonumber(strengthen_item.Para2)

        --银币
        if not self:is_enough_by_id(strenghten_cost_config.silver[1],strenghten_cost_config.silver[2]) then
            result = const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result,success = success, item_id = 1001})
            return result
        end

        --祝福石
        if input.bless_id ~= nil then
            local bless_item = item_scheme[input.bless_id]
            if bless_item == nil then
                return
            end

            if bless_item.Type ~= const.TYPE_EQUIP_STRENGTHEN_BLESS then
                return
            end

            if not self:is_enough_by_id(input.bless_id,1) then
                result = const.error_item_not_enough
                self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result,success = success, item_id = input.bless_id})
                return result
            end

            probability = probability + tonumber(bless_item.Para1)
        end

        --消耗
        self:remove_item_by_id(strenghten_cost_config.silver[1],strenghten_cost_config.silver[2])
        self:remove_item_by_id(input.strengthen_id,need_count)
        if input.bless_id ~= nil then
            self:remove_item_by_id(input.bless_id,1)
        end

        local random_result = math.random(0, 100)
        if random_result <=  probability then
            success = 1
            current_level = current_level + 1
        else
            success = 0
            local drop_level_limit = tonumber(strengthen_item.Para1)
            if current_level > drop_level_limit then
                drop_level = get_equip_strengthen_drop(current_level - drop_level_limit)
                current_level = current_level - drop_level
            end
        end
    end
    if self.equipment_strengthen[part_name] == nil then
        self.equipment_strengthen[part_name] = {}
    end
    self.equipment_strengthen[part_name].stage = current_stage
    self.equipment_strengthen[part_name].level = current_level

    self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result,success = success, equip_type = input.equip_type,stage = current_stage,level = current_level,drop_level = drop_level})
    self:recalc()
    self:imp_property_write_to_sync_dict(syn_data)
    self:imp_equipment_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
    flog("salog","strenghten equipment part_name "..part_name..", old stage "..old_stage.." to new stage "..current_stage..",old level "..old_level.." to new level "..current_level,self.actor_id)
    if success == 1 then
        self:update_task_system_operation(const.TASK_SYSTEM_OPERATION.equipment_strengthen)
    end
end

local function on_star_equipment(self,input,syn_data)
    local result = 0
    local equip_type = input.equip_type
    local part_name = equip_type_to_name[equip_type]
    if part_name == nil then
        result = const.error_equip_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result})
        return result
    end

    --没有装备
    if self[part_name] == nil then
        result =const.error_equip_unload
        self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result,equip_type = input.equip_type})
        return result
    end

    local current_star = 0
    local current_exp = 0
    local current_cost = 0
    if self.equipment_star[part_name] ~= nil then
        current_star = self.equipment_star[part_name].star
        current_exp = self.equipment_star[part_name].exp
        current_cost = self.equipment_star[part_name].cost
    end

    --升到最高级了
    if current_star >= MAX_EQUIPMENT_STAR then
        result = const.error_equipment_strengthen_max_level
        self:send_message(const.SC_MESSAGE_LUA_STAR_EQUIPMENT , {result = result,equip_type = input.equip_type})
        return result
    end

    local star_config = equipment_star_scheme.Bless[current_star+1]
    if star_config == nil then
        return
    end

    local bless_item_config = item_scheme[input.bless_id]
    if bless_item_config == nil then
        return
    end

    --道具不足
    if not self:is_enough_by_id(input.bless_id,1) then
        result = const.error_item_not_enough
        self:send_message(const.SC_MESSAGE_LUA_STAR_EQUIPMENT , {result = result,item_id = input.bless_id})
        return result
    end

    --消耗
    self:remove_item_by_id(input.bless_id,1)

    local success = 0
    local addon_exp = 0
    local crit = 0
    local upgrade = 0
    if current_cost >= star_config.costMin then
        local random_star = math.random(100)
        --直接升星
        if random_star <= star_config.probability then
            success = 1
            addon_exp = tonumber(bless_item_config.Para1)
            if addon_exp > star_config.exp - current_exp then
                current_exp = addon_exp - (star_config.exp - current_exp)
            else
                current_exp = 0
                addon_exp = star_config.exp - current_exp
            end
            upgrade = 1
        end
    end
    if success == 0 then
        local exp_random = math.random(100)
        --经验暴击
        if exp_random <= star_config.pro2 then
            addon_exp = tonumber(bless_item_config.Para1)*10
            crit = 10
        elseif exp_random <= star_config.pro2 + star_config.pro1 then
            addon_exp = tonumber(bless_item_config.Para1)*2
            crit = 2
        else
            addon_exp = tonumber(bless_item_config.Para1)
            crit = 1
        end
        addon_exp = math.floor(addon_exp)
        current_exp = current_exp + addon_exp
        current_cost = current_cost + bless_item_config.Price
        if current_exp >= star_config.exp then
            success = 1
            current_exp = current_exp - star_config.exp
        end
    end

    if success == 1 then
        current_star = current_star + 1
        current_cost = 0
    end

    if self.equipment_star[part_name] == nil then
        self.equipment_star[part_name] = {}
    end
    self.equipment_star[part_name].star = current_star
    self.equipment_star[part_name].exp = current_exp
    self.equipment_star[part_name].cost = current_cost

    self:send_message(const.SC_MESSAGE_LUA_STAR_EQUIPMENT , {result = result,success = success, equip_type = input.equip_type,star = current_star,addon_exp = addon_exp,current_exp = current_exp,crit = crit,upgrade=upgrade})
    self:recalc()
    self:imp_property_write_to_sync_dict(syn_data)
    self:imp_equipment_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
    flog("salog","equipment upgrade star,part_name "..part_name,self.actor_id)
end

--input
--input.equip_type 装备类型
--input.item_pos 被消耗的物品位置
--input.refine_attribute1 被替换的属性
--input.refine_attribute2 用来替换的属性
local function on_refine_equipment(self,input,syn_data)
    local result = 0
    local equip_type = 0
    local equip_item_template = nil
    local equip_item_config = nil
    local equip_data = nil
    local part_name = ""
    if input.equip_type ~= nil then
        equip_type = input.equip_type
        part_name = equip_type_to_name[equip_type]
        if part_name == nil then
            result = const.error_equip_type_wrong
            self:send_message(const.SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT , {result = result})
            return result
        end
        equip_data = self[part_name]
        if equip_data == nil then
            return
        end
        equip_item_config = item_scheme[equip_data:get_id()]
        if equip_item_config == nil then
            return
        end
        equip_item_template = equipment_template[equip_data:get_id()]
        if equip_item_template == nil then
            return
        end
    elseif input.equip_pos ~= nil then
        equip_data = self:get_item_by_pos(input.equip_pos)
        if equip_data == nil then
            flog("tmlDebug","on_refine_equipment not have this main equipment")
            return
        end
        equip_item_config = item_scheme[equip_data:get_id()]
        if equip_item_config == nil then
            return
        end
        equip_type = equip_item_config.Type
        equip_item_template = equipment_template[equip_data:get_id()]
        if equip_item_template == nil then
            flog("tmlDebug","on_refine_equipment not have this main equipment templete")
            return
        end
        part_name = equip_type_to_name[equip_type]
    else
        return
    end

    --检查被吞噬的装备
    local bag_item = self:get_item_by_pos(input.item_pos)
    if bag_item == nil then
        result = const.error_no_item_in_pos
        self:send_message(const.SC_MESSAGE_LUA_REFINE_EQUIPMENT , {result = result})
        return result
    end

    local bag_item_config = item_scheme[bag_item:get_id()]
    if bag_item_config == nil then
        flog("tmlDebug","on_refine_equipment not have this sencod equipment")
        return
    end

    --背包装备模板
    local bag_item_template = equipment_template[bag_item:get_id()]
    if bag_item_template == nil then
        flog("tmlDebug","on_refine_equipment not have this second equipment templete")
        return
    end

    --检查消耗
    if equip_refine_cost[part_name] == nil then
        flog("tmlDebug","on_refine_equipment not have cost config")
        return
    end

    local refine_level = 0
    for i,v in pairs(equip_refine_cost[part_name]) do
        if i <= equip_item_config.LevelLimit and refine_level < i then
            refine_level = i
        end
    end
    if refine_level == 0 then
        flog("tmlDebug","on_refine_equipment refine_level == 0")
        return
    end

    local cost_items = {}
    if #equip_refine_cost[part_name][refine_level].cost1 == 2 then
        table.insert(cost_items,{id=equip_refine_cost[part_name][refine_level].cost1[1],count=equip_refine_cost[part_name][refine_level].cost1[2]})
    end
    if #equip_refine_cost[part_name][refine_level].cost2 == 2 then
        table.insert(cost_items,{id=equip_refine_cost[part_name][refine_level].cost2[1],count=equip_refine_cost[part_name][refine_level].cost2[2]})
    end
    if #equip_refine_cost[part_name][refine_level].cost3 == 2 then
        table.insert(cost_items,{id=equip_refine_cost[part_name][refine_level].cost3[1],count=equip_refine_cost[part_name][refine_level].cost3[2]})
    end

    for i,v in pairs(cost_items) do
        if not self:is_enough_by_id(v.id,v.count) then
            result = const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_REFINE_EQUIPMENT , {result = result,item_id = v.id})
            return result
        end
    end

    --检查类型匹配
    if bag_item_config.Type ~= equip_type then
        result = const.error_equip_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_REFINE_EQUIPMENT , {result = result})
        return result
    end

    --检查属性匹配
    local item_additional = bag_item:get_additional_prop()
    if item_additional == nil or input.refine_attribute1 == nil or input.refine_attribute2 == nil or  item_additional[input.refine_attribute2] == nil then
        result = const.error_equip_refine_atribute_not_match
        self:send_message(const.SC_MESSAGE_LUA_REFINE_EQUIPMENT , {result = result})
        return
    end
    local equip_additional = equip_data:get_additional_prop()
    if equip_additional ~= nil then
        if input.refine_attribute1 > equip_item_template.ClearAttriMax then
            result = const.error_equip_refine_atribute_max
            self:send_message(const.SC_MESSAGE_LUA_REFINE_EQUIPMENT , {result = result})
            return
        end

        --属性配置没有
        local item_refine_config = equipment_attribute_table[item_additional[input.refine_attribute2][5]]
        if item_refine_config == nil then
            flog("tmlDebug","on_refine_equipment not have this second equipment attribute config is nil!")
            return
        end
        --属性类别不匹配
        for i,v in pairs(equip_additional) do
            local equip_refine_config = equipment_attribute_table[v[5]]
            --还有其他属性与洗练属性同一类别
            if equip_refine_config ~= nil and item_refine_config.TypeID == equip_refine_config.TypeID and input.refine_attribute1 ~= i then
                result = const.error_equip_refine_atribute_not_match
                self:send_message(const.SC_MESSAGE_LUA_REFINE_EQUIPMENT , {result = result})
                return
            end
        end
    else
        --这件装备最大洗练属性条目为零
        if equip_item_template.ClearAttriMax < input.refine_attribute1 then
            result = const.error_equip_refine_atribute_max
            self:send_message(const.SC_MESSAGE_LUA_REFINE_EQUIPMENT , {result = result})
            return
        end
    end

    --消耗资源
    for i,v in pairs(cost_items) do
        self:remove_item_by_id(v.id,v.count)
    end
    --移除装备
    self:remove_item_by_pos(input.item_pos,1)
    --替换属性
    equip_data:refine_equip(input.refine_attribute1,item_additional[input.refine_attribute2])

    self:send_message(const.SC_MESSAGE_LUA_REFINE_EQUIPMENT , {result = result})
    self:recalc()
    self:imp_property_write_to_sync_dict(syn_data)
    self:imp_equipment_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
    flog("salog","equipment refine,part_name "..part_name,self.actor_id)
end

local function on_gem_open_slot(self,input,syn_data)
    if input.equip_type == nil or input.slot == nil then
        return
    end
    local result = 0
    local equip_type = input.equip_type
    local part_name = equip_type_to_name[equip_type]
    if part_name == nil then
        result = const.error_equip_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_OPEN_SLOT , {result = result})
        return result
    end

    --没有装备
    if self[part_name] == nil then
        result =const.error_equip_unload
        self:send_message(const.SC_MESSAGE_LUA_GEM_OPEN_SLOT , {result = result,equip_type = input.equip_type})
        return result
    end
    --此孔已开
    if self.equipment_gem[part_name].slots[input.slot] == gem_slot_state.unlock then
        result =const.error_equip_gem_slot_opened
        self:send_message(const.SC_MESSAGE_LUA_GEM_OPEN_SLOT , {result = result,equip_type = input.equip_type,slot = input.slot})
        return result
    end
    --计算消耗
    local current_count = 0
    for i = 1,MAX_GEM_SLOT,1 do
        if self.equipment_gem[part_name].slots[i] >= gem_slot_state.unlock then
            current_count = current_count + 1
        end
    end
    current_count = current_count - MIN_GEM_SLOT
    local cost_cfg = equip_gem_open[current_count + 1]
    if cost_cfg == nil then
        result =const.error_equip_gem_open_slot_max
        self:send_message(const.SC_MESSAGE_LUA_GEM_OPEN_SLOT , {result = result,equip_type = input.equip_type,slot = input.slot})
        return result
    end
    if cost_cfg.cost1[1] ~= nil and cost_cfg.cost1[1] > 0 and cost_cfg.cost1[2] ~= nil and cost_cfg.cost1[2] > 0 then
        if not self:is_enough_by_id(cost_cfg.cost1[1],cost_cfg.cost1[2]) then
            result = const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_GEM_OPEN_SLOT , {result = result,item_id = cost_cfg.cost1[1]})
            return result
        end
    end

    if cost_cfg.cost2[1] ~= nil and cost_cfg.cost2[1] > 0 and cost_cfg.cost2[2] ~= nil and cost_cfg.cost2[2] > 0 then
        if not self:is_enough_by_id(cost_cfg.cost2[1],cost_cfg.cost2[2]) then
            result = const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_GEM_OPEN_SLOT , {result = result,item_id = cost_cfg.cost2[1]})
            return result
        end
    end

    --开孔
    self.equipment_gem[part_name].slots[input.slot] = gem_slot_state.unlock
    --消耗
    if cost_cfg.cost1[1] ~= nil and cost_cfg.cost1[1] > 0 and cost_cfg.cost1[2] ~= nil and cost_cfg.cost1[2] > 0 then
        self:remove_item_by_id(cost_cfg.cost1[1],cost_cfg.cost1[2])
    end
    if cost_cfg.cost2[1] ~= nil and cost_cfg.cost2[1] > 0 and cost_cfg.cost2[2] ~= nil and cost_cfg.cost2[2] > 0 then
        self:remove_item_by_id(cost_cfg.cost2[1],cost_cfg.cost2[2])
    end
    self:send_message(const.SC_MESSAGE_LUA_GEM_OPEN_SLOT , {result = result})
    self:imp_equipment_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
    flog("salog","equipment gem open slot,part_name "..part_name,self.actor_id)
end

local function on_gem_inlay(self,input,syn_data)
    if input.equip_type == nil or input.item_id == nil or input.slots == nil then
        return
    end
    local result = 0
    local equip_type = input.equip_type
    local part_name = equip_type_to_name[equip_type]
    if part_name == nil then
        result = const.error_equip_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,equip_type = input.equip_type})
        return result
    end

    --没有装备
    if self[part_name] == nil then
        result =const.error_equip_unload
        self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,equip_type = input.equip_type})
        return result
    end

    for _,slot in pairs(input.slots) do
        if slot < 1 or slot > MAX_GEM_SLOT then
            result =const.error_equip_gem_slot_wrong
            self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,equip_type = input.equip_type,gem_slot = slot})
            return result
        elseif self.equipment_gem[part_name].slots[slot] == gem_slot_state.lock then
            --此孔未开
            result =const.error_equip_gem_slot_not_opened
            self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,equip_type = input.equip_type,gem_slot = slot})
            return result
        elseif self.equipment_gem[part_name].slots[slot] > gem_slot_state.unlock then
            --此孔已镶嵌
            result = const.error_equip_gem_slot_inlay
            self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,equip_type = input.equip_type,gem_slot = slot})
            return result
        end
    end
    --物品是否存在
    if not self:is_enough_by_id(input.item_id,1) then
        result = const.error_item_not_enough
        self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id})
        return result
    end

    --物品类型错误
    local item_cfg = item_scheme[input.item_id]
    if item_cfg == nil or item_cfg.Type ~= const.TYPE_GEM then
        result = const.error_item_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id})
        return result
    end

    local item_gem_param = string_split(item_cfg.Para1,"|")
    if #item_gem_param < 2 then
        result = const.error_item_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id})
        return result
    end

    --宝石与装备是否匹配
    local gem_id_cfg = equipment_gem_table.GemType[tonumber(item_gem_param[1])]
    if gem_id_cfg == nil or gem_id_cfg[part_name] ~= 1 then
        result = const.error_equip_gem_inlay_type
        self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,equip_type=input.equip_type})
        return result
    end
    --此类宝石是否已镶嵌
    local inlay_item_cfg = nil
    local inlay_item_gem_param = nil
    for i=1,MAX_GEM_SLOT,1 do
        if self.equipment_gem[part_name].slots[i] > 0 then
            inlay_item_cfg = item_scheme[self.equipment_gem[part_name].slots[i]]
            if inlay_item_cfg ~= nil  then
                inlay_item_gem_param = string_split(inlay_item_cfg.Para1,"|")
                if #inlay_item_gem_param > 0 and inlay_item_gem_param[1] == item_gem_param[1] then
                    result = const.error_equip_gem_same_type_inlay
                    self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,gem_slot=i})
                    return result
                end
            end
        end
    end

    --确认形状
    --1,3|4,6|7,9能不能在一起
    local tmp_slots = {}
    for _,slot in ipairs(input.slots) do
        if slot == 1 then
            if tmp_slots[3] ~= nil and tmp_slots[3] == true then
                result = const.error_equip_gem_shape_not_match
                self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,gem_slots=input.slots})
                return result
            end
            tmp_slots[slot] = true
        end
        if slot == 3 then
            if tmp_slots[1] ~= nil and tmp_slots[1] == true then
                result = const.error_equip_gem_shape_not_match
                self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,gem_slots=input.slots})
                return result
            end
            tmp_slots[slot] = true
        end
        if slot == 4 then
            if tmp_slots[6] ~= nil and tmp_slots[6] == true then
                result = const.error_equip_gem_shape_not_match
                self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,gem_slots=input.slots})
                return result
            end
            tmp_slots[slot] = true
        end
        if slot == 6 then
            if tmp_slots[4] ~= nil and tmp_slots[4] == true then
                result = const.error_equip_gem_shape_not_match
                self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,gem_slots=input.slots})
                return result
            end
            tmp_slots[slot] = true
        end
        if slot == 7 then
            if tmp_slots[9] ~= nil and tmp_slots[9] == true then
                result = const.error_equip_gem_shape_not_match
                self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,gem_slots=input.slots})
                return result
            end
            tmp_slots[slot] = true
        end
        if slot == 9 then
            if tmp_slots[7] ~= nil and tmp_slots[7] == true then
                result = const.error_equip_gem_shape_not_match
                self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,gem_slots=input.slots})
                return result
            end
            tmp_slots[slot] = true
        end
    end
    local gem_shape_cfg = gem_shape_configs[tonumber(item_cfg.Para2)]
    if gem_shape_cfg == nil then
        result = const.error_item_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id})
        return result
    end
    local tmp_slots = {}
    local min_slot = MAX_GEM_SLOT
    for _,slot in pairs(input.slots) do
        if slot < min_slot then
            min_slot = slot
        end
    end
    for _,slot in pairs(input.slots) do
        table.insert(tmp_slots,slot - min_slot + 1)
    end

    local different = false
    local same = false
    for _,slot in pairs(gem_shape_cfg.ShapeNum) do
        same = false
        for _,slot1 in pairs(tmp_slots) do
            if slot == slot1 then
                same = true
                break
            end
        end
        if same == false then
            different = true
        end
    end
    if not different then
        for _,slot in pairs(tmp_slots) do
            same = false
            for _,slot1 in pairs(gem_shape_cfg.ShapeNum) do
                if slot == slot1 then
                    same = true
                    break
                end
            end
            if same == false then
                different = true
            end
        end
    end

    if different then
        result = const.error_equip_gem_shape_not_match
        self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,gem_slots=input.slots})
        return result
    end

    --镶嵌
    for _,slot in pairs(input.slots) do
        self.equipment_gem[part_name].slots[slot] = input.item_id
    end
    --移除物品
    self:remove_item_by_id(input.item_id,1)
    self:send_message(const.SC_MESSAGE_LUA_GEM_INLAY , {result = result,item_id = input.item_id,gem_slots=input.slots})
    self:recalc()
    self:imp_property_write_to_sync_dict(syn_data)
    self:imp_equipment_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
    flog("salog","equipment gem inlay,part_name "..part_name,self.actor_id)
end

local function on_gem_remove(self,input,syn_data)
    if input.equip_type == nil or input.slots == nil then
        return
    end
    local result = 0
    local equip_type = input.equip_type
    local part_name = equip_type_to_name[equip_type]
    if part_name == nil then
        result = const.error_equip_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_REMOVE , {result = result,equip_type = input.equip_type})
        return result
    end

    --没有装备
    if self[part_name] == nil then
        result =const.error_equip_unload
        self:send_message(const.SC_MESSAGE_LUA_GEM_REMOVE , {result = result,equip_type = input.equip_type})
        return result
    end

    local item_id = 0
    for _,slot in pairs(input.slots) do
        if slot < 1 or slot > MAX_GEM_SLOT then
            result =const.error_equip_gem_slot_wrong
            self:send_message(const.SC_MESSAGE_LUA_GEM_REMOVE , {result = result,equip_type = input.equip_type,gem_slot = slot})
            return result
        elseif self.equipment_gem[part_name].slots[slot] == gem_slot_state.lock then
            --此孔未开
            result =const.error_equip_gem_slot_not_opened
            self:send_message(const.SC_MESSAGE_LUA_GEM_REMOVE , {result = result,equip_type = input.equip_type,gem_slot = slot})
            return result
        elseif self.equipment_gem[part_name].slots[slot] == gem_slot_state.unlock then
            --此孔没有宝石
            result = const.error_equip_gem_slot_remove
            self:send_message(const.SC_MESSAGE_LUA_GEM_REMOVE , {result = result,equip_type = input.equip_type,gem_slot = slot})
            return result
        elseif self.equipment_gem[part_name].slots[slot] > 0 then
            if item_id == 0 then
                item_id = self.equipment_gem[part_name].slots[slot]
            elseif self.equipment_gem[part_name].slots[slot] ~= item_id then
                result = const.error_equip_gem_remove_different
                self:send_message(const.SC_MESSAGE_LUA_GEM_REMOVE , {result = result,equip_type = input.equip_type,gem_slot = slot})
                return result
            end
        end
    end

    if self:get_first_empty() == nil then
        result =const.error_no_empty_cell
        self:send_message(const.SC_MESSAGE_LUA_GEM_REMOVE , {result = result,equip_type = input.equip_type})
        return result
    end

    for _,slot in pairs(input.slots) do
        self.equipment_gem[part_name].slots[slot] = gem_slot_state.unlock
    end
    self:add_item_by_id(item_id,1)
    self:send_message(const.SC_MESSAGE_LUA_GEM_REMOVE , {result = result,equip_type = input.equip_type,gem_slots=input.slots})
    self:recalc()
    self:imp_property_write_to_sync_dict(syn_data)
    self:imp_equipment_write_to_sync_dict(syn_data)
    self:imp_assets_write_to_sync_dict(syn_data)
    flog("salog","equipment gem remove,part_name "..part_name,self.actor_id)
end

local function on_gem_carve(self,input,syn_data)
    local result = 0
    if input.gem_pos == nil or input.gem_pos < 1 then
        return
    end

    if self:get_first_empty() == nil then
        result =const.error_no_empty_cell
        self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result})
        return result
    end

    --检查宝石
    local gem_item = self:get_item_by_pos(input.gem_pos)
    if gem_item == nil then
        result =const.error_item_not_enough
        self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result,gem_pos = input.gem_pos})
        return
    end

    local gem_item_cfg = item_scheme[gem_item.id]
    if gem_item_cfg == nil or gem_item_cfg.Type ~= const.TYPE_GEM then
        result =const.error_item_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result,gem_pos = input.gem_pos})
        return
    end

    local gem_item_parms = string_split(gem_item_cfg.Para1,"|")
    if #gem_item_parms < 2 then
        result =const.error_item_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result,gem_pos = input.gem_pos})
        return
    end

    --是否最优
    local gem_shape_type = tonumber(gem_item_cfg.Para2)
    local gem_shape_cfg = gem_shape_configs[gem_shape_type]
    if gem_shape_cfg == nil then
        result =const.error_item_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result,gem_pos = input.gem_pos})
        return
    end

    if gem_shape_cfg.Grid == 1 then
        result =const.error_equip_gem_carve_grid
        self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result,gem_pos = input.gem_pos})
        return
    end

    --等级参数
    local gem_level = tonumber(gem_item_parms[2])
    local gem_level_cfg = gem_level_configs[gem_level]
    if gem_level_cfg == nil then
        result =const.error_item_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result,gem_pos = input.gem_pos})
        return
    end

    --检查变形石
    if gem_level_cfg.cost1[1] ~= nil and gem_level_cfg.cost1[1] > 0 and gem_level_cfg.cost1[2] ~= nil and gem_level_cfg.cost1[2] > 0 then
        if not self:is_enough_by_id(gem_level_cfg.cost1[1],gem_level_cfg.cost1[2]) then
            result = const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_GEM_OPEN_SLOT , {result = result,item_id = gem_level_cfg.cost1[1]})
            return result
        end
    end

    if gem_level_cfg.cost2[1] ~= nil and gem_level_cfg.cost2[1] > 0 and gem_level_cfg.cost2[2] ~= nil and gem_level_cfg.cost2[2] > 0 then
        if not self:is_enough_by_id(gem_level_cfg.cost2[1],gem_level_cfg.cost2[2]) then
            result = const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_GEM_OPEN_SLOT , {result = result,item_id = gem_level_cfg.cost2[1]})
            return result
        end
    end

    --检查磨砂石
    local using_grinding_stone = false
    if input.item_id ~= nil then
        if input.item_id ~= gem_level_cfg.Specialcost[1] then
            result =const.error_item_type_wrong
            self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result,item_id = input.item_id})
            return
        end
        if not self:is_enough_by_id(gem_level_cfg.Specialcost[1],gem_level_cfg.Specialcost[2]) then
            result = const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result,item_id = input.item_id})
            return result
        end
        using_grinding_stone = true
    end

    --产生新宝石
    local new_gem_id = gem_item_cfg.ID
    local new_grid_number = 0
    if using_grinding_stone then
        new_grid_number = carve_gem_grid_number[gem_level][gem_shape_cfg.Grid][get_random_index_with_weight_by_count(carve_gem_grid_weight[gem_level][gem_shape_cfg.Grid],gem_shape_cfg.Grid)]
    else
        new_grid_number = carve_gem_grid_number[gem_level][gem_shape_cfg.Grid][get_random_index_with_weight_by_count(carve_gem_grid_weight[gem_level][gem_shape_cfg.Grid])]
    end

    local new_shape_id = gem_shape_type
    --如果格子数不变，就变形(1个格子，4个格子不需要变形)
    if new_grid_number == gem_shape_cfg.Grid then
        if new_grid_number == 2 then
            for _,v in pairs(gem_shape_grid_number[new_grid_number]) do
                if v ~= gem_shape_type then
                    new_shape_id = v
                    break
                end
            end
        elseif new_grid_number == 3 then
            local index = 1
            local count = math.random(2)
            for _,v in pairs(gem_shape_grid_number[new_grid_number]) do
                if v ~= gem_shape_type then
                    if index == count then
                        new_shape_id = v
                        break
                    else
                        index = index + 1
                    end
                end
            end
        end
    else
        new_shape_id = gem_shape_grid_number[new_grid_number][math.random(#gem_shape_grid_number[new_grid_number])]
    end

    local gid = tonumber(gem_item_parms[1])
    if gid == nil or gem_level == nil then
        return
    end

    if gem_configs[gid] ~= nil and gem_configs[gid][gem_level] ~= nil and gem_configs[gid][gem_level][new_shape_id] ~= nil then
        new_gem_id = gem_configs[gid][gem_level][new_shape_id]
    else
        _warn("can not find gem config,gem_id=%d,gem_level=%d,gem_shape_type=%d",gid,gem_level,gem_shape_type)
    end

    --消耗
    self:remove_item_by_pos(input.gem_pos,1)
    if using_grinding_stone then
        self:remove_item_by_id(gem_level_cfg.Specialcost[1],gem_level_cfg.Specialcost[2])
    end
    if gem_level_cfg.cost1[1] ~= nil and gem_level_cfg.cost1[1] > 0 and gem_level_cfg.cost1[2] ~= nil and gem_level_cfg.cost1[2] > 0 then
        self:remove_item_by_id(gem_level_cfg.cost1[1],gem_level_cfg.cost1[2])
    end
    if gem_level_cfg.cost2[1] ~= nil and gem_level_cfg.cost2[1] > 0 and gem_level_cfg.cost2[2] ~= nil and gem_level_cfg.cost2[2] > 0 then
        self:remove_item_by_id(gem_level_cfg.cost2[1],gem_level_cfg.cost2[2])
    end
    --新增
    self:add_item_by_id(new_gem_id,1)
    local bag_dict = {}
    self:imp_assets_write_to_sync_dict(bag_dict)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE , bag_dict)
    self:send_message(const.SC_MESSAGE_LUA_GEM_CARVE , {result = result,new_gem_id = new_gem_id,gem_pos=input.gem_pos})
    flog("salog","equipment gem carve ",self.actor_id)
end

local function on_gem_identify(self,input,syn_data)
    local result = 0
    if input.item_pos == nil or input.item_pos < 1 then
        return
    end

    if self:get_first_empty() == nil then
        result =const.error_no_empty_cell
        self:send_message(const.SC_MESSAGE_LUA_GEM_IDENTIFY , {result = result})
        return result
    end

    --检查混沌石
    local item = self:get_item_by_pos(input.item_pos)
    if item == nil then
        result =const.error_item_slot_not_enough
        self:send_message(const.SC_MESSAGE_LUA_GEM_IDENTIFY , {result = result,item_pos = input.item_pos})
        return
    end

    local item_cfg = item_scheme[item.id]
    if item_cfg == nil or item_cfg.Type ~= const.TYPE_CHAOS_STONE then
        result =const.error_item_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_IDENTIFY , {result = result,item_id = item.id})
        return
    end

    --检查消耗鉴定符
    local gem_level_cfg = chaos_stone_level[item.id]
    if gem_level_cfg == nil and #gem_level_cfg.TestCost >= 2 then
        result =const.error_item_type_wrong
        self:send_message(const.SC_MESSAGE_LUA_GEM_IDENTIFY , {result = result,item_id = item.id})
        return
    end

    if not self:is_enough_by_id(gem_level_cfg.TestCost[1],gem_level_cfg.TestCost[2]) then
        result = const.error_item_not_enough
        self:send_message(const.SC_MESSAGE_LUA_GEM_IDENTIFY , {result = result,item_id = gem_level_cfg.TestCost[1]})
        return result
    end

    --产生宝石
    local new_gem_id = 0
    local gem_shape_type = 0
    local grid_number = get_gem_grid_number(gem_level_cfg.Level)
    if gem_shape_grid_number[grid_number] ~= nil then
        gem_shape_type = gem_shape_grid_number[grid_number][math.random(#gem_shape_grid_number[grid_number])]
    end

    local gem_id = get_chaos_stone_identify_result()
    if gem_configs[gem_id] ~= nil and gem_configs[gem_id][gem_level_cfg.Level] ~= nil and gem_configs[gem_id][gem_level_cfg.Level][gem_shape_type] ~= nil then
        new_gem_id = gem_configs[gem_id][gem_level_cfg.Level][gem_shape_type]
    end

    if new_gem_id == 0 then
        result =const.error_data
        self:send_message(const.SC_MESSAGE_LUA_GEM_IDENTIFY , {result = result})
        return
    end
    self:add_item_by_id(new_gem_id,1)
    --移除混沌石与鉴定符
    self:remove_item_by_pos(input.item_pos,1)
    self:remove_item_by_id(gem_level_cfg.TestCost[1],gem_level_cfg.TestCost[2])
    --完成
    self:send_message(const.SC_MESSAGE_LUA_GEM_IDENTIFY , {result = result,new_gem_id=new_gem_id})
    self:imp_assets_write_to_sync_dict(syn_data)
    flog("salog","equipment gem identify ",self.actor_id)
end

local function on_gem_combine(self,input,syn_data)
    local result = 0
    if input.item_pos1 == nil or input.item_pos2 == nil or input.item_pos3 == nil then
        log("tmlDebug","on_gem_combine data error!")
        return
    end
    if self:get_first_empty() == nil then
        result =const.error_no_empty_cell
        self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result})
        return result
    end
    local item_cnt1 = 1
    local item_cnt2 = 0
    local item_cnt3 = 0
    if input.item_pos2 == input.item_pos1 then
        item_cnt1 = item_cnt1 + 1
    else
        item_cnt2 = 1
    end
    if input.item_pos3 == input.item_pos1 then
        item_cnt1 = item_cnt1 + 1
    elseif input.item_pos3 == input.item_pos2 then
        item_cnt2 = item_cnt2 + 1
    else
        item_cnt3 = 1
    end
    local items = {}
    if item_cnt1 > 0 then
        local item = {}
        item.pos = input.item_pos1
        item.cnt = item_cnt1
        table.insert(items,item)
    end
    if item_cnt2 > 0 then
        local item = {}
        item.pos = input.item_pos2
        item.cnt = item_cnt2
        table.insert(items,item)
    end
    if item_cnt3 > 0 then
        local item = {}
        item.pos = input.item_pos3
        item.cnt = item_cnt3
        table.insert(items,item)
    end
    --检查道具
    local tmp_level = 0
    local gem_items = {}
    local old_gem_ids = {}
    for _,item in pairs(items) do
        local item_data = self:get_item_by_pos(item.pos)
        if item_data == nil then
            result =const.error_item_slot_not_enough
            self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result,item_pos = input.item_pos})
            return
        end

        if not self:is_enough_by_id(item_data.id,item.cnt) then
            result =const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result,item_id = item_data.id})
            return
        end
        local item_cfg = item_scheme[item_data.id]
        if item_cfg == nil then
            flog("info", "can not find item config,id="..item_data.id)
            result =const.error_data
            self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result})
            return
        end

        if item_cfg.Type ~= const.TYPE_GEM then
            result =const.error_item_type_wrong
            self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result,item_id=item_data.id})
            return
        end

        local item_params = string_split(item_cfg.Para1,"|")
        if #item_params < 2 then
            flog("info", string.format("can not decode item config para1=%s,id=%d",item_cfg.Para1,item_data.id))
            result =const.error_data
            self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result})
            return
        end
        local gem_id = tonumber(item_params[1])
        if gem_id == nil or gem_type_configs[gem_id] == nil then
            result =const.error_data
            flog("info", "can not decode item config gem type,id="..item_data.id)
            self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result})
            return
        end
        local gem_level = tonumber(item_params[2])
        if gem_level == nil or gem_level < 1 or gem_level > max_gem_level then
            result =const.error_data
            flog("info", "can not decode item config gem level,id="..item_data.id)
            self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result})
            return
        end

        if tmp_level ~= 0 and tmp_level ~= gem_level then
            result = const.error_equip_gem_combine_level
            self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result})
            return
        end

        tmp_level = gem_level
        item.id = item_data.id
        if gem_items[gem_id] == nil then
            gem_items[gem_id] = {}
            gem_items[gem_id].gem_id = gem_id
            gem_items[gem_id].cnt = item.cnt
            gem_items[gem_id].gem_level = gem_level
            table.insert(old_gem_ids,gem_id)
        else
            gem_items[gem_id].cnt = gem_items[gem_id].cnt + item.cnt
        end
    end

    --产生新宝石
    local new_gem_id = 0
    if #old_gem_ids == 1 then
        --只有一种宝石合成
        flog("tmlDebug","only one gem!!")
        local item = gem_items[old_gem_ids[1]]
        if item.gem_level >= max_gem_level then
            result =const.error_equip_gem_combine_max_level
            self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result,item_id = items[1].id})
            return
        end
        local gem_shape_type = 0
        local grid_number = get_gem_grid_number(item.gem_level+1)
        if gem_shape_grid_number[grid_number] ~= nil then
            gem_shape_type = gem_shape_grid_number[grid_number][math.random(#gem_shape_grid_number[grid_number])]
        end

        local tmp_level = item.gem_level+1
        if gem_configs[item.gem_id] ~= nil and gem_configs[item.gem_id][tmp_level] ~= nil and gem_configs[item.gem_id][tmp_level][gem_shape_type] ~= nil then
            new_gem_id = gem_configs[item.gem_id][tmp_level][gem_shape_type]
        else
            flog("info", string.format("can not find new gem config,gem_id=%d,gem_level=%d,gem_shape_type=%d",item.gem_id,tmp_level,gem_shape_type))
        end
    else
        --多种宝石合成
        flog("tmlDebug","multi kind of gem!!")
        local random_result = math.random(100)
        if random_result <= system_parameter[3].Parameter then
            flog("tmlDebug","chaos gem!!")
            --混沌石
            local level_cfg = gem_level_configs[gem_items[old_gem_ids[1]].gem_level]
            if level_cfg ~= nil then
                new_gem_id = level_cfg.TestItem
            else
                flog("info", string.format("can not find new chaos gem config,level=%d",gem_items[old_gem_ids[1]].gem_level))
            end
        else
            flog("tmlDebug","multi kind of gem!!")
            local normal_cnt = 0
            local special_cnt = 0
            for i,item in pairs(gem_items) do
                local gem_id_cfg = gem_type_configs[i]
                if gem_id_cfg.type == const.GEM_BIG_TYPE.normal then
                    normal_cnt = normal_cnt + item.cnt
                else
                    special_cnt = special_cnt + item.cnt
                end
            end

            random_result = math.random(normal_cnt + special_cnt)
            local new_gem_ids = {}
            if random_result <= normal_cnt then
                flog("tmlDebug","normal gem!!")
                --普通
                for _,gem_id in pairs(gem_type_normal) do
                    if gem_items[gem_id] == nil then
                        table.insert(new_gem_ids,gem_id)
                    end
                end
            else
                flog("tmlDebug","special gem!!")
                --特殊
                for _,gem_id in pairs(gem_type_special) do
                    if gem_items[gem_id] == nil then
                        table.insert(new_gem_ids,gem_id)
                    end
                end
            end
            random_result = math.random(#new_gem_ids)
            local gem_id = new_gem_ids[random_result]
            local gem_shape_type = 0
            flog("tmlDebug","special gem!!")
            local gem_item = gem_items[old_gem_ids[1]]
            local grid_number = get_gem_grid_number(gem_item.gem_level+1)
            if gem_shape_grid_number[grid_number] ~= nil then
                gem_shape_type = gem_shape_grid_number[grid_number][math.random(#gem_shape_grid_number[grid_number])]
            end

            if gem_configs[gem_id] ~= nil and gem_configs[gem_id][gem_item.gem_level] ~= nil and gem_configs[gem_id][gem_item.gem_level][gem_shape_type] ~= nil then
                new_gem_id = gem_configs[gem_id][gem_item.gem_level][gem_shape_type]
            else
                flog("info", string.format("can not find new gem config,gem_id=%d,gem_level=%d,gem_shape_type=%d",gem_id,gem_item.gem_level,gem_shape_type))
            end
        end
    end

    if new_gem_id == 0 then
        result =const.error_data
        flog("info", "can not find new gem")
        self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result})
        return
    end
    --移除旧宝石
    for _,item in pairs(items) do
        self:remove_item_by_id(item.id,item.cnt)
    end
    self:add_item_by_id(new_gem_id,1)
    self:send_message(const.SC_MESSAGE_LUA_GEM_COMBINE , {result = result,new_gem_id=new_gem_id})
    self:imp_assets_write_to_sync_dict(syn_data)
    flog("salog","equipment gem combine ",self.actor_id)
end

function imp_equipment.__ctor(self)
    self.equipment_strengthen = {}
    self.equipment_star = {}
    self.equipment_gem = {}
end


function imp_equipment.imp_equipment_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    local equip_info = table.get(dict, "equipments", {})
    for i, v in pairs(equip_name_to_type) do
        if equip_info[i] ~= nil then
            local new_item = create_item()
            new_item:init_from_dict(equip_info[i])
            self[i] = new_item
        end
    end

    local equip_strengthen_info = table.get(dict,"equipment_strengthen",{})
    for i,v in pairs(equip_name_to_type) do
        if equip_strengthen_info[i] ~= nil then
            self.equipment_strengthen[i] = {}
            self.equipment_strengthen[i].stage = equip_strengthen_info[i].stage
            self.equipment_strengthen[i].level = equip_strengthen_info[i].level
        end
    end

    local equip_star_info = table.get(dict,"equipment_star",{})
    for i,v in pairs(equip_name_to_type) do
        if equip_star_info[i] ~= nil then
            self.equipment_star[i] = {}
            self.equipment_star[i].star = equip_star_info[i].star
            self.equipment_star[i].exp = equip_star_info[i].exp
            self.equipment_star[i].cost = equip_star_info[i].cost
        end
    end

    local equip_jewel_info = table.get(dict,"equipment_gem",{})
    for i,v in pairs(equip_name_to_type) do
        self.equipment_gem[i] = {}
        if equip_jewel_info[i] ~= nil and equip_jewel_info[i].slots ~= nil then
            self.equipment_gem[i].slots = equip_jewel_info[i].slots
        else
            self.equipment_gem[i].slots = {}
            for index=1,MAX_GEM_SLOT,1 do
                if index == 5 or index == 6 or index == 8  or index == 9 then
                    table.insert(self.equipment_gem[i].slots,index,gem_slot_state.unlock)
                else
                    table.insert(self.equipment_gem[i].slots,index,gem_slot_state.lock)
                end
            end
        end
    end
end

function imp_equipment.imp_equipment_init_from_other_game_dict(self,dict)
    self:imp_equipment_init_from_dict(self,dict)
end

function imp_equipment.imp_equipment_write_to_dict(self, dict, to_other_game)
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

    dict.equipments = {}
    for i, v in pairs(equip_name_to_type) do
        --flog("error", "imp_equipment_write_to_dict: v "..v)
        if self[i] ~= nil then
            dict.equipments[i] = {}
            self[i]:write_to_dict(dict.equipments[i])
        end
    end
    dict.equipment_strengthen = {}
    for i,v in pairs(equip_name_to_type) do
        if self.equipment_strengthen[i] ~= nil then
            dict.equipment_strengthen[i] = {}
            dict.equipment_strengthen[i].stage = self.equipment_strengthen[i].stage
            dict.equipment_strengthen[i].level = self.equipment_strengthen[i].level
        end
    end
    dict.equipment_star = {}
    for i,v in pairs(equip_name_to_type) do
        if self.equipment_star[i] ~=nil then
            dict.equipment_star[i] = {}
            dict.equipment_star[i].star = self.equipment_star[i].star
            dict.equipment_star[i].exp = self.equipment_star[i].exp
            dict.equipment_star[i].cost = self.equipment_star[i].cost
        end
    end
    dict.equipment_gem = {}
    for i,v in pairs(equip_name_to_type) do
        if self.equipment_gem[i] ~= nil then
            dict.equipment_gem[i] = {}
            dict.equipment_gem[i].slots = self.equipment_gem[i].slots
        end
    end
end

function imp_equipment.imp_equipment_write_to_other_game_dict(self,dict)
    self:imp_equipment_write_to_dict(dict, true)
end

function imp_equipment.imp_equipment_write_to_sync_dict(self, dict)
    return imp_equipment.imp_equipment_write_to_dict(self, dict)
end

function imp_equipment.get_equipment_attrib(self)
    local property_addtion = {}
    for ename, _ in pairs(equip_name_to_type) do
        if self[ename] ~= nil then
            local single_addition = {}
            local percent_addition = {}
            local strengthen_additional = {} --强化加成

            --计算基础属性加成
            local base_prop = self[ename]:get_base_prop()
            if base_prop ~= nil then
                for j, p in pairs(base_prop) do
                    --基础属性
                    if single_addition[j] ~= nil then
                        single_addition[j] = single_addition[j] + p
                    else
                        single_addition[j] = p
                    end
                    --基础属性强化
                    if self.equipment_strengthen[ename] ~= nil then
                        local fixed = 0
                        local percent = 0
                        for i = 1,self.equipment_strengthen[ename].stage,1 do
                            local addition_cfg = equipment_strengthen_config.get_strengthen_addition(ename,i,j)
                            if addition_cfg ~= nil then
                                if i == self.equipment_strengthen[ename].stage then
                                    fixed = fixed + addition_cfg.fixed*self.equipment_strengthen[ename].level
                                    percent = percent + addition_cfg.percent*self.equipment_strengthen[ename].level
                                else
                                    fixed = fixed + addition_cfg.fixed*MAX_STRENGTHEN_LEVEL
                                    percent = percent + addition_cfg.percent*MAX_STRENGTHEN_LEVEL
                                end
                            end
                        end
                        strengthen_additional[j] = math.floor(p*percent/100) + fixed
                    end
                end
            end

            --计算洗练属性加成
            local additional_prop = self[ename]:get_additional_prop()
            if additional_prop ~= nil then
                --洗练属性结构(1 属性索引，2 属性值，3是否稀有，4属性值类型)
                for j, p in pairs(additional_prop) do
                    if p[4] == 2 then       --value_type为2的是正常属性加成
                        if single_addition[p[1]] ~= nil then
                            single_addition[p[1]] = single_addition[p[1]] + p[2]
                        else
                            single_addition[p[1]] = p[2]
                        end
                    elseif p[4] ==1 then        --value_type为1的是百分比属性加成
                        if percent_addition[p[1]] ~= nil then
                            percent_addition[p[1]] = percent_addition[p[1]] + p[2]
                        else
                            percent_addition[p[1]] = p[2]
                        end
                    end
                end
            end

            --计算宝石属性
            local jewels = {}
            for jewel_slot = 1,MAX_GEM_SLOT,1 do
                if self.equipment_gem[ename].slots[jewel_slot] > 0 and jewels[self.equipment_gem[ename].slots[jewel_slot]] == nil then
                    jewels[self.equipment_gem[ename].slots[jewel_slot]] = 1
                end
            end
            for jewel,_ in pairs(jewels) do
                local item_gem_config = item_gem_configs[jewel]
                if item_gem_config ~= nil then
                    if item_gem_config.attribute_value_type == equipment_attribute_value_type.normal then       --value_type为2的是正常属性加成
                        if single_addition[item_gem_config.attribute_index] ~= nil then
                            single_addition[item_gem_config.attribute_index] = single_addition[item_gem_config.attribute_index] + item_gem_config.attribute_value
                        else
                            single_addition[item_gem_config.attribute_index] = item_gem_config.attribute_value
                        end
                    elseif item_gem_config.attribute_value_type == equipment_attribute_value_type.percent then        --value_type为1的是百分比属性加成
                        if percent_addition[item_gem_config.attribute_index] ~= nil then
                            percent_addition[item_gem_config.attribute_index] = percent_addition[item_gem_config.attribute_index] + item_gem_config.attribute_value
                        else
                            percent_addition[item_gem_config.attribute_index] = item_gem_config.attribute_value
                        end
                    end
                end
            end

            --洗练属性中万分比加成
            for j, p in pairs(percent_addition) do
                local s_value = single_addition[j]
                if s_value ~= nil then
                    single_addition[j] = s_value + math.floor(s_value * p / 10000)
                end
            end

            for j,p in pairs(strengthen_additional) do
                if single_addition[j] == nil then
                    single_addition[j] = p
                else
                    single_addition[j] = single_addition[j] + p
                end
            end

            --装备升星属性
            if self.equipment_star[ename] ~= nil then
                local equipment_start_config = equipment_star_scheme.Bless[self.equipment_star[ename].star]
                if equipment_start_config ~= nil then
                    if single_addition[property_name_to_index.spritual] == nil then
                        single_addition[property_name_to_index.spritual] = 0
                    end
                    single_addition[property_name_to_index.spritual] = single_addition[property_name_to_index.spritual] + equipment_start_config.spiritual
                end
            end

            --单装备属性加成加入总表
            for j,p in pairs(single_addition) do
                local name = PROPERTY_INDEX_TO_NAME[j]
                --_info("j "..j)
                --_info("name  "..name)
                if property_addtion[name] ~= nil then
                    property_addtion[name] = property_addtion[name] + p
                else
                    property_addtion[name] = p
                end
            end
        end
    end
    return property_addtion
end

function imp_equipment.write_equipment_info_to_other(self,dict)
    dict.equipments = {}
    for i, v in pairs(equip_name_to_type) do
        if self[i] ~= nil then
            dict.equipments[i] = {}
            self[i]:write_to_dict(dict.equipments[i])
        end
    end
end

function imp_equipment.get_equipment_strengthen_level(self)
    local strengthen_level = 0
    for i, v in pairs(equip_name_to_type) do
        if self.equipment_strengthen[i] ~= nil then
            strengthen_level = strengthen_level +(self.equipment_strengthen[i].stage - 1)*9 + self.equipment_strengthen[i].level
        end
    end
    return strengthen_level
end

register_message_handler(const.CS_MESSAGE_LUA_LOAD_EQUIPMENT, on_load_equipment)
register_message_handler(const.CS_MESSAGE_LUA_UNLOAD_EQUIPMENT, on_unload_equipment)
register_message_handler(const.CS_MESSAGE_LUA_STRENGTHEN_EQUIPMENT,on_strengthen_equipment)
register_message_handler(const.CS_MESSAGE_LUA_STAR_EQUIPMENT,on_star_equipment)
register_message_handler(const.CS_MESSAGE_LUA_REFINE_EQUIPMENT,on_refine_equipment)
register_message_handler(const.CS_MESSAGE_LUA_GEM_OPEN_SLOT,on_gem_open_slot)
register_message_handler(const.CS_MESSAGE_LUA_GEM_INLAY,on_gem_inlay)
register_message_handler(const.CS_MESSAGE_LUA_GEM_REMOVE,on_gem_remove)
register_message_handler(const.CS_MESSAGE_LUA_GEM_CARVE,on_gem_carve)
register_message_handler(const.CS_MESSAGE_LUA_GEM_IDENTIFY,on_gem_identify)
register_message_handler(const.CS_MESSAGE_LUA_GEM_COMBINE,on_gem_combine)

imp_equipment.__message_handler = {}
imp_equipment.__message_handler.on_load_equipment = on_load_equipment
imp_equipment.__message_handler.on_unload_equipment = on_unload_equipment
imp_equipment.__message_handler.on_strengthen_equipment = on_strengthen_equipment
imp_equipment.__message_handler.on_star_equipment = on_star_equipment
imp_equipment.__message_handler.on_refine_equipment = on_refine_equipment
imp_equipment.__message_handler.on_gem_open_slot = on_gem_open_slot
imp_equipment.__message_handler.on_gem_inlay = on_gem_inlay
imp_equipment.__message_handler.on_gem_remove = on_gem_remove
imp_equipment.__message_handler.on_gem_carve = on_gem_carve
imp_equipment.__message_handler.on_gem_identify = on_gem_identify
imp_equipment.__message_handler.on_gem_combine = on_gem_combine

return imp_equipment