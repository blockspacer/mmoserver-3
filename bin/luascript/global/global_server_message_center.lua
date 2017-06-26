--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/1 0001
-- Time: 9:18
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local onlinerole = require "global/global_online_user"
local send_to_game = require("basic/net").forward_message_to_game
local send_to_client = require("basic/net").send_to_client
local flog = require "basic/log"
local global_login_user = require "global/global_login_user"

local online_user = {}
local server_stop = false

local function on_game_rpc_transport(input)
    flog("tmlDebug","global_server_message_center on_game_rpc_transport")
    local avatar = onlinerole.get_user(input.actor_id)
    if avatar ~= nil then
        send_to_game(avatar.src_game_id, const.OG_MESSAGE_LUA_GAME_RPC, input)
    end
end

local function on_client_rpc_transport(input)
    flog("tmlDebug","global_server_message_center on_client_rpc_transport")
    local avatar = onlinerole.get_user(input.actor_id)
    if avatar ~= nil then
        send_to_client(avatar.session_id, const.SC_MESSAGE_LUA_GAME_RPC, input)
    end
end

local function on_message(key_action, data,src_game_id)
    flog("tmlDebug","global_server_message_center on_message:"..key_action)
    if key_action == const.SG_MESSAGE_GAME_RPC_TRANSPORT then
        on_game_rpc_transport(data)
    elseif key_action == const.SG_MESSAGE_CLIENT_RPC_TRANSPORT then
        on_client_rpc_transport(data)
    elseif key_action == const.GG_MESSAGE_LUA_GAME_RPC then
        if data.actor_id == nil then
        else
            if online_user[data.actor_id] == nil then
                if data.func_name == "on_add_friend_player" then
                    online_user[data.actor_id] = global_login_user()
                else
                    flog("warn","can not find friend player,func_name "..data.func_name)
                    return
                end
            end
            online_user[data.actor_id]:on_message(src_game_id,key_action,data)
        end
    end
end

local function check_close()
    if server_stop and table.isEmptyOrNil(online_user) then
        FriendUserManageReadyClose()
    end
end

local function del_user(actor_id)
    flog("tmlDebug","global_server_message_center del_user actor_id "..actor_id)
    online_user[actor_id] = nil
    check_close()
end

local function on_server_stop()
    server_stop = true
    for actor_id,_ in pairs(online_user) do
        local friend_player = onlinerole.get_user(actor_id)
        if friend_player ~= nil then
            friend_player:on_friend_player_logout({actor_id=actor_id})
        else
            flog("warn","can not find player!actor_id "..actor_id)
            online_user[actor_id] = nil
        end
    end
    check_close()
end

return {
    on_message = on_message,
    del_user = del_user,
    on_server_stop = on_server_stop,
}