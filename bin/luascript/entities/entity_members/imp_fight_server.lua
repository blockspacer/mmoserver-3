--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/20 0020
-- Time: 15:46
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local net_work = require "basic/net"
local send_message_to_fight = net_work.send_message_to_fight
local flog = require "basic/log"
local fight_server_type = const.FIGHT_SERVER_TYPE
local timer = require "basic/timer"

local params = {}
local imp_fight_server = {}
imp_fight_server.__index = imp_fight_server

setmetatable(imp_fight_server, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_fight_server.__params = params

function imp_fight_server.__ctor(self)
    self.ip = ""
    self.port = 0
    self.fight_id = ""
    self.token = ""
    self.fight_server_id = 0
    self.fight_server_connect_timer = nil
end

function imp_fight_server.remove_fight_server_connect_server(self)
    if self.fight_server_connect_timer ~= nil then
        self.fight_server_connect_timer = timer.destroy_timer(self.fight_server_connect_timer)
        self.fight_server_connect_timer = nil
    end
end

function imp_fight_server.set_fight_server_info(self,fight_server_id,ip,port,token,fight_id,fight_type)
    if self.fight_server_connect_timer ~= nil then
        self:on_failed_connet_fight_server({})
        self:remove_fight_server_connect_server()
    end
    self.ip = ip
    self.port = port
    self.token = token
    self.fight_id = fight_id
    self.fight_server_id = fight_server_id
    self.fight_type = fight_type
end

function imp_fight_server.connet_fight_server(self)
    flog("tmlDebug","imp_fight_server.connet_fight_server")
    local data = {}
    data.result = 0
    data.func_name = "ConnetFightServer"
    data.ip = self.ip
    data.port = self.port
    data.token = self.token
    data.fight_id = self.fight_id
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,data)
end

function imp_fight_server.write_fight_server_info_to_dict(self,dict)
    dict.fight_server_info = {}
    dict.fight_server_info.ip=self.ip
    dict.fight_server_info.port = self.port
    dict.fight_server_info.token = self.token
    dict.fight_server_info.fight_id = self.fight_id
    dict.fight_server_info.fight_type = self.fight_type
end

function imp_fight_server.send_to_fight_server(self,key_action,msg_data)
    msg_data.actor_id = self.actor_id
    send_message_to_fight(self.fight_server_id,key_action,msg_data)
end

function imp_fight_server.make_combat_info(self, input)
    self:imp_player_write_to_sync_dict(input)
    self:imp_property_write_to_sync_dict(input)
    self:imp_seal_write_to_sync_dict(input)
    self:imp_skill_write_to_sync_dict(input)
    self:imp_teamup_write_to_sync_dict(input)
    self:imp_appearance_write_to_sync_dict(input)

end

function imp_fight_server.send_fight_info_to_fight_server(self,data)
    local combat_info = {}
    self:make_combat_info(combat_info)
    data.fight_id = self.fight_id
    data.fight_type = self.fight_type
    data.func_name = "on_initialize_fight_avater"
    data.combat_info = combat_info
    combat_info.is_reward_enable = self.is_reward_enable
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, data)
end

local function connet_fight_server_failed(self,result)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="FailedConnectFightServerRet",result=result})
end

function imp_fight_server.on_failed_connet_fight_server(self,input)
    flog("warn","imp_fight_server.on_failed_connet_fight_server actor_id"..self.actor_id)
    if self.fight_type == fight_server_type.MAIN_DUNGEON then
        self:on_fight_avatar_leave_main_dungeon({})
    elseif self.fight_type == fight_server_type.TEAM_DUNGEON then
        self:on_fight_avatar_quit_team_dungeon({})
    elseif self.fight_type == fight_server_type.TASK_DUNGEON then
        self:on_fight_avatar_quit_team_dungeon({})
    elseif self.fight_type == fight_server_type.DOGFIGHT_ARENA then
        self:can_not_connect_dogfight_fight_server()
    elseif self.fight_type == fight_server_type.QUALIFYING_ARENA then
        self:can_not_connect_qualifying_fight_server()
    end
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_failed_connet_fight_server",fight_id=self.fight_id})
    connet_fight_server_failed(self,0)
end

function imp_fight_server.on_failed_connet_fight_server_reply(self,input)
    if input.success then
        self.in_fight_server = false
    else
        flog("warn","imp_fight_server.on_failed_connet_fight_server_reply success = false")
    end
end

function imp_fight_server.on_client_connect_fight_server(self,input)
    self:remove_fight_server_connect_server()
end

function imp_fight_server.client_start_connect_server(self)
    if self.fight_server_connect_timer ~= nil then
        return
    end

    local function connect_fight_server_handle()
        self:on_failed_connet_fight_server({})
        self:remove_fight_server_connect_server()
    end
    self.fight_server_connect_timer = timer.create_timer(connect_fight_server_handle,30000,0)
end

function imp_fight_server.is_connecting_fight_server(self)
    return self.fight_server_connect_timer ~= nil
end

return imp_fight_server

