--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/7 0007
-- Time: 18:50
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"
local growing_skill_config = require "configs/growing_skill_config"
local item_effect = require "entities/items/item_effect"
local flog = require "basic/log"

local add_buff_effect = ExtendClass(item_effect)

function add_buff_effect:__ctor()
    self.buff_id = 0
end

function add_buff_effect:effect(launcher,target,count)
    return launcher:item_add_buff(self.buff_id)
end

function add_buff_effect:parse_effect(id,param1,param2)
    self.buff_id = tonumber(param1)
    local buff_config = growing_skill_config.get_buff_config(self.buff_id)
    if buff_config == nil then
        flog("error","add_buff_effect parse_effect fail,item id:"..id..",buff_id:"..self.buff_id)
        return false
    end
    return true
end

return add_buff_effect
