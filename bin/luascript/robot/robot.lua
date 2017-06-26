--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/18 0018
-- Time: 15:54
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"
local const = require "Common/constant"
local flog = require "basic/log"
local table = table
local robot_net = require "robot/robot_net"
local timer = require "basic/timer"
local robot_status = require "robot/robot_status"
local robot_state = require "robot/robot_state"
local robot_aoi_manager = require "robot/robot_aoi_manager"
local robot_action = require "robot/robot_action"

local objectid = objectid
local table = table
local math = math
local _set_client_state = _set_client_state
local _get_now_time_second = _get_now_time_second
local _sync_time = _sync_time

local message_handler = {}
function register_client_message_handler(key_action, handle_function)
    if type(key_action) ~= "number" then
        flog("error", "register_message_handler: key_action is not legal " ..key_action )
        return false
    end

    if type(handle_function) ~= "function" then
        flog("error", "register_message_handler: The handle_function is not function " ..key_action )
        return false
    end

    message_handler[key_action] = message_handler[key_action] or {}

    table.insert(message_handler[key_action], handle_function)
    return true
end

local robot = ExtendClass()

function robot:__ctor(robot_id,manager_id)
    self.robot_id = robot_id
    self.user_name = "robot_"..(manager_id*1000 + robot_id)
    self.password = "123"
    self.device_id = objectid()
    self.manager_id = manager_id
    self.enter_scene_timer = nil
    self.robot_status = robot_status.ROBOT_STATUS_CONNECTED
    self.state = robot_state.idle
    self.next_state_change_time = 0
    self.aoi_manager = robot_aoi_manager(robot_id)
    self.robot_action = robot_action(robot_id)
end

local function remove_enter_scene_timer(self)
    if self.enter_scene_timer ~= nil then
        timer.destroy_timer(self.enter_scene_timer)
        self.enter_scene_timer = nil
    end
end

function robot:send_message(key_action,data)
    robot_net.send_message(self.robot_id,key_action,data)
end

function robot:login()
    self:send_message(const.CS_MESSAGE_LOGIN_LOGIN,{user_name=self.user_name,password=self.password,device_id=self.device_id})
end

function robot:on_message(key_action,data)
    flog("debug","robot key_action "..key_action)
    local handler_table = message_handler[key_action]
    if handler_table == nil then
        --flog("warn", "avatar on_message: not message handler "..key_action)
        return
    end

    for _, handler in pairs(handler_table) do
        handler(self, data)
    end
end

local function on_login_login_ret(self,data)
    if data.result ~= 0 then
        flog("debug","on_login_login_ret error "..data.result)
        self:set_client_state(robot_status.ROBOT_STATUS_LOGIN_FAILED)
        return
    end
    if #data.actor_list > 0 then
        --选择玩家进入游戏
        self:send_message(const.CS_MESSAGE_LOGIN_SELECT_ACTOR,{actor_name=data.actor_list[1].actor_name,actor_id=data.actor_list[1].actor_id})
    else
        --创建新角色
        local data = {
            actor_name="r_"..(self.manager_id*1000 + self.robot_id),
            vocation = math.random(3),
            sext = math.random(2),
            country = "random",
        }
        self:send_message(const.CS_MESSAGE_LOGIN_CREATE_ACTOR,data)
    end
end

local function on_login_create_actor_ret(self,data)
    if data.result ~= 0 then
        flog("debug","on_login_create_actor_ret error "..data.result)
        self:set_client_state(robot_status.ROBOT_STATUS_LOGIN_FAILED)
        return
    end
    self:send_message(const.CS_MESSAGE_LUA_LOGIN,{})

end

local function on_login_select_actor_ret(self,data)
    if data.result ~= 0 then
        flog("debug","on_login_select_actor_ret error "..data.result)
        self:set_client_state(robot_status.ROBOT_STATUS_LOGIN_FAILED)
        return
    end
    self:send_message(const.CS_MESSAGE_LUA_LOGIN,{})
end

local function on_login_ret(self,data)
    if data.result ~= 0 then
        flog("debug","on_login_ret error "..data.result)
        self:set_client_state(robot_status.ROBOT_STATUS_LOGIN_FAILED)
        return
    end
    self:set_client_state(robot_status.ROBOT_STATUS_RUN)
    self.login_data = table.copy(data.login_data)
    self.aoi_manager:set_my_entity_id(self.login_data.entity_id)
    self.robot_action:set_entity_id(self.login_data.entity_id)
    self:send_message(const.CS_MESSAGE_LUA_ENTER_SCENE, {scene_id = self.login_data.scene_id})
end

local function on_enter_scene_ret(self,data)
    flog("debug","on_enter_scene_ret result "..data.result)
    if data.result ~= 0 then
        flog("debug","on_enter_scene_ret "..data.result)
        if self.robot_status == robot_status.ROBOT_STATUS_CONNECTED then
            self:set_client_state(robot_status.ROBOT_STATUS_LOGIN_FAILED)
        end
        return
    end
    self:send_message(const.CS_MESSAGE_LUA_LOADED_SCENE, {scene_id = data.scene_id})
    self.aoi_manager:clear()
    self.aoi_manager:set_aoi_scene_id(data.aoi_scene_id)
    self.robot_action:set_scene_info(data.scene_id,data.scene_type,data.aoi_scene_id)
end

local function on_loaded_scene_ret(self,data)
    flog("debug","on_loaded_scene_ret result "..data.result)
    if data.result ~= 0 then
        if self.robot_status == robot_status.ROBOT_STATUS_CONNECTED then
            self:set_client_state(robot_status.ROBOT_STATUS_LOGIN_FAILED)
        end
        return
    end
end

local function on_game_rpc(self,data)
    if data.func_name ~= nil and self[data.func_name] ~= nil then
        self[data.func_name](self,data)
    end
end

function robot:set_client_state(value)
    _set_client_state(self.robot_id,value)
end

function robot:on_client_runing()
    self.robot_action:tick()
end

function robot:on_aoi_add(scene_id,entity_id,data,x,y,z,orientation,speed)
    self.aoi_manager:on_aoi_add(scene_id,entity_id,data,x,y,z,orientation,speed)
end

function robot:on_aoi_del(scene_id,entity_id)
    self.aoi_manager:on_aoi_del(scene_id,entity_id)
end

function robot:on_aoi_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
    self.aoi_manager:on_aoi_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
end

function robot:on_aoi_stop_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
    self.aoi_manager:on_aoi_stop_move(robot_id,scene_id,server_time,entity_id,x,y,z,orientation,speed)
end

function robot:on_aoi_force_position(scene_id,entity_id,x,y,z)
    self.aoi_manager:on_aoi_force_position(scene_id,entity_id,x,y,z)
end

function robot:on_aoi_turn_direction(robot_id,scene_id,entity_id,x,y,z,direction)
    self.aoi_manager:on_aoi_turn_direction(robot_id,scene_id,entity_id,x,y,z,direction)
end

function robot:OnUpdateGameLineRet(data)
    self.curLineId = data.game_id
    _sync_time(self.robot_id)
end

function robot:get_action()
    return self.robot_action
end

register_client_message_handler(const.SC_MESSAGE_LOGIN_LOGIN,on_login_login_ret)
register_client_message_handler(const.SC_MESSAGE_LOGIN_CREATE_ACTOR,on_login_create_actor_ret)
register_client_message_handler(const.SC_MESSAGE_LOGIN_SELECT_ACTOR,on_login_select_actor_ret)
register_client_message_handler(const.SC_MESSAGE_LUA_LOGIN,on_login_ret)
register_client_message_handler(const.SC_MESSAGE_LUA_ENTER_SCENE,on_enter_scene_ret)
register_client_message_handler(const.SC_MESSAGE_LUA_LOADED_SCENE,on_loaded_scene_ret)
register_client_message_handler(const.SC_MESSAGE_LUA_GAME_RPC,on_game_rpc)
return robot