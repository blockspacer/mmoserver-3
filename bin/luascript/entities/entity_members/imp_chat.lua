--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/10 0010
-- Time: 13:57
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local system_friends_chat = require "data/system_friends_chat"
local onlinerole = require "onlinerole"
local flog = require "basic/log"

local CHAT_CHANNEL = const.CHAT_CHANNEL
local SYSTEM_MESSAGE_ID = const.SYSTEM_MESSAGE_ID
local CHAT_MESSAGE_TYPE = const.CHAT_MESSAGE_TYPE
local ChannelContent = system_friends_chat.ChannelContent
local SystemMessage = system_friends_chat.SystemMessage
local Parameter = system_friends_chat.Parameter
local system_friends_chat_config = require "configs/system_friends_chat_config"
local _get_now_time_second = _get_now_time_second
local tostring = tostring
local broadcast_message = require("basic/net").broadcast_message
local create_system_message_by_id = require("basic/scheme").create_system_message_by_id

local params = {}
local imp_chat = {}
imp_chat.__index = imp_chat

setmetatable(imp_chat, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_chat.__params = params

function imp_chat.__ctor(self)
    self.channel_talk_time = {}
    for i,v in pairs(ChannelContent) do
        self.channel_talk_time[i] = 0
    end
end

--被禁言了
local function is_ban(self)
    return false
end

local function broadcast_system_message(data)
    broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE,data)
end

local function broadcast_loudspeaker(data)
    broadcast_message(const.SC_MESSAGE_LUA_CHAT_BROADCAST,data)
end

local function broadcast_faction(self,data)
    self:send_message_to_friend_server({func_name="on_chat",channel=CHAT_CHANNEL.FactionChannel,data=data})
end

local function broadcast_union(self,data)
    self:send_message_to_faction_server({func_name="on_faction_member_chat",data=data,faction_id=self.faction_id})
end

local function broadcast_team(self,data)
    self:send_message_to_team_server({func_name="on_team_member_chat",data=data,team_id=self.team_id})
end

function imp_chat.send_system_message_by_id(self, message_id, attach, props, ...)
    local message_data, message = create_system_message_by_id(message_id, attach, ...)
    message_data.props = props
    if message.Notice == 1 then
        broadcast_system_message(message_data)
    else
        self:imp_chat_send_system_message(message_data)
    end
end

local function on_chat(self,input,syn_data)
    local result = 0
    if is_ban(self) then
        result = const.error_chat_ban
        self:send_message(const.SC_MESSAGE_LUA_CHAT,{result=result})
        return
    end

    if input.channel == nil or input.data == nil or input.channel == CHAT_CHANNEL.SystemChannel then
        return
    end

    local current_time = _get_now_time_second()
    if current_time - self.channel_talk_time[input.channel] < ChannelContent[input.channel].ChatInterval then
        result = const.error_chat_cd_not_enough
        self:send_message(const.SC_MESSAGE_LUA_CHAT,{result=result})
        return
    end

    if input.channel == CHAT_CHANNEL.UnionChannel and not self:is_have_faction() then
        result = const.error_no_union
        self:send_message(const.SC_MESSAGE_LUA_CHAT,{result=result})
        return
    end

    if input.channel == CHAT_CHANNEL.TeamChannel and not self:is_in_team() then
        result = const.error_no_team
        self:send_message(const.SC_MESSAGE_LUA_CHAT,{result=result})
        return
    end

    if ChannelContent[input.channel].OpenLevel > self:get("level") then
        result = const.error_level_not_enough
        self:send_message(const.SC_MESSAGE_LUA_CHAT,{result=result})
        return
    end

    local consum = false
    if ChannelContent[input.channel].Consumption ~= nil and ChannelContent[input.channel].Consumption[1] > 0 then
        if not self:is_enough_by_id(ChannelContent[input.channel].Consumption[1],ChannelContent[input.channel].Consumption[2]) then
            result = const.error_item_not_enough
            self:send_message(const.SC_MESSAGE_LUA_CHAT,{result=result})
            return
        else
            self:remove_item_by_id(ChannelContent[input.channel].Consumption[1],ChannelContent[input.channel].Consumption[2])
            consum = true
        end
    end

    local send_to_client_data = {}
    send_to_client_data.message_type = CHAT_MESSAGE_TYPE.NearbyMessage
    if input.channel == CHAT_CHANNEL.UnionChannel then
        send_to_client_data.message_type = CHAT_MESSAGE_TYPE.UnionMessage
    elseif input.channel == CHAT_CHANNEL.FactionChannel then
        send_to_client_data.message_type = CHAT_MESSAGE_TYPE.FactionMessage
    elseif input.channel == CHAT_CHANNEL.TeamChannel then
        send_to_client_data.message_type = CHAT_MESSAGE_TYPE.TeamMessage
    elseif input.channel == CHAT_CHANNEL.LoudspeakerChannel then
        send_to_client_data.message_type = CHAT_MESSAGE_TYPE.LoudspeakerMessage
    end
    send_to_client_data.actor_id = self:get("actor_id")
    send_to_client_data.actor_name = self:get("actor_name")
    send_to_client_data.sex = self:get("sex")
    send_to_client_data.vocation = self:get("vocation")
    send_to_client_data.level = self:get("level")
    send_to_client_data.country = self:get("country")
    send_to_client_data.time = current_time
    send_to_client_data.data = input.data
    if input.data ~= nil then
        send_to_client_data.attach = input.attach
    end

    self:send_message(const.SC_MESSAGE_LUA_CHAT,{result=result})
    if input.channel == CHAT_CHANNEL.LoudspeakerChannel then
        broadcast_loudspeaker(send_to_client_data)
    elseif input.channel == CHAT_CHANNEL.FactionChannel then
        broadcast_faction(self,send_to_client_data)
    elseif input.channel == CHAT_CHANNEL.UnionChannel then
        broadcast_union(self,send_to_client_data)
    elseif input.channel == CHAT_CHANNEL.TeamChannel then
        broadcast_team(self,send_to_client_data)
    elseif input.channel == CHAT_CHANNEL.NearbyChannel then
        if self.in_fight_server then
            self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_server_nearby_chat",send_to_client_data=send_to_client_data})
        else
            self:broadcast_nearby(send_to_client_data)
        end
    end

    if consum then
        self:imp_assets_write_to_sync_dict(syn_data)
    end
    self.channel_talk_time[input.channel] = current_time
end

function imp_chat.imp_chat_init_from_dict(self, dict)

end

function imp_chat.imp_chat_write_to_dict(self, dict)

end

function imp_chat.imp_chat_send_system_message(self,data)
    self:send_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE,data)
end

--获得物品广播
function imp_chat.imp_chat_broadcast_obtain_props(self,route,props)
    local message = system_friends_chat_config.get_system_message_config(SYSTEM_MESSAGE_ID.system_obtain_prop)
    if message == nil then
        return
    end

    local message_data = {}
    message_data.message_type = message.MessageType
    message_data.data = string.format(system_friends_chat_config.get_chat_content(SYSTEM_MESSAGE_ID.system_obtain_prop),self:get("actor_name"),route)
    message_data.time = _get_now_time_second()
    message_data.friend_chat_display = message.FriendChatDisplay
    message_data.attach = {}
    if message.Notice == 1 then
        broadcast_system_message(message_data)
    else
        self:imp_chat_send_system_message(message_data)
    end
end

function imp_chat.imp_chat_upgrade_level(self)
    self:send_system_message_by_id(SYSTEM_MESSAGE_ID.system_level_up, nil, nil, self:get("level"))
end

function imp_chat.arena_upgrade_grade_system_notice(self,notice_id,grade_name)
    self:send_system_message_by_id(notice_id, nil, nil, self:get("actor_name"), grade_name)
end

--排名前几通告
function imp_chat.arena_rank_up_system_notice(self,notice_id,rank)
    self:send_system_message_by_id(notice_id, nil, nil, self:get("actor_name"), tostring(rank))
end
--首次进入前十通告
function imp_chat.arena_rank_ten_system_notice(self,notice_id)
    self:send_system_message_by_id(notice_id, nil, nil, self:get("actor_name"))
end

function imp_chat.imp_chat_get_monster_exp(self, exp_count)
    self:send_system_message_by_id(SYSTEM_MESSAGE_ID.battle_get_exp, nil, nil, tostring(exp_count))
end

function imp_chat.imp_chat_send_gm_message(self, data_str, is_bradcast, is_scroll_board)
    local message = system_friends_chat_config.get_system_message_config(1001)
    if message == nil then
        return
    end

    local message_data = {}
    if is_scroll_board then
        message_data.message_type = 1
    else
        message_data.message_type = message.MessageType
    end
    message_data.data = data_str
    message_data.time = _get_now_time_second()
    message_data.friend_chat_display = message.FriendChatDisplay
    message_data.attach = {}
    if is_bradcast then
        broadcast_system_message(message_data)
    else
        self:imp_chat_send_system_message(message_data)
    end
end

function imp_chat.on_send_system_message(self, input)
    local message_id = input.message_id
    local attach = input.attach
    local props = input.props
    local params = input.params
    self:send_system_message_by_id(message_id, attach, props, unpack(params))
end

function imp_chat.on_team_member_chat(self,input)
    self:send_message(const.SC_MESSAGE_LUA_CHAT_BROADCAST,input.data)
end

function imp_chat.on_faction_member_chat(self,input)
    flog("tmlDebug","imp_chat.on_faction_member_chat")
    self:send_message(const.SC_MESSAGE_LUA_CHAT_BROADCAST,input.data)
end

function gm_broadcast_loudspeaker(notice_id, ...)
    local message_data = create_system_message_by_id(notice_id, {}, ...)
    broadcast_system_message(message_data)
    local message = system_friends_chat_config.get_system_message_config(notice_id)
    if message == nil then
        return
    end
    if table.isEmptyOrNil(message.Repeat) or #message.Repeat < 2 then
        return
    end
    game_manager.add_repeat_notice(message_data,message.Repeat[1],message.Repeat[2])
end

function gm_broadcast_self_define_message(data_str)
    local message_data = create_system_message_by_id(1011, {}, 0,0)
    message_data.data = data_str
    broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE,message_data)
    local message = system_friends_chat_config.get_system_message_config(1011)
    if message == nil then
        return
    end
    if table.isEmptyOrNil(message.Repeat) or #message.Repeat < 2 then
        return
    end
    game_manager.add_repeat_notice(message_data,message.Repeat[1],message.Repeat[2])
end

register_message_handler(const.CS_MESSAGE_LUA_CHAT,on_chat)

imp_chat.__message_handler = {}
imp_chat.__message_handler.on_chat = on_chat
return imp_chat

