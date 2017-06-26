--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/7 0007
-- Time: 14:10
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local string_split = require("basic/scheme").string_split
local common_item_config = require "configs/common_item_config"
local math = require "math"
local const = require "Common/constant"

local fix_package_effect = ExtendClass(item_effect)

function fix_package_effect:__ctor()
    self.items = {}
end

function fix_package_effect:effect(launcher,target,count)
    local need_slot = 0
    local item_table = {}
    local item_config = nil
    for item_id,item_count in pairs(self.items) do
        item_config = common_item_config.get_item_config(item_id)
        need_slot = need_slot + math.ceil(item_count*count/item_config.OverlayNum)
        item_table[item_id] = item_count*count
    end
    if launcher:get_empty_slot_number() < need_slot then
        return const.error_no_empty_cell
    end
    launcher:add_new_rewards(item_table)
    launcher:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",items=item_table})
    return 0
end

function fix_package_effect:parse_effect(id,param1,param2)
    --多个物品
    local item_strings = string_split(param1,'|')
    local item_value = nil
    for _,item_string in pairs(item_strings) do
        --id=count
        item_value = string_split(item_string,'=')
        if #item_value == 2 then
            self.items[tonumber(item_value[1])] = (self.items[tonumber(item_value[1])] or 0) + tonumber(item_value[2])
        end
    end
    return true
end

return fix_package_effect

