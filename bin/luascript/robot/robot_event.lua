--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/18 0018
-- Time: 14:37
-- To change this template use File | Settings | File Templates.
--

local robot_manager = require "robot/robot_manager"
local flog = require "basic/flog"

--执行服务端返回消息
function OnServerMessage(robot_id,key_action,data)
    robot_manager.on_server_message(robot_id,key_action,data)
end

--客户端执行下一个操作
function OnClientRuning(robot_id)
    robot_manager.on_client_runing(robot_id)
end

--连接完成，准备登录
function OnClientConnected(robot_id)
    robot_manager.on_client_connected(robot_id)
end

function OnSetRobotManagerID(manager_id,log_level)
    flog.set_level(log_level)
    robot_manager.on_set_robot_manager_id(manager_id)
end

function OnAOIAdd(robot_id,scene_id,entity_id,data,x,y,z,orientation,speed)
    robot_manager.on_aoi_add(robot_id,scene_id,entity_id,data,x,y,z,orientation,speed)
end

function OnAOIDel(robot_id,scene_id,entity_id)
    robot_manager.on_aoi_del(robot_id,scene_id,entity_id)
end

function OnAOIMove(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
    robot_manager.on_aoi_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
end

function OnAOIStopMove(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
    robot_manager.on_aoi_stop_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
end

function OnAOIForcePosition(robot_id,scene_id,entity_id,x,y,z)
    robot_manager.on_aoi_force_position(robot_id,scene_id,entity_id,x,y,z)
end

function OnAOITurnDirection(robot_id,scene_id,entity_id,x,y,z,direction)
    robot_manager.on_aoi_turn_direction(robot_id,scene_id,entity_id,x,y,z,direction)
end