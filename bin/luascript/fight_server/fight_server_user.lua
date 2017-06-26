--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/21 0021
-- Time: 10:44
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local online_user = require "fight_server/fight_server_online_user"
local flog = require "basic/log"
local fight_server_center = require "fight_server/fight_server_center"
local fight_avatar_connect_state = require "fight_server/fight_avatar_connect_state"
local timer = require "basic/timer"

local fight_server_user = {}
fight_server_user.__index = fight_server_user

setmetatable(fight_server_user, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function fight_server_user.__ctor(self)
    self.session_id = nil
    self.actor_id  = nil
    self.delay_disconnect_timer = nil
end

function fight_server_user.init(self, session_id)
    self.session_id = session_id
    return true
end

function fight_server_user.on_message(self, key_action, input)
    if key_action == const.CD_MESSAGE_LUA_GAME_RPC then
        if input.func_name ~= nil then
            if input.func_name == "on_connet_fight_server" then
                local result = fight_server_center:on_connet_fight_server(self.session_id,input)
                if result == true then
                    self.actor_id = input.actor_id
                end
            elseif input.func_name == "on_reconnet_fight_server" then
                local result = fight_server_center:on_reconnet_fight_server(self.session_id,input)
                if result == true then
                    self.actor_id = input.actor_id
                end
            else
                local fight_avatar = online_user.get_user(self.actor_id)
                if fight_avatar == nil then
                    flog("info","can not find fight avatar in fight server!!!")
                    return
                end
                fight_avatar:on_message(key_action,input)
            end
        end
    end
end

function fight_server_user.on_logout(self,session_id)
    flog("tmlDebug","fight_server_user.on_logout")
    local player = online_user.get_user(self.actor_id)
    if player == nil then
        flog("tmlDebug","player already leave,actor_id:"..self.actor_id)
        return
    end
    online_user.del_user(self.actor_id)
    local connect_state = player:get_connect_state()
    if connect_state == fight_avatar_connect_state.done then
        return
    end
    player:on_player_logout()
    player:on_fight_server_disconnet()
    self:remove_delay_disconnect_time()
end

function fight_server_user.get_fight_avatar_connect_state(self)
    flog("tmlDebug","fight_server_user.get_fight_avatar_connect_state")
    local avatar = online_user.get_user(self.actor_id)
    if avatar == nil then
        return nil
    end
    return avatar:get_connect_state()
end

function fight_server_user.notice_fight_avatar_leave_scene(self)
    flog("tmlDebug","fight_server_user.notice_fight_avatar_leave_scene")
    local avatar = online_user.get_user(self.actor_id)
    if avatar == nil then
        flog("tmlDebug","fight_server_user.notice_fight_avatar_leave_scene avatar == nil actor_id "..self.actor_id)
        return nil
    end
    avatar:fight_send_to_game({func_name="on_fight_avatar_leave_scene"})
    avatar:set_connect_state(fight_avatar_connect_state.done)
    avatar:on_logout()
end

function fight_server_user.remove_delay_disconnect_timer(self)
    if self.delay_disconnect_timer ~= nil then
        timer.destroy_timer(self.delay_disconnect_timer)
        self.delay_disconnect_timer = nil
    end
end

function fight_server_user.set_connect_state(self,value,delay_disconnect)
    flog("tmlDebug","fight_server_user.set_connect_state")
    local avatar = online_user.get_user(self.actor_id)
    if avatar == nil then
        return nil
    end
    avatar:set_connect_state(value)
    self:remove_delay_disconnect_timer()
    self.delay_disconnect_timer = timer.create_timer(delay_disconnect,const.CLOSE_SESSION_DELAY_TIME,0)
end

function fight_server_user.check_can_leave(self)
    flog("tmlDebug","fight_server_user.check_can_close")
    local avatar = online_user.get_user(self.actor_id)
    if avatar == nil then
        return false
    end
    return avatar:check_can_leave()
end

return fight_server_user



