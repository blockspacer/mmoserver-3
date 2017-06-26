--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/4/26 0026
-- Time: 15:08
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local send_to_game = require("basic/net").forward_message_to_game

local cross_server_arena_player = {}
cross_server_arena_player.__index = cross_server_arena_player

setmetatable(cross_server_arena_player, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function cross_server_arena_player.__ctor(self,game_id,actor_id,actor_name,vocation,grade_id)
    self:init(game_id,actor_id,actor_name,vocation,grade_id)
end

function cross_server_arena_player.init(self,game_id,actor_id,actor_name,vocation,grade_id)
    self.actor_id = actor_id
    self.game_id = game_id
    self.grade_id = grade_id
    self.actor_name = actor_name
    self.vocation = vocation
    self.agree = false
    self.room_id = 0
end

function cross_server_arena_player.set_actor_name(self,value)
    self.actor_name = value
end

function cross_server_arena_player.set_vocation(self,value)
    self.vocation = value
end

function cross_server_arena_player.set_grade_id(self,grade_id)
    self.grade_id = grade_id
end

function cross_server_arena_player.set_game_id(self,game_id)
    self.game_id = game_id
end

function cross_server_arena_player.set_agree(self,value)
    self.agree = value
end

function cross_server_arena_player.get_agree(self)
    return self.agree
end

function cross_server_arena_player.send_message_to_game(self,msg_data)
    msg_data.actor_id = self.actor_id
    send_to_game(self.game_id, const.OG_MESSAGE_LUA_GAME_RPC,  msg_data)
end

function cross_server_arena_player.request_agree(self,agree_time)
    self:send_message_to_game({func_name="arena_request_agree",agree_time=agree_time})
end

function cross_server_arena_player.set_room_id(self,value)
    self.room_id = value
end

function cross_server_arena_player.get_room_id(self)
    return self.room_id
end

return cross_server_arena_player



