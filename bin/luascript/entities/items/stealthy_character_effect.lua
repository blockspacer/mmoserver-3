--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/10 0010
-- Time: 17:37
-- To change this template use File | Settings | File Templates.
--
require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local math = require "math"

local stealthy_character_effect = ExtendClass(item_effect)

function stealthy_character_effect:__ctor()
    self.duration = 60
end

function stealthy_character_effect:effect(launcher,target,count)
    launcher:player_stealthy(self.duration)
    return 0
end

function stealthy_character_effect:parse_effect(id,param1,param2)
    self.duration = math.floor(tonumber(param1))*60
    return true
end

return stealthy_character_effect
