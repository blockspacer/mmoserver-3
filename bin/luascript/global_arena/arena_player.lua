--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/9 0009
-- Time: 18:52
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local net_work = require "basic/net"
local send_to_game = net_work.forward_message_to_game

local arena_player = {}
arena_player.__index = arena_player

setmetatable(arena_player, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function arena_player.__ctor(self,actor_id)
    self.game_id = nil
    self.actor_id  = actor_id
end

function arena_player.send_message_to_game(self,msg_data)
    msg_data.actor_id = self.actor_id
    send_to_game(self.game_id, const.OG_MESSAGE_LUA_GAME_RPC,  msg_data)
end

function arena_player.get_actor_id(self)
    return self.actor_id
end

function arena_player.get_game_id(self)
    return self.game_id
end

function arena_player.set_game_id(self,game_id)
    self.game_id = game_id
end

return arena_player

