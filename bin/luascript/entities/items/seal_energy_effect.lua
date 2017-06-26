--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/8 0008
-- Time: 14:28
-- To change this template use File | Settings | File Templates.
--
require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local const = require "Common/constant"

local seal_energy_effect = ExtendClass(item_effect)

function seal_energy_effect:__ctor()
    self.energy = 0
end

function seal_energy_effect:effect(launcher,target,count)
    if launcher:is_seal_energy_full() then
        return const.error_seal_energy_is_full
    end
    launcher:add_capture_energy(self.energy*count)
    launcher:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",seal_energy=self.energy*count})
    return 0
end

function seal_energy_effect:parse_effect(id,param1,param2)
    self.energy = tonumber(param1)
    return true
end

return seal_energy_effect
