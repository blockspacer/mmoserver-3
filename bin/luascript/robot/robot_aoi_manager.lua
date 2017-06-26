--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/6/19 0019
-- Time: 10:36
-- To change this template use File | Settings | File Templates.
--
require "Common/basic/LuaObject"
local flog = require "basic/log"
local msg_pack = require "basic/message_pack"

local robot_aoi_manager = ExtendClass()

--传入的entity_id为谁拥有的这个aoi_manager
function robot_aoi_manager:__ctor(robot_id)
    self.robot_id = robot_id
end

local aoi_scene_id
local entitys = {}

function robot_aoi_manager:set_my_entity_id(entity_id)
    self.entity_id = entity_id
end

function robot_aoi_manager:on_aoi_add(scene_id,entity_id,data,x,y,z,orientation,speed)
    flog("tmlDebug",string.format("robot_aoi_manager|add_aoi_entity scene_id %d,entity_id %s,(%f,%f,%f),orientation %f,speed %f",scene_id,entity_id,x,y,z,orientation,speed))
    if scene_id ~= aoi_scene_id then
        flog("debug","robot_aoi_manager|add_aoi_entity scene_id "..scene_id..",aoi_scene_id "..aoi_scene_id)
        return
    end
    if entitys[entity_id] ~= nil then
        flog("warn","robot_aoi_manager|add_aoi_entity entity is already exist!entity_id "..entity_id)
    end
    entitys[entity_id] = {data=msg_pack.unpack(data),x=x,y=y,z=z,orientation=orientation,speed=speed }
    if self.entity_id == entity_id then
        local robot_manager = require "robot/robot_manager"
        local robot = robot_manager.get_robot(self.robot_id)
        if robot ~= nil then
            local action = robot:get_action()
            action:set_position(x,y,z)
            action:set_speed(speed)
        end
    end
end

function robot_aoi_manager:on_aoi_del(scene_id,entity_id)
    if scene_id ~= aoi_scene_id then
        flog("debug","robot_aoi_manager|remove_aoi_entity scene_id "..scene_id..",aoi_scene_id "..aoi_scene_id)
        return
    end
    entitys[entity_id] = nil
end

function robot_aoi_manager:set_aoi_scene_id(scene_id)
    aoi_scene_id = scene_id
end

function robot_aoi_manager:clear()
    entitys = {}
end

function robot_aoi_manager:on_aoi_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
end

function robot_aoi_manager:on_aoi_stop_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
end

function robot_aoi_manager:on_aoi_force_position(scene_id,entity_id,x,y,z)
end

function robot_aoi_manager:on_aoi_turn_direction(robot_id,scene_id,entity_id,x,y,z,direction)

end

return robot_aoi_manager

