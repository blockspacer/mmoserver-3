--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/10/30
-- Time: 17:51
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"

local params = {
    present_friend_flower_count = {db=true,sync=true,default=0},
    receive_friend_flower_count = {db=true,sync=true,default=0}
}
local imp_friend = {}
imp_friend.__index = imp_friend

setmetatable(imp_friend, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_friend.__params = params

function imp_friend.__ctor(self)

end

local function on_get_friend(self,input,syn_data)
    input.func_name = "on_get_friend"
    self:send_message_to_friend_server(input)
end

local function on_search_friend(self,input,syn_data)
    input.func_name = "on_search_friend"
    self:send_message_to_friend_server(input)
end

local function on_apply_friend(self,input,syn_data)
    input.func_name = "on_apply_friend"
    input.apply_actor_id = input.actor_id
    self:send_message_to_friend_server(input)
end

local function on_accept_friend(self,input,syn_data)
    input.func_name = "on_accept_friend"
    self:send_message_to_friend_server(input)
end

local function on_delete_friend(self,input,syn_data)
    input.func_name = "on_delete_friend"
    input.delete_actor_id = input.actor_id
    self:send_message_to_friend_server(input)
end

local function on_add_blacklist(self,input,syn_data)
    input.func_name = "on_add_blacklist"
    input.blacklist_actor_id = input.actor_id
    self:send_message_to_friend_server(input)
end

local function on_delete_blacklist(self,input,syn_data)
    input.func_name = "on_delete_blacklist"
    input.delete_actor_id = input.actor_id
    self:send_message_to_friend_server(input)
end

local function on_add_enemy(self,input,syn_data)
    input.func_name = "on_add_enemy"
    input.enemy_actor_id = input.actor_id
    self:send_message_to_friend_server(input)
end

local function on_delete_enemy(self,input,syn_data)
    input.func_name = "on_delete_enemy"
    input.enemy_actor_id = input.actor_id
    self:send_message_to_friend_server(input)
end

local function on_friend_chat(self,input,syn_data)
    input.func_name = "on_friend_chat"
    input.chat_friend_id = input.actor_id
    self:send_message_to_friend_server(input)
end

function imp_friend.on_global_giving_gift(self,input,sync_data)
    self:remove_item_by_id(input.item_id,input.item_count)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="UseBagItemReply",gift_giving=true})
    self:imp_assets_write_to_sync_dict(sync_data)
    if input.flower_count ~= nil then
        self.present_friend_flower_count = self.present_friend_flower_count + input.flower_count
        self:update_player_value_to_rank_list("present_friend_flower_count")
    end
end

function imp_friend.on_global_receive_gift(self,input,sync_data)
    if input.flower_count ~= nil then
        self.receive_friend_flower_count = self.receive_friend_flower_count + input.flower_count
        self:update_player_value_to_rank_list("receive_friend_flower_count")
    end
end

function imp_friend.imp_friend_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    if self.receive_friend_flower_count ~= 0 then
        self:update_player_value_to_rank_list("receive_friend_flower_count")
    end
end

function imp_friend.imp_friend_init_from_other_game_dict(self,dict)
    self:imp_friend_init_from_dict(dict)
end

function imp_friend.imp_friend_write_to_dict(self, dict)
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
end

function imp_friend.imp_friend_write_to_other_game_dict(self,dict)
    self:imp_friend_write_to_dict(dict)
end

function imp_friend.imp_friend_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
end

register_message_handler(const.CS_MESSAGE_LUA_FRIEND_GET, on_get_friend)
register_message_handler(const.CS_MESSAGE_LUA_FRIEND_SEARCH, on_search_friend)
register_message_handler(const.CS_MESSAGE_LUA_FRIEND_APPLY,on_apply_friend)
register_message_handler(const.CS_MESSAGE_LUA_FRIEND_ACCEPT,on_accept_friend)
register_message_handler(const.CS_MESSAGE_LUA_FRIEND_DELETE,on_delete_friend)
register_message_handler(const.CS_MESSAGE_LUA_BLACKLIST_ADD,on_add_blacklist)
register_message_handler(const.CS_MESSAGE_LUA_BLACKLIST_DELETE,on_delete_blacklist)
register_message_handler(const.CS_MESSAGE_LUA_ENEMY_ADD,on_add_enemy)
register_message_handler(const.CS_MESSAGE_LUA_ENEMY_DELETE,on_delete_enemy)
register_message_handler(const.CS_MESSAGE_LUA_FRIEND_CHAT,on_friend_chat)

imp_friend.__message_handler = {}
imp_friend.__message_handler.on_get_friend = on_get_friend
imp_friend.__message_handler.on_search_friend = on_search_friend
imp_friend.__message_handler.on_apply_friend = on_apply_friend
imp_friend.__message_handler.on_accept_friend = on_accept_friend
imp_friend.__message_handler.on_delete_friend = on_delete_friend
imp_friend.__message_handler.on_add_blacklist = on_add_blacklist
imp_friend.__message_handler.on_delete_blacklist = on_delete_blacklist
imp_friend.__message_handler.on_add_enemy = on_add_enemy
imp_friend.__message_handler.on_delete_enemy = on_delete_enemy
imp_friend.__message_handler.on_friend_chat = on_friend_chat

return imp_friend