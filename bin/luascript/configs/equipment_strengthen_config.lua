--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/12 0012
-- Time: 17:37
-- To change this template use File | Settings | File Templates.
--

local equipment_strengthen = require "data/equipment_strengthen"
local scheme = require "basic/scheme"

local strengthen_addition = {}
local max_strengthen_stage = 0
local equip_strengthen_cost = {}
--强化失败等级掉落
local weight_table_equip_strengthen_drop = {}

local function reload()
    strengthen_addition = {}
    strengthen_addition.Weapon = {}
    strengthen_addition.Necklace = {}
    strengthen_addition.Ring = {}
    strengthen_addition.Helmet = {}
    strengthen_addition.Armor = {}
    strengthen_addition.Belt = {}
    strengthen_addition.Legging = {}
    strengthen_addition.Boot = {}
    max_strengthen_stage = 0
    for _,v in pairs(equipment_strengthen.StrengthAddition) do
        if v.stage > max_strengthen_stage then
            max_strengthen_stage = v.stage
        end
        if strengthen_addition.Weapon[v.stage] == nil then
            strengthen_addition.Weapon[v.stage] = {}
        end
        strengthen_addition.Weapon[v.stage][v.AttriID] = {fixed=v.Weapon1,percent=v.Weapon2 }

        if strengthen_addition.Necklace[v.stage] == nil then
            strengthen_addition.Necklace[v.stage] = {}
        end
        strengthen_addition.Necklace[v.stage][v.AttriID] = {fixed=v.Necklace1,percent=v.Necklace2 }

        if strengthen_addition.Ring[v.stage] == nil then
            strengthen_addition.Ring[v.stage] = {}
        end
        strengthen_addition.Ring[v.stage][v.AttriID] = {fixed=v.Ring1,percent=v.Ring2 }

        if strengthen_addition.Helmet[v.stage] == nil then
            strengthen_addition.Helmet[v.stage] = {}
        end
        strengthen_addition.Helmet[v.stage][v.AttriID] = {fixed=v.Helmet1,percent=v.Helmet2 }

        if strengthen_addition.Armor[v.stage] == nil then
            strengthen_addition.Armor[v.stage] = {}
        end
        strengthen_addition.Armor[v.stage][v.AttriID] = {fixed=v.Armor1,percent=v.Armor2 }

        if strengthen_addition.Belt[v.stage] == nil then
            strengthen_addition.Belt[v.stage] = {}
        end
        strengthen_addition.Belt[v.stage][v.AttriID] = {fixed=v.Belt1,percent=v.Belt2 }

        if strengthen_addition.Legging[v.stage] == nil then
            strengthen_addition.Legging[v.stage] = {}
        end
        strengthen_addition.Legging[v.stage][v.AttriID] = {fixed=v.Legging1,percent=v.Legging2 }
        if strengthen_addition.Boot[v.stage] == nil then
            strengthen_addition.Boot[v.stage] = {}
        end
        strengthen_addition.Boot[v.stage][v.AttriID] = {fixed=v.Boot1,percent=v.Boot2}
    end

    --强化消耗
    equip_strengthen_cost = {}
    for i,v in pairs(equipment_strengthen.Strengthstage) do
        if equip_strengthen_cost[v.stage] == nil then
            equip_strengthen_cost[v.stage] = {}
        end
        equip_strengthen_cost[v.stage][v.level] = v
    end
    --强化等级掉落
    weight_table_equip_strengthen_drop = {}
    for i, v in ipairs(equipment_strengthen.DropLevel) do
        table.insert(weight_table_equip_strengthen_drop, v.weight)
    end
    weight_table_equip_strengthen_drop = scheme.create_add_up_table(weight_table_equip_strengthen_drop)
end

reload()

local function get_strengthen_addition(part,stage,attribute)
    return strengthen_addition[part][stage][attribute]
end

local function get_max_strengthen_stage()
    return max_strengthen_stage
end

local function get_equip_strengthen_cost(stage,level)
    return equip_strengthen_cost[stage][level]
end

return {
    reload = reload,
    get_strengthen_addition = get_strengthen_addition,
    get_max_strengthen_stage = get_max_strengthen_stage,
    get_equip_strengthen_cost = get_equip_strengthen_cost,
}

