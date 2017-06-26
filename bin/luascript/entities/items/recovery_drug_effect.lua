--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/24 0024
-- Time: 16:29
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local math = require "math"
local const = require "Common/constant"
local flog = require "basic/log"

local recovery_drug_effect = ExtendClass(item_effect)

function recovery_drug_effect:__ctor()
    self.type = 1
    self.recovery_value = 0
end

function recovery_drug_effect:effect(launcher,target,count)
    local res = launcher:use_recovery_drug(self.type,self.recovery_value*count)
    if res ~= 0 then
        flog("tmlDebug","recovery_drug_effect.effect result:"..res)
        --launcher:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=res,func_name="UseBagItemReply"})
    end
    return res
end

function recovery_drug_effect:parse_effect(id,param1,param2)
    self.type = math.floor(tonumber(param1))
    self.recovery_value = math.floor(tonumber(param2))
    return true
end

return recovery_drug_effect



