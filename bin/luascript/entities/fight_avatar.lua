--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/3 0003
-- Time: 9:46
-- To change this template use File | Settings | File Templates.
--

local flog = require "basic/log"
local entity_factory = require "entity_factory"
local const = require "Common/constant"
local net_work = require "basic/net"
local send_to_client = net_work.send_to_client
local fight_send_to_game = net_work.fight_send_to_game
local entity_common = require "entities/entity_common"
local fight_avatar_connect_state = require "fight_server/fight_avatar_connect_state"
local table =table

local fight_avatar = {}
local parent = {}
fight_avatar.__index = fight_avatar

setmetatable(fight_avatar, {
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
    "imp_fight_avatar","imp_fight_avatar_aoi","imp_fight_avatar_team_dungeon","imp_fight_avatar_main_dungeon","imp_fight_avatar_pet","imp_property","imp_fight_avatar_skill","imp_fight_avatar_arena","imp_fight_avatar_task_dungeon"
}

local message_handler = {}
function register_fight_avatar_message_handler(key_action, handle_function)
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

function fight_avatar.__ctor(self, entity_id)
    self.combat_info = nil
    self.game_session_id = 0
    self.client_session_id = 0
    self.src_game_id = 0
    self.entity_id = entity_id
    self.type = const.ENTITY_TYPE_FIGHT_AVATAR
    self.is_logout = false

    -- 添加entity模块
    entity_common.create_entity_module(self, fight_avatar, entity_part_list, parent, parent_part_list)
end

function fight_avatar.on_initialize_fight_avater(self,input)
    flog("tmlDebug","fight_avatar|on_initialize_fight_avater!!!")
    self.combat_info = input.combat_info
    self:init(self.combat_info)
    self.fight_id = input.fight_id
    self.dungeon_id = input.dungeon_id
    self.fight_type = input.fight_type
    self.team_id = input.team_id
    self.arena_total_score = input.arena_total_score
    self.arena_address = input.arena_address
    self:fight_send_to_game({func_name="on_fight_avatar_initialize_complete"})
    self.connect_state = fight_avatar_connect_state.not_connect
    --第一次进战斗场景,满血法
    self.combat_info.immortal_data.hp = nil
    self.combat_info.immortal_data.mp = nil
    self.immortal_data = table.copy(self.combat_info.immortal_data)
end

-- 通过table初始化数据
function fight_avatar.init(self, dict)
    flog("info", "fight avatar init")

    --初始化模块数据
    entity_common.init_all_module_from_dict(self, dict, fight_avatar, entity_part_list)
end

function fight_avatar.on_logout(self,input)
    flog("tmlDebug","fight_avatar.on_logout")
    self:remove_player_timer()
    self:leave_aoi_scene()
    self.is_logout = true
    return
end

function fight_avatar.on_player_logout(self,input)
    flog("tmlDebug","fight_avatar.on_player_logout")
    if self.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
        self:on_remove_team_dungeon_member()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.MAIN_DUNGEON then

    elseif self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
        self:set_qualifying_arena_done()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
        self:leave_dogfight_arena()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
        self:on_remove_task_dungeon_member()
    end
    self:on_logout()
    --fight_server_message_center:on_game_message(self.src_game_id,const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_logout",actor_id=self.actor_id})
end

function fight_avatar.send_message(self, key_action, msg_data)
    --目前客户端与服务端session_id一样
    send_to_client(self.client_session_id, key_action, msg_data)
end

function fight_avatar.fight_send_to_game(self,data)
    data.actor_id = self.actor_id
    fight_send_to_game(self.src_game_id,const.OG_MESSAGE_LUA_GAME_RPC,data)
end

function fight_avatar.send_to_self_game(self, data)
    data.actor_id = self.actor_id
    fight_send_to_game(self.src_game_id,const.OG_MESSAGE_LUA_GAME_RPC,data)
end

function fight_avatar.on_message(self, key_action, input)
    flog("tmlDebug", "fight_avatar on message "..key_action)

    local hander_table = message_handler[key_action]
    if hander_table == nil then
        flog("warn", "fight_avatart on_message: not message handler "..key_action)
        return
    end

    for _, handler in pairs(hander_table) do
        handler(self, input)
    end
end

function fight_avatar.set_client_session_id(self,session_id)
    self.client_session_id = session_id
end

function fight_avatar.get_client_session_id(self)
    return self.client_session_id
end

function fight_avatar.set_src_game_id(self,game_id)
    self.src_game_id = game_id
end

function fight_avatar.get(self, param_name)
    return self[param_name]
end

function fight_avatar.get_entity_id(self)
    return self.entity_id
end

function fight_avatar.on_fight_server_disconnet(self)
    self:fight_send_to_game({func_name="on_fight_server_disconnet",fight_type=self.fight_type})
end

function fight_avatar.on_failed_connet_fight_server(self,input)
    if input.fight_id ~= self.fight_id then
        flog("warn","fight_avatar.on_failed_connet_fight_server fight_id not match!!!input fight id "..input.fight_id.."fight_avatar "..self.fight_id)
        self:fight_send_to_game({func_name="on_failed_connet_fight_server_reply",success=false})
        return
    end
    if self.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
        self:on_remove_team_dungeon_member()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.MAIN_DUNGEON then

    elseif self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
        self:set_qualifying_arena_done()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
        self:leave_dogfight_arena()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
        self:on_remove_task_dungeon_member()
    end
    self:fight_send_to_game({func_name="on_failed_connet_fight_server_reply",success=true})
end

function fight_avatar.get_connect_state(self)
    return self.connect_state
end

function fight_avatar.set_connect_state(self,value)
    self.connect_state = value
end

function fight_avatar.on_notice_fight_avatar_logout(self,input)
    avatar_notice_fight_avatar_close(self.client_session_id)
end

entity_factory.register_entity(const.ENTITY_TYPE_FIGHT_AVATAR, fight_avatar)

return fight_avatar