--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/7 0007
-- Time: 18:29
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local string_split = require("basic/scheme").string_split
local common_item_config = require "configs/common_item_config"
local math = require "math"
local const = require "Common/constant"
local flog = require "basic/log"

local auto_package_effect = ExtendClass(item_effect)

function auto_package_effect:__ctor()
    self.item_id = 0
    self.item_count = 0
end

function auto_package_effect:effect(launcher,target,count)
    local item_config = common_item_config.get_item_config(self.item_id)
    local need_slot = math.ceil(self.item_count*count/item_config.OverlayNum)
    if launcher:get_empty_slot_number() < need_slot then
        return const.error_no_empty_cell
    end
    local item_table = {}
    item_table[self.item_id] = self.item_count*count
    launcher:add_new_rewards(item_table)
    launcher:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",items=item_table})
    return 0
end

function auto_package_effect:parse_effect(id,param1,param2)
    local item_strings = string_split(param1,'=')
    if #item_strings ~= 2 or common_item_config.get_item_config(tonumber(item_strings[1])) == nil then
        flog("error","auto_package_effect parse_effect fail,item id:"..id)
        return false
    end
    self.item_id = tonumber(item_strings[1])
    self.item_count = tonumber(item_strings[2])
    return true
end

return auto_package_effect
