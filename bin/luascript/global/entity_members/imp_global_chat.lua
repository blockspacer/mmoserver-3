--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/16 0016
-- Time: 9:25
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local onlinerole = require "global/global_online_user"
local flog = require "basic/log"

local CHAT_CHANNEL = const.CHAT_CHANNEL

local params = {}
local imp_global_chat = {}
imp_global_chat.__index = imp_global_chat

setmetatable(imp_global_chat, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_global_chat.__params = params

function imp_global_chat.__ctor(self)

end

local function broadcast_all(data)
    local all_user = onlinerole.get_all_user()
    for _,v in pairs(all_user) do
        v:send_message_to_client(const.SC_MESSAGE_LUA_CHAT_BROADCAST,data)
    end
end

local function broadcast_faction(self,data)
    local self_country = self:get("country")
    local all_user = onlinerole.get_all_user()
    for _,v in pairs(all_user) do
        if self_country == v:get("country") then
            v:send_message_to_client(const.SC_MESSAGE_LUA_CHAT_BROADCAST,data)
        end
    end
end

local function broadcast_union(self,data)
    local all_user = onlinerole.get_all_user()
    for _,v in pairs(all_user) do
        v:send_message_to_client(const.SC_MESSAGE_LUA_CHAT_BROADCAST,data)
    end
end

function imp_global_chat.on_chat(self,input,syn_data)
    if input.channel == CHAT_CHANNEL.LoudspeakerChannel then
        broadcast_all(input.data)
    elseif input.channel == CHAT_CHANNEL.FactionChannel then
        broadcast_faction(self,input.data)
    elseif input.channel == CHAT_CHANNEL.UnionChannel then
        broadcast_union(self,input.data)
    end
end

function imp_global_chat.imp_global_chat_send_system_message(self,data)
    self:send_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE,data)
end

return imp_global_chat

