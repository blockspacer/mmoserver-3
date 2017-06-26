--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/18 0018
-- Time: 14:36
-- To change this template use File | Settings | File Templates.
--

local flog = require "basic/log"
local robot = require "robot/robot"
local robot_net = require "robot/robot_net"
local table = table
local robots = {}
local manager_id = 1
local common_scene_config = require "configs/common_scene_config"

local function on_server_message(robot_id,key_action,data)
    if robots[robot_id] ~= nil then
        data = robot_net.decode_message(data)
        flog("debug",string.format("on_server_message robot_id %d,key_action %d,data %s",robot_id,key_action,table.serialize(data)))
        robots[robot_id]:on_message(key_action,data)
    end
end

local function on_client_runing(robot_id)
    if robots[robot_id] == nil then
        flog("debug","robot is not login,robot id "..robot_id)
        return
    end
    robots[robot_id]:on_client_runing()
end

local function on_client_connected(robot_id)
    flog("info","robot_manager.on_client_connected robot_id "..robot_id)
    if robots[robot_id] ~= nil then
        return
    end
    robots[robot_id] = robot(robot_id,manager_id)
    robots[robot_id]:login()
end

local function on_set_robot_manager_id(managerid)
    manager_id = managerid
    _init_scene_detour(common_scene_config.get_scene_resource_ids())
end

local function on_aoi_add(robot_id,scene_id,entity_id,data,x,y,z,orientation,speed)
    if robots[robot_id] == nil then
        return
    end
    robots[robot_id]:on_aoi_add(scene_id,entity_id,data,x,y,z,orientation,speed)
end

local function on_aoi_del(robot_id,scene_id,entity_id)
    if robots[robot_id] == nil then
        return
    end
    robots[robot_id]:on_aoi_del(scene_id,entity_id)
end

local function on_aoi_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
    if robots[robot_id] == nil then
        return
    end
    robots[robot_id]:on_aoi_move(scene_id,server_time,entity_id,x,y,z,orientation,speed)
end

local function on_aoi_stop_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
    if robots[robot_id] == nil then
        return
    end
    robots[robot_id]:on_aoi_stop_move(scene_id,server_time,entity_id,x,y,z,orientation,speed)
end

local function on_aoi_force_position(robot_id,scene_id,entity_id,x,y,z)
    if robots[robot_id] == nil then
        return
    end
    robots[robot_id]:on_aoi_force_position(scene_id,entity_id,x,y,z)
end

local function on_aoi_turn_direction(robot_id,scene_id,entity_id,x,y,z,direction)
    if robots[robot_id] == nil then
        return
    end
    robots[robot_id]:on_aoi_turn_direction(robot_id,scene_id,entity_id,x,y,z,direction)
end

local function get_robot(robot_id)
    return robots[robot_id]
end

return{
    on_server_message = on_server_message,
    on_client_runing = on_client_runing,
    on_client_connected = on_client_connected,
    on_set_robot_manager_id = on_set_robot_manager_id,
    on_aoi_add = on_aoi_add,
    on_aoi_del = on_aoi_del,
    on_aoi_move = on_aoi_move,
    on_aoi_stop_move = on_aoi_stop_move,
    on_aoi_force_position = on_aoi_force_position,
    on_aoi_turn_direction = on_aoi_turn_direction,
    get_robot = get_robot,
}