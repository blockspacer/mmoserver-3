--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/15 0015
-- Time: 14:01
-- To change this template use File | Settings | File Templates.
--

local flog = require "basic/log"
local const = require "Common/constant"
local net_work = require "basic/net"
local send_to_client = net_work.send_to_client
local send_to_game = net_work.forward_message_to_game
local timer = require "basic/timer"
local data_base = require "basic/db_mongo"

local global_avatar = {}
global_avatar.__index = global_avatar

setmetatable(global_avatar, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local entity_part_list = {
   "imp_global_player","imp_global_friend","imp_global_chat",
    }

local db_scheme = {}
local sync_scheme = {}
local broadcast_scheme = {}

local message_handler = {}
function register_message_handler(key_action, handle_function)
    if type(key_action) ~= "number" then
        flog("error", "global avatar register_message_handler: key_action is not legal " ..key_action )
        return false
    end

    if type(handle_function) ~= "function" then
        flog("error", "global avatar register_message_handler: The handle_function is not function " ..key_action )
        return false
    end

    message_handler[key_action] = message_handler[key_action] or {}

    table.insert(message_handler[key_action], handle_function)
    return true
end

for _, v in pairs(entity_part_list) do
    local module_name = "global/entity_members/"..v
    local module = require(module_name)
    local module_params = module.__params
    for j, param in pairs(module_params) do
        if param.db then
            db_scheme[j] = true
        end
        if param.sync then
            sync_scheme[j] = true
        end
        if param.broadcast then
            broadcast_scheme[j] = true
        end
    end
end

function global_avatar.__ctor(self)
    self.syn_buffer = {}
    self.save_timer = nil
    self.is_logout = false
    -- 添加entity模块
    for _, name in ipairs(entity_part_list) do
        local module_name = "global/entity_members/"..name
        local module = require(module_name)()

        if not module then
            flog("error", "entity_part "..name.."创建失败")
        end

        for i, v in pairs(module) do
            self[i] = v
        end
        local moudule_metatable = getmetatable(module)
        for i, v in pairs(moudule_metatable) do
            if string.sub(i,1,2) ~= "__" then
                global_avatar[i] = v
            end
        end
    end
end

local function remove_save_timer(self)
    if self.save_timer ~= nil then
        timer.destroy_timer(self.save_timer)
        self.save_timer = nil
    end
end


local function _db_callback_save_data(caller, status)
    if status == false then
        flog("warn", "global _db_callback_save_data : save fail ")
    end
    if caller.is_logout then
        global_server_message_center.del_user(caller.actor_id)
    end
end

local function _save_data(self)
    local dict = {}
    --模块数据保存
    for i in pairs(entity_part_list) do
        if global_avatar[entity_part_list[i].."_write_to_dict"] ~= nil then
            global_avatar[entity_part_list[i].."_write_to_dict"](self, dict)
        end
    end

    --flog("syzDebug", "The save data of is " .. table.serialize(dict))
    data_base.db_update_doc(self, _db_callback_save_data, "global_player", {actor_id = self.actor_id}, dict, 1, 0)

    return dict
end


-- 玩家通过数据库数据
function global_avatar.init(self, dict)
    flog("info", "Global avatar init")

    --初始化模块数据
    for i, v in ipairs(entity_part_list) do
        if global_avatar[v.."_init_from_dict"] ~= nil then
            global_avatar[v.."_init_from_dict"](self, dict)
        end
    end

    --定时器
    local function syn_tick()
        --保存数据到数据库
        _save_data(self)
    end
    remove_save_timer(self)
    self.save_timer = timer.create_timer(syn_tick, 600000, const.INFINITY_CALL)
end

function global_avatar.on_friend_player_logout(self)
    self.is_logout = true
    self:player_left_team()
    self:_set("offlinetime",_get_now_time_second())
    remove_save_timer(self)
    _save_data(self)
end

function global_avatar.get(self, param_name)
    return self[param_name]
end

function global_avatar.send_message_to_client(self, key_action, msg_data)
    send_to_client(self.session_id, key_action, msg_data)
end

function global_avatar.send_message_to_game(self, key_action, msg_data)
    msg_data.actor_id = self.actor_id
    send_to_game(self.src_game_id,key_action,msg_data)
end

--给参数赋值，建议外部不要调用
function global_avatar._set(self, param_name, value)
    if type(self[param_name]) == "table" then
        self[param_name] = table.copy(value)
    else
        self[param_name] = value
    end

    if sync_scheme[param_name] then
        self.syn_buffer[param_name] = value
    end
end


function global_avatar.on_message(self, key_action, input)
    flog("syzDebug", "global avatar on message "..key_action)
    local hander_table = message_handler[key_action]
    if hander_table == nil then
        flog("error", "global avatar on_message: not message handler "..key_action)
        return
    end

    for _, handler in pairs(hander_table) do
        handler(self, input, self.syn_buffer)
    end
end

global_avatar.on_player_session_changed = require("helper/global_common").on_player_session_changed

return global_avatar