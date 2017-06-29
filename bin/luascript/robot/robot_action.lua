--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/6/21 0021
-- Time: 17:30
-- To change this template use File | Settings | File Templates.
--
require "Common/basic/LuaObject"
require "UnityEngine/Vector3"
local flog = require "basic/flog"
local common_scene_config = require "configs/common_scene_config"
local progress_test_config = require "configs/progress_test_config"
local robot_state = require "robot/robot_state"
local const = require "Common/constant"

local math = math
local _get_path = _get_path
local _get_now_time_second = _get_now_time_second
local _get_now_time_mille = _get_now_time_mille
local table_insert = table.insert
local table_remove = table.remove
local math_pi = 3.141592653589793
local table = table
local _robot_move = _robot_move
local move_msg_interval = 3000

local move_type = {
    None = 0,
    Destination = 1,
    Direction = 2,
}

local robot_action = ExtendClass()

function robot_action:__ctor(robot_id)
    self.robot_id = robot_id
    self.state = robot_state.idle
    self.scene_id = 0
    self.aoi_scene_id = 0
    self.scene_type = const.SCENE_TYPE.WILD
    self.first_walk_tick = true
    self.next_state_change_time = _get_now_time_second()
    self.last_move_message_time = _get_now_time_mille()
    self.move_type = move_type.None
end

function robot_action:set_entity_id(entity_id)
    self.entity_id = entity_id
end

function robot_action:set_scene_info(scene_id,scene_type,aoi_scene_id)
    self.scene_id = scene_id
    self.scene_type = scene_type
    self.aoi_scene_id = aoi_scene_id
    self.path= {}
    self.state = const.SCENE_TYPE.WILD
    self.next_state_change_time = _get_now_time_second() + math.random(5,10)
    self.x = nil
    self.y = nil
    self.z = nil
    self.direction = 0
    self.last_direction = 0
end

function robot_action:set_position(x,y,z)
    self.x = x
    self.y = y
    self.z = z
end

function robot_action:set_speed(value)
    self.speed = value
end

function robot_action:get_path()
    if self.x == nil or self.y == nil or self.z == nil then
        return false
    end
    local resource_id = common_scene_config.get_scene_config(self.scene_id).SceneID
    if resource_id ~= nil then
        local target = progress_test_config.get_next_random_pos(resource_id)
        flog.log("info","find path!!!,(%f,%f,%f)-->(%f,%f,%f)",self.x,self.y,self.z,target.x,target.y,target.z)
        local result,path = _get_path(resource_id,self.x,self.y,self.z,target.x,target.y,target.z)
        if result == false then
            flog.log("info","result == false can not find path!!!,(%f,%f,%f)-->(%f,%f,%f)",self.x,self.y,self.z,target.x,target.y,target.z)
            return false
        end
        self.path = {}
        for i = 4,#path,3 do
            table_insert(self.path,{x=path[i],y=path[i+1],z=path[i+2]})
        end
        if #self.path < 1 then
            flog.log("info","can not find path!!!,(%f,%f,%f)-->(%f,%f,%f)",self.x,self.y,self.z,target.x,target.y,target.z)
            return false
        end
        return true
    end
    return false
end

function robot_action:idle()
    if _get_now_time_second() >= self.next_state_change_time then
        self.next_state_change_time = _get_now_time_second() + math.random(5,10)
        if self:get_path() then
            self.state = robot_state.walk
            self.first_walk_tick = true
            self.last_move_message_time = 0
        end
    end
end


local function stop_move(self)
    self.path = {}
    self.next_state_change_time = _get_now_time_second() + math.random(5,10)
    self.state = robot_state.idle
    _robot_move(self.robot_id,self.aoi_scene_id,self.entity_id,self.x,self.y,self.z,self.direction,self.speed)
    self.last_move_message_time = 0
    self.move_type = move_type.None
end

local function sync_move(self)
    if _get_now_time_mille() - self.last_move_message_time > move_msg_interval  or math.abs(self.direction - self.last_direction) > 0.015 then
        self.last_move_message_time = _get_now_time_mille()
        self.last_direction = self.direction
        flog.log("tmlDebug","sync_move robot_id %d (%f,%f.%f) time %s",self.robot_id,self.x,self.y,self.z,self.last_move_message_time)
        _robot_move(self.robot_id,self.aoi_scene_id,self.entity_id,self.x,self.y,self.z,self.direction,self.speed)
    end
end

function robot_action:walk()
    if table.isEmptyOrNil(self.path) then
        stop_move(self)
        return
    end

    local delta_time = self.delta_time
    local next_corner = Vector3.New(self.path[1].x,self.path[1].y,self.path[1].z)
    local current_pos = Vector3.New(self.x,self.y,self.z)
    local dir = next_corner - current_pos
    dir.y = 0
    local delta_dir =Vector3.Normalize(dir)*((self.speed / 100)*delta_time/1000)
    local next_pos = current_pos + delta_dir
    local dir_after = next_corner - next_pos
    dir_after.y = 0
    if dir:Magnitude() > 0 then
        self.direction = math.atan2(dir.x, dir.z) * 180 / math_pi;
    end
    local dot = dir.x*dir_after.x + dir.z*dir_after.z
    if dot < 0 or dir:Magnitude() < 0.01 then
        self.x = next_corner.x
        self.y = next_corner.y
        self.z = next_corner.z
        if #self.path > 1 then
            table_remove(self.path,1)
        else
            stop_move(self)
            return
        end
    else
        self.x = next_pos.x
        self.y = next_pos.y
        self.z = next_pos.z
    end
    sync_move(self)
end

function robot_action:tick()
    if self.last_tick_time == nil then
        self.delta_time = 100
    else
        self.delta_time = _get_now_time_mille() - self.last_tick_time
    end
    self.last_tick_time = _get_now_time_mille()
    --flog.log("tmlDebug","robot_action:tick last_tick_time %s",self.last_tick_time)
    if self.state == robot_state.idle then
        self:idle()
    elseif self.state == robot_state.walk then
        self:walk()
    end
end

return robot_action