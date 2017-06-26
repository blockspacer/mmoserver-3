--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/6 0006
-- Time: 14:58
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"

local item_effect = ExtendClass()

function item_effect:__ctor()
end

function item_effect:effect(launcher,target,count)
    return 0
end

function item_effect:parse_effect(id,param1,param2)
    return true
end

return item_effect