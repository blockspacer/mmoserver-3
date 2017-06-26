--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/14 0014
-- Time: 18:15
-- To change this template use File | Settings | File Templates.
--

local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local const = require "Common/constant"
global_server_message_center = require "global/global_server_message_center"
local global_server_message_center = global_server_message_center

--处理Game端连接
local function on_connect(session_id)

end

--处理Game端断开
local function on_close(session_id)
end

--处理Game端发来的消息
local function on_message(key_action, data,src_game_id)
    if key_action ~= const.GG_MESSAGE_LUA_GAME_RPC and key_action ~= const.SG_MESSAGE_GAME_RPC_TRANSPORT and key_action ~= const.SG_MESSAGE_CLIENT_RPC_TRANSPORT then
        return
    end

    data = decode_client_data(data)
    global_server_message_center.on_message(key_action, data,src_game_id)
end

local function on_server_stop()
    flog("info", "friend server on_server_stop")
    global_server_message_center.on_server_stop()
end

function FriendUserManageReadyClose()
    flog("info", "FriendUserManageReadyClose")
    IsServerModuleReadyClose(const.SERVICE_TYPE.friend_service)
end

return {
    on_message = on_message,
    on_close = on_close,
    on_server_stop = on_server_stop,
}

