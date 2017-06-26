--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/7 0007
-- Time: 16:25
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local common_item_config = require "configs/common_item_config"
local math = require "math"
local const = require "Common/constant"
local create_add_up_table = require("basic/scheme").create_add_up_table
local get_random_index_with_weight_by_count = require("basic/scheme").get_random_index_with_weight_by_count
local flog = require "basic/log"
local table_insert = table.insert

local rand_package_effect = ExtendClass(item_effect)

function rand_package_effect:__ctor()
    self.random_item_configs = {}
    self.rand_item_id = 0
end

function rand_package_effect:effect(launcher,target,count)
    local level = launcher.level
    local fit_level_configs = {}
    local fit_level_configs_weight = {}
    for _,config in pairs(self.random_item_configs) do
        if config.LowerLimit <= level and level <= config.UpperLimit then
            local faction_match = false
            if config.Sex == 0 or config.Sex == launcher.sex then
                local faction_count = #config.Faction
                if faction_count == 0 then
                    faction_match = true
                else
                    for i=1,faction_count,1 do
                        if launcher.vocation == config.Faction[i] then
                            faction_match = true
                            break
                        end
                    end
                end
            end

            if faction_match then
                table_insert(fit_level_configs,config)
                table_insert(fit_level_configs_weight,config.Weight)
            end
        end
    end
    fit_level_configs_weight = create_add_up_table(fit_level_configs_weight)

    local need_slot = 0
    local item_table = {}
    local item_config = nil
    for i=1,count,1 do
        local item_index = get_random_index_with_weight_by_count(fit_level_configs_weight)
        item_config = common_item_config.get_item_config(fit_level_configs[item_index].Item[1])
        if item_config ~= nil then
            item_table[item_config.ID] = item_table[item_config.ID] or 0 + fit_level_configs[item_index].Item[2]
        else
            flog("info","rand_package_effect|effect can not find item config,random item id:"..self.rand_item_id..",item id:"..fit_level_configs[item_index].Item[1])
        end
    end
    for item_id,item_count in pairs(item_table) do
        item_config = common_item_config.get_item_config(item_id)
        need_slot = need_slot + math.ceil(item_count/item_config.OverlayNum)
    end
    if launcher:get_empty_slot_number() < need_slot then
        return const.error_no_empty_cell
    end
    launcher:add_new_rewards(item_table)
    launcher:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",items=item_table})
    return 0
end

function rand_package_effect:parse_effect(id,param1,param2)
    self.rand_item_id = tonumber(param1)
    self.random_item_configs = table.copy(common_item_config.get_rand_item_configs(self.rand_item_id))
    return true
end

return rand_package_effect
