--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/15 0015
-- Time: 11:14
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local data_base = require "basic/db_mongo"
local online = require "global/global_online_user"
local global_avatar = require "global/global_avatar"
local _get_now_time_second = _get_now_time_second

local global_login_user = {}
global_login_user.__index = global_login_user

setmetatable(global_login_user, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function global_login_user.__ctor(self)
    self.session_id = nil
    self.actor_id = nil
end

function global_login_user.init(self, session_id)
    self.session_id = session_id
    return true
end

local function _db_callback_get_global_player(self, status, playerdata,callback_id)
    flog("info", "_db_callback_get_global_player:"..self.actor_id)
    if playerdata == nil then
        playerdata = {}
    end
    playerdata.actor_id = self.actor_id

    local avatar = global_avatar()
    if avatar ==  nil then
        flog("error", "Failed create player " .. self.actor_id)
        return
    end
    playerdata.session_id = self.session_id
    playerdata.src_game_id = self.src_game_id
    if avatar:init(playerdata) == false then
        flog("error", "Failed init global avatar")
        return
    end
    online.update_player_offlinetime(self.actor_id,0)
    online.add_user(self.actor_id, avatar)
    avatar:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_global_init_complete"})
end

function global_login_user.on_message(self,src_game_id, key_action, input)
    if input.func_name == nil then
        flog("info","global_login_user on_message func_name is nil!!!")
        return
    end
    if input.func_name == "on_add_friend_player" then
        self.actor_id = input.actor_id
        self.session_id = tonumber(input.session_id)
        flog("info", "add global avatar session_id:"..self.session_id..",game_id:"..src_game_id..",actor_id:"..input.actor_id)
        local avatar = online.get_user(self.actor_id)
        if avatar == nil then
            flog("info", "query global player,actor_id:"..self.actor_id)
            self.src_game_id = src_game_id
            data_base.db_find_one(self, _db_callback_get_global_player, "global_player", {actor_id = self.actor_id}, {})
        else
            flog("warn", "global avatar is exist,actor_id:"..input.actor_id)
            avatar:_set("src_game_id",src_game_id)
            avatar:_set("session_id",self.session_id)
            avatar:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_global_init_complete"})
        end
        return
    end

    local actor_id = self.actor_id
    if actor_id == nil then
        flog("error", "global_login_user|on_message : actor id is nil")
    end
    local avatar = online.get_user(actor_id)
    if avatar == nil then
        flog("warn", "global_login_user|on_message: avatar is nil")
        return
    end
    flog("tmlDebug", "global_login_user|on_message actor_id "..actor_id)
    return avatar[input.func_name](avatar,input)
end

function global_login_user.on_logout(self, session_id)
    local actor_id = self.actor_id
    if actor_id == nil then
        flog("info", "global_login_user|on_logout : actor id is nil")
        return
    end
    local avatar = online.get_user(actor_id)
    if avatar == nil then
        flog("info", " global_login_user|on_logout Failed get user actor_id: "..actor_id)
        return
    end

    online.del_user(actor_id)
    online.update_player_offlinetime(actor_id,_get_now_time_second())

    --save data
    avatar:on_logout()
end

return global_login_user

