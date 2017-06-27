--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/14 0014
-- Time: 14:11
-- To change this template use File | Settings | File Templates.
--
local growing_pet = require "data/growing_pet"

local pet_attributes = {}

--初始化产出表
local output_pet_scheme = growing_pet.OutputPet
local base_prop_output_index = {}
local quality_output_index = {}

local function check_output_type(type)
    if base_prop_output_index[type] == nil then
        return false
    end
    if quality_output_index[type] == nil then
        return false
    end
    return true
end

local function get_pet_config(id)
    return pet_attributes[id]
end

local NAME_TO_SCHEME

local function reload()
    pet_attributes = {}
    for _,v in pairs(growing_pet.Attribute) do
        pet_attributes[v.ID] = v
    end

    --初始化产出表
    output_pet_scheme = growing_pet.OutputPet
    base_prop_output_index = {}
    quality_output_index = {}
    for _, v in ipairs(output_pet_scheme) do
        if v.Type == 1 then
            if base_prop_output_index[v.Label] == nil then
                base_prop_output_index[v.Label] = {}
            end
            table.insert(base_prop_output_index[v.Label], v)
        elseif v.Type == 2 then
            if quality_output_index[v.Label] == nil then
                quality_output_index[v.Label] = {}
            end
            table.insert(quality_output_index[v.Label], v)
        end
    end

    NAME_TO_SCHEME = {
        base_physic_attack = "PhysicAttack",      --基础物理攻击
        base_magic_attack = "MagicAttack",       --基础魔法攻击
        base_physic_defence  = "PhysicDefence",  --基础物理防御
        base_magic_defence = "MagicDefence",     --基础魔法防御

        physic_attack_quality = "PhyAttQuality",             --物理攻击资质
        magic_attack_quality = "MagAttQuality",              --魔法攻击资质
        physic_defence_quality = "PhyDefQuality",            --物理防御资质
        magic_defence_quality = "MagDefQuality",             --魔法防御资质
    }

    for _, pet_attrib_this in pairs(pet_attributes) do
        for prop_name, _ in pairs(NAME_TO_SCHEME) do
            local prop_value = pet_attrib_this[NAME_TO_SCHEME[prop_name]]
            if prop_value <= 0 then
                _error(string.format("pet base attrib error %s : %d", prop_name, prop_value))
                assert(false)
            end
        end
    end
end
reload()

return{
    check_output_type = check_output_type,
    get_pet_config = get_pet_config,
    reload = reload,
}

