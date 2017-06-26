--------------------------------------------------------------------
-- 文件名:	avatar.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/08/26
-- 描  述:	玩家控制的类
--------------------------------------------------------------------
local flog = require "basic/log"
local entity_factory = require "entity_factory"
local const = require "Common/constant"
local net_work = require "basic/net"
local send_to_client = net_work.send_to_client
local broadcast_message = net_work.broadcast_message
local timer = require "basic/timer"
local data_base = require "basic/db_mongo"
local config = require "server_config"
local entity_common = require "entities/entity_common"
local center_server_manager = require "center_server_manager"

local avatar = {}
local parent = {}
avatar.__index = avatar

setmetatable(avatar, {
  __index = parent,
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local parent_part_list = {
    "imp_aoi_common","imp_interface", "imp_player_only",
}

local entity_part_list = {
   "imp_player", "imp_property", "imp_dungeon", "imp_assets", "imp_seal", "imp_equipment", "imp_store","imp_friend","imp_chat",
    "imp_skill","imp_aoi","imp_teamup","imp_arena", "imp_country","imp_pk","imp_mail","imp_red_points","imp_faction","imp_fight_server",
    "imp_appearance","imp_task","imp_activity","imp_redis_rank","imp_gift_code","imp_country_war", "imp_talent",
}

local db_scheme = {}
local sync_scheme = {}
local broadcast_scheme = {}

local message_handler = {}
function register_message_handler(key_action, handle_function)
    if type(key_action) ~= "number" or key_action <= const.MESSAGE_LUA_START or key_action >= const.MESSAGE_LUA_END then
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

for _, v in ipairs(entity_part_list) do
    local module_name = "entities/entity_members/"..v
    flog("syzDebug", "module_name "..module_name)
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

function avatar.__ctor(self, entity_id)
    self.entity_id = entity_id
    self.saver_timer = nil
    self.type = const.ENTITY_TYPE_PLAYER
    self.aoi_proxy = nil
    self.game_id = _get_serverid()

    -- 添加entity模块
    entity_common.create_entity_module(self, avatar, entity_part_list, parent, parent_part_list)
end


local function remove_save_timer(saver_timer, actor_id)
    --flog("salog", "remove_save_timer ", actor_id)
    if saver_timer ~= nil then
        flog("salog", "remove_save_timer save timer not nil", actor_id)
        timer.destroy_timer(saver_timer)
        saver_timer = nil
    end
end

local function _db_callback_save_data(playerdata, status)
    if status == false then
        flog("error", "_db_callback_save_data : save fail "..playerdata.actor_id)
        return
    end
    if playerdata.callback ~= nil then
        playerdata.callback()
    end
    if playerdata.is_logout == true then
        flog("salog", "Player Save Data success ", playerdata.actor_id)
        remove_save_timer(playerdata.saver_timer, playerdata.actor_id)
    end
end

local function _save_data(self, callback)
    if self.is_logout == true then
        return
    end
    local dict = {}
    --模块数据保存
    for _, v in pairs(entity_part_list) do
        if avatar[v.."_write_to_dict"] ~= nil then
            avatar[v.."_write_to_dict"](self, dict)
        end
    end

    local coin = self.inventory:get_resource("coin")
    local ingot = self.inventory:get_resource("ingot")
    local pet_num = #self.pet_list
    flog("salog", string.format("Player Save Data %d, ingot %d, coin %d, pet_num %d", self.level, ingot, coin, pet_num), self.actor_id)

    local player_data = {}
    player_data.actor_id = self.actor_id
    player_data.is_logout = self.is_logout
    player_data.saver_timer = self.saver_timer
    player_data.callback = callback
    data_base.db_update_doc(player_data, _db_callback_save_data, "actor_info", {actor_id = self.actor_id}, dict, 1, 0)

    return dict
end

function avatar.on_login(self)
    local coin = self.inventory:get_resource("coin")
    local ingot = self.inventory:get_resource("ingot")
    local pet_num = #self.pet_list
    flog("salog", string.format("Player Login level %d, ingot %d, coin %d, pet_num %d", self.level, ingot, coin, pet_num), self.actor_id)


    --定时器
    remove_save_timer(self.saver_timer, self.actor_id)
    local function syn_tick()
        --保存数据到数据库
        _save_data(self)
    end

    self.saver_timer = timer.create_timer(syn_tick, 600000, const.INFINITY_CALL)
end

-- 通过table初始化数据
-- NPC通过系统配置
-- 玩家通过数据库数据
function avatar.init(self, dict)
    flog("info", "Avatar init")

    entity_common.init_all_module_from_dict(self, dict, avatar, entity_part_list)
    avatar.on_login(self)
end

function avatar.on_logout(self, callback)
    self:remove_player_timer()
    self:remove_fight_server_connect_server()
    local close_aoi = function ()
        avatar.imp_aoi_set_pos(self)
        avatar.leave_aoi_scene(self)
    end
    local err_handler = function ()
        flog("warn", "save aoi failed!")
    end
    xpcall(close_aoi, err_handler)

    remove_save_timer(self.saver_timer, self.actor_id)
    _save_data(self, callback)
    self.is_logout = true

    local coin = self.inventory:get_resource("coin")
    local ingot = self.inventory:get_resource("ingot")
    local pet_num = #self.pet_list
    flog("salog", string.format("Player Logout level %d, ingot %d, coin %d, pet_num %d", self.level, ingot, coin, pet_num), self.actor_id)
    --通知邮件服务器
    self:send_message_to_mail_server({func_name="on_mail_player_logout",actor_id=self.actor_id})
    --通知阵营服务器
    self:send_message_to_country_server({func_name="on_country_player_logout",actor_id=self.actor_id})
    --通知帮派服务器
    self:send_message_to_faction_server({func_name="on_faction_player_logout",actor_id=self.actor_id})
    --通知排名服务器
    self:send_message_to_ranking_server({func_name="on_ranking_player_logout",actor_id=self.actor_id})
    --通知商店服务器
    self:send_message_to_shop_server({func_name="on_shop_player_logout",actor_id=self.actor_id})
    --通知好友服务器
    self:send_message_to_friend_server({func_name="on_friend_player_logout",actor_id = self.actor_id})
    return
end

function avatar.save_data(self, callback)
    flog("salog", "avatar.save_data(self) not tick", self.actor_id)
    avatar.imp_aoi_set_pos(self)
    _save_data(self, callback)
end

function avatar.get(self, param_name)
    return self[param_name]
end

function avatar.send_message(self, key_action, msg_data)
    send_to_client(self.session_id, key_action, msg_data)
end

function avatar.transport_message_to_game_server(self,data)
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service,const.SG_MESSAGE_GAME_RPC_TRANSPORT,data)
end

function avatar.transport_message_to_client(self,data)
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service,const.SG_MESSAGE_CLIENT_RPC_TRANSPORT,data)
end

function avatar.send_message_to_friend_server(self,data)
    data.actor_id = self.actor_id
    data.session_id = string.format("%16.0f",self.session_id)
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service,const.GG_MESSAGE_LUA_GAME_RPC,data)
end

function avatar.send_message_to_ranking_server(self,data)
    data.actor_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.ranking_service,const.GR_MESSAGE_LUA_GAME_RPC,data)
end

function avatar.send_message_to_faction_server(self,data)
    data.actor_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.faction_service,const.GF_MESSAGE_LUA_GAME_RPC,data)
end

function avatar.send_message_to_country_server(self,data)
    data.actor_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.country_service,const.GC_MESSAGE_LUA_GAME_RPC,data)
end

function avatar.send_message_to_shop_server(self,data)
    data.actor_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.shop_service,const.GS_MESSAGE_LUA_GAME_RPC,data)
end

function avatar.send_message_to_team_server(self,data)
    data.actor_id = self.actor_id
    data.team_id = self.team_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.team_service,const.GT_MESSAGE_LUA_GAME_RPC,data)
end

function avatar.send_message_to_mail_server(self,data)
    data.actor_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.mail_service,const.OM_MESSAGE_LUA_GAME_RPC,data)
end

function avatar.send_message_to_arena_server(self,data)
    data.actor_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.arena_service,const.SA_MESSAGE_LUA_GAME_ARENA_RPC,data)
end

function avatar.send_message_to_cross_server_arena_server(self,data)
    data.actor_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.cross_server_arena_service,const.GCA_MESSAGE_LUA_GAME_RPC,data)
end

function avatar.send_message_to_line_server(self,data)
    data.actor_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.line_service,const.SL_MESSAGE_LUA_GAME_RPC,data)
end

function avatar.broadcast_message(self,key_action, msg_data)
    broadcast_message(key_action,msg_data)
end

--给参数赋值，建议外部不要调用
function avatar._set(self, param_name, value)
    if type(self[param_name]) == "table" then
        self[param_name] = table.copy(value)
    else
        self[param_name] = value
    end

    if sync_scheme[param_name] then
        local buffer = {}
        buffer[param_name] = value
        flog("syzDebug", "update message ")
        avatar.send_message(self, const.SC_MESSAGE_LUA_UPDATE, buffer)
    end
    --[[if db_scheme[param_name] then
    end
    if sync_scheme[param_name] then
        self:send_message(const.SC_MESSAGE_LUA_UPDATE, {param_name = value})
    end
    if broadcast_scheme[param_name] then
    end]]
end

--属性值自增
function avatar._inc(self, param_name, inc_num)
    inc_num = inc_num or 1
    avatar._set(self, param_name, self[param_name] + inc_num)
end

--属性值自减
function avatar._dec(self, param_name, dec_num)
    dec_num = dec_num or 1
    avatar._set(self, param_name, self[param_name] - dec_num)
end


function avatar.on_message(self, key_action, input)
    flog("syzDebug", "avatar on message "..key_action)
    flog('net_msg', key_action)

    --[[local b_dead, dead_time = self:is_player_die()
    if b_dead and not const.ALLOW_WHILE_DEAD[key_action] then
        flog("info", "can not do this while dead "..key_action)
        avatar.send_message(self, const.SC_MESSAGE_LUA_ERROR_INFO, {result = const.error_invalid_while_dead, dead_time = dead_time} )
        return
    end]]

    local hander_table = message_handler[key_action]
    if hander_table == nil then
        flog("warn", "avatar on_message: not message handler "..key_action)
        return
    end

    for _, handler in pairs(hander_table) do
        local buffer = {}
        handler(self, input, buffer)
        if not table.isEmptyOrNil(buffer) then
            flog("info", "update message ")
            avatar.send_message(self, const.SC_MESSAGE_LUA_UPDATE, buffer )
        end
    end
end

function avatar.gm_on_reset(self)
    local session_id = self.session_id
    for _, v in pairs(entity_part_list) do
       avatar[v.."_write_to_dict"] = function () end
    end
    _kickoffline(session_id)
end

function avatar.write_to_other_game_dict(self,dict)
    local dict = {}
    --写入数据，传送到其他进程
    for _, v in pairs(entity_part_list) do
        if avatar[v.."_write_to_other_game_dict"] ~= nil then
            avatar[v.."_write_to_other_game_dict"](self, dict)
        end
    end
    return dict
end

function avatar.init_from_other_game_dict(self,dict)
    flog("info", "Avatar init_from_other_game_dict")

    --从其他进程数据初始化数据
    for _, v in ipairs(entity_part_list) do
        if avatar[v.."_init_from_other_game_dict"] ~= nil then
            avatar[v.."_init_from_other_game_dict"](self, dict)
        end
    end

    --定时器
    remove_save_timer(self.saver_timer, self.actor_id)
    local function syn_tick()
        --保存数据到数据库
        _save_data(self)
    end

    self.saver_timer = timer.create_timer(syn_tick, 600000, const.INFINITY_CALL)
    return true
end

--通知中心服玩家game_id变更
function avatar.notice_global_game_change(self)
    --通知global玩家登录
    self:send_message_to_friend_server({func_name="on_friend_player_game_id_change",actor_id = self.actor_id,actor_game_id=self.game_id})
    --通知邮件服务器
    self:send_message_to_mail_server({func_name="on_mail_player_game_id_change",actor_id=self.actor_id,actor_game_id=self.game_id})
    --通知组队服务器
    self:send_message_to_team_server({func_name="on_team_player_game_id_change",actor_id=self.actor_id,actor_game_id=self.game_id})
    --通知竞技场服务器
    self:send_message_to_arena_server({func_name="on_arena_player_game_id_change",actor_id = self.actor_id,actor_game_id=self.game_id})
    --通知帮派服务器
    self:send_message_to_faction_server({func_name="on_faction_player_game_id_change",actor_id = self.actor_id,actor_game_id=self.game_id})
end

function avatar.on_session_changed(self, new_session_id)
    self.session_id = new_session_id
    local output = {func_name="on_player_session_changed",actor_id=self.actor_id, new_session_id = string.format("%16.0f", new_session_id)}
    --通知global玩家登录
    self:send_message_to_friend_server(output)
    --通知邮件服务器
    self:send_message_to_mail_server(output)
    --通知阵营服务器
    self:send_message_to_country_server(output)
    --通知帮派服务器
    self:send_message_to_faction_server(output)
    --通知排名服务器
    self:send_message_to_ranking_server(output)
    --通知商店服务器
    self:send_message_to_shop_server(output)
    --通知竞技场服务器
    self:send_message_to_arena_server(output)
    --通知组队服务器
    output.team_id = self.team_id
    self:send_message_to_team_server(output)
end

--玩家离开进程
function avatar.clear_player_data_when_change_game_line(self)
    self:leave_aoi_scene()
    self:destroy_update_task_timer()
    self:clear_player_timers()
    remove_save_timer(self.saver_timer, self.actor_id)
end

--当顶号退出时,通知战斗服务器
function avatar.notice_fight_server_avatar_logout(self)
    if self.in_fight_server then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_notice_fight_avatar_logout"})
    end
end

function avatar:player_offline()
    flog("tmlDebug","avatar:player_offline")
    self.is_offline = true
    local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:StopMove()
    end
    self:save_data()
end

entity_factory.register_entity(const.ENTITY_TYPE_PLAYER, avatar)

return avatar