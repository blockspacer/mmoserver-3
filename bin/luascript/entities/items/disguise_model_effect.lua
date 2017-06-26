--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/9 0009
-- Time: 10:57
-- To change this template use File | Settings | File Templates.
--
require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local math = require "math"

local change_model_scale_effect = ExtendClass(item_effect)

function change_model_scale_effect:__ctor()
    self.model_id = 100
    self.duration = 60
end

function change_model_scale_effect:effect(launcher,target,count)
    launcher:on_disguise_model(self.model_id,self.duration)
    return 0
end

function change_model_scale_effect:parse_effect(id,param1,param2)
    self.model_id = math.floor(tonumber(param1))
    self.duration = tonumber(param2)*60
    return true
end

return change_model_scale_effect

