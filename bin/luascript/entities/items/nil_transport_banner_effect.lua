--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/10 0010
-- Time: 9:53
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local math = require "math"
local const = require "Common/constant"
local flog = require "basic/log"

local nil_transport_banner_effect = ExtendClass(item_effect)

function nil_transport_banner_effect:__ctor()
    self.duration = 0
    self.banner_id = 0
end

function nil_transport_banner_effect:effect(launcher,target,count)
    if launcher:get_empty_slot_number() < 1 then
        return const.error_no_empty_cell
    end
    if launcher:is_in_normal_scene() == true then
        local scene_id = launcher:get_aoi_scene_id()
        local x,y,z = launcher:get_pos()
        x = math.floor(x*100)
        y = math.floor(y*100)
        z = math.floor(z*100)
        launcher:add_new_transport_banner(self.banner_id,scene_id,x,y,z)
        launcher:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",locate_position = true,scene_id=scene_id,posX=x,posY=y,posZ=z})
    else
        return const.error_locate_in_dungeon
    end
    return 0
end

function nil_transport_banner_effect:parse_effect(id,param1,param2)
    self.duration = math.floor(tonumber(param1))
    self.banner_id = math.floor(tonumber(param2))
    return true
end

return nil_transport_banner_effect
