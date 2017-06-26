--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/8 0008
-- Time: 18:44
-- To change this template use File | Settings | File Templates.
--
require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local math = require "math"

local change_model_scale_effect = ExtendClass(item_effect)

function change_model_scale_effect:__ctor()
    self.model_scale = 100
    self.duration = 60
end

function change_model_scale_effect:effect(launcher,target,count)
    launcher:change_model_scale(self.model_scale,self.duration)
    return 0
end

function change_model_scale_effect:parse_effect(id,param1,param2)
    self.model_scale = math.floor(tonumber(param1))
    self.duration = tonumber(param2)*60
    return true
end

return change_model_scale_effect
