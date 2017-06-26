--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/7 0007
-- Time: 10:44
-- To change this template use File | Settings | File Templates.
--

local common_item_config = require "configs/common_item_config"
local const = require "Common/constant"
local fix_package_effect = require "entities/items/fix_package_effect"
local rand_package_effect = require "entities/items/rand_package_effect"
local auto_package_effect = require "entities/items/auto_package_effect"
local add_buff_effect = require "entities/items/add_buff_effect"
local seal_energy_effect = require "entities/items/seal_energy_effect"
local pet_egg_effect = require "entities/items/pet_egg_effect"
local clear_pk_value_effect = require "entities/items/clear_pk_value_effect"
local change_model_scale_effect = require "entities/items/change_model_scale_effect"
local disguise_model_effect = require "entities/items/disguise_model_effect"
local random_transport_character_effect = require "entities/items/random_transport_character_effect"
local nil_transport_banner_effect = require "entities/items/nil_transport_banner_effect"
local stealthy_character_effect = require "entities/items/stealthy_character_effect"
local recovery_drug_effect = require "entities/items/recovery_drug_effect"
local fashion_effect = require "entities/items/fashion_effect"
local flog = require "basic/log"

local item_effects = {}

local function effect(item_id,launcher,target,count)
    flog("tmlDebug","item_effect_manager.effect")
    local item_config = common_item_config.get_item_config(item_id)
    if item_config == nil then
        return const.error_data
    end

    local effect = item_effects[item_id]
    if effect ~= nil then
        return effect:effect(launcher,target,count)
    end

    return const.error_data
end

local function init()
    local configs = common_item_config.get_item_configs()
    for _,item_config in pairs(configs) do
        local effect = nil
        if item_config.Type == const.TYPE_FIX_PACKAGE then
            effect = fix_package_effect()
        elseif item_config.Type == const.TYPE_RAND_PACKAGE then
            effect = rand_package_effect()
        elseif item_config.Type == const.TYPE_AUTO_PACKAGE then
            effect = auto_package_effect()
        elseif item_config.Type == const.TYPE_ADD_BUFF then
            effect = add_buff_effect()
        elseif item_config.Type == const.TYPE_SEAL_ENERGY then
            effect = seal_energy_effect()
        elseif item_config.Type == const.TYPE_PET_EGG then
            effect = pet_egg_effect()
        elseif item_config.Type == const.TYPE_CLEAR_PK_VALUE then
            effect = clear_pk_value_effect()
        elseif item_config.Type == const.TYPE_SCALE_MODEL then
            effect = change_model_scale_effect()
        elseif item_config.Type == const.TYPE_DISGUISE_MODEL then
            effect = disguise_model_effect()
        elseif item_config.Type == const.TYPE_RANDOM_TRANSPORT_CHARACTER then
            effect = random_transport_character_effect()
        elseif item_config.Type == const.TYPE_NIL_TRANSPORT_BANNER then
            effect = nil_transport_banner_effect()
        elseif item_config.Type == const.TYPE_STEALTHY_CHARACTER then
            effect = stealthy_character_effect()
        elseif item_config.Type == const.TYPE_RECOVERY_DRUG then
            effect = recovery_drug_effect()
        elseif item_config.Type == const.TYPE_HEAD_FASHION or item_config.Type == const.TYPE_CLOTH_FASHION or item_config.Type == const.TYPE_WEAPON_FASHION or item_config.Type == const.TYPE_ORNAMENT_FASHION then
            effect = fashion_effect()
        end
        if effect ~= nil and effect:parse_effect(item_config.ID,item_config.Para1,item_config.Para2) then
            item_effects[item_config.ID] = effect
        end
    end
end

init()

return {
    effect = effect
}

