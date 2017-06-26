--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/28 0028
-- Time: 15:21
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local online = require "fight_server/fight_server_online_user"

local dogfight_arena_fight_room_player = {}
dogfight_arena_fight_room_player.__index = dogfight_arena_fight_room_player

setmetatable(dogfight_arena_fight_room_player, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function dogfight_arena_fight_room_player.__ctor(self,actor_id,actor_name,vocation,rank)
    self.actor_id = actor_id
    self.actor_name = actor_name
    self.vocation = vocation
    self.scene_score = 0
    self.plunder_score  = 0
    self.total_score = 0
    self.session_score = 0
    self.rank = rank
    self.die_count = 0
    self.leave = true
    self.arena_address = nil
end

function dogfight_arena_fight_room_player.add_plunder_score(self,addon)
    if self.leave then
        return
    end

    self.plunder_score = self.plunder_score + addon
    self.total_score = self.total_score + addon
    self:update_session_score()
end

function dogfight_arena_fight_room_player.add_scene_score(self,addon)
    if self.leave then
        return
    end

    self.scene_score = self.scene_score + addon
    self.total_score = self.total_score + addon
    self:update_session_score()
end

function dogfight_arena_fight_room_player.update_session_score(self)
    self.session_score = self.plunder_score + self.scene_score
end

function dogfight_arena_fight_room_player.get_session_score(self)
    return self.session_score
end

function dogfight_arena_fight_room_player.add_die_count(self)
    self.die_count = self.die_count + 1
end

function dogfight_arena_fight_room_player.get_die_count(self)
    return self.die_count
end

function dogfight_arena_fight_room_player.set_total_score(self,value)
    flog("tmlDebug","dogfight_arena_fight_room_player.set_total_score total_score "..value)
    self.total_score = value
end

function dogfight_arena_fight_room_player.get_total_score(self)
    return self.total_score
end

function dogfight_arena_fight_room_player.set_leave_state(self,value)
    self.leave = value
end

function dogfight_arena_fight_room_player.get_leave_state(self)
    return self.leave
end

function dogfight_arena_fight_room_player.score_change(self,addon,actor_name)
    local player = online.get_user(self.actor_id)
    if player ~= nil then
        player:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{func_name="PlayerDogfigtFightScoreChange",result=0,addon=addon})
    end
    if addon > 0 then
        if actor_name == nil then
            player:send_system_message(const.SYSTEM_MESSAGE_ID.dogfight_score,nil,addon)
        else
            player:send_system_message(const.SYSTEM_MESSAGE_ID.dogfight_plundered_score,nil,actor_name,math.abs(addon))
        end
    elseif addon < 0 then
        player:send_system_message(const.SYSTEM_MESSAGE_ID.dogfight_plundered_score,nil,actor_name,math.abs(addon))
    end
end

function dogfight_arena_fight_room_player.set_arena_address(self,address)
    self.arena_address = address
end

return dogfight_arena_fight_room_player

