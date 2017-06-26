--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/9 0009
-- Time: 13:44
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local math = require "math"
local const = require "Common/constant"
local flog = require "basic/log"
local Vector3 = require "UnityEngine.Vector3"

local random_transport_character_effect = ExtendClass(item_effect)

function random_transport_character_effect:__ctor()
    self.distance = 100
    self.duration = 0
end

function random_transport_character_effect:effect(launcher,target,count)
    local res,x,y,z = launcher:on_random_transport(self.distance)
    if res == false then
        return const.error_random_transport_fail
    else
        flog("tmlDebug","random_transport_character_effect.effect x:"..x..",y:"..y..",z:"..z)
        local puppet = launcher:get_entity_manager().GetPuppet(launcher.entity_id)
        if puppet ~= nil then
            puppet:SetPosition(Vector3.New(x,y,z))
        end
        launcher:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",random_transport = true,posX=math.floor(x*100),posY=math.floor(y*100),posZ=math.floor(z*100)})
    end
    return 0
end

function random_transport_character_effect:parse_effect(id,param1,param2)
    self.distance = math.floor(tonumber(param1))
    self.duration = tonumber(param2)
    return true
end

return random_transport_character_effect

