--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/8 0008
-- Time: 16:21
-- To change this template use File | Settings | File Templates.
--
require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local const = require "Common/constant"

local clear_pk_value_effect = ExtendClass(item_effect)

function clear_pk_value_effect:__ctor()
    self.reduce_pk_value = {}
end

function clear_pk_value_effect:effect(launcher,target,count)
    if launcher:get_pk_value() <= 0 then
        return const.error_pk_value_is_zero
    end

    local reduce_pk_value = launcher:reduce_pk_value(self.reduce_pk_value)
    launcher:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",reduce_pk_value=reduce_pk_value})
    return 0
end

function clear_pk_value_effect:parse_effect(id,param1,param2)
    self.reduce_pk_value = tonumber(param1)
    return true
end

return clear_pk_value_effect
