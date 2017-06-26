--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/2 0002
-- Time: 16:33
-- To change this template use File | Settings | File Templates.
--

local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local const = require "Common/constant"
arena_center_instance = require "global_arena/arena_center"()
local arena_server_message_center = require "global_arena/arena_server_message_center"

local online_user = {}

local function _is_message_on_handle(key_action)
    if key_action == const.SA_MESSAGE_LUA_GAME_ARENA_RPC then
        return true
    end
    return false
end

--处理Game端连接
local function on_connect(session_id)
end

--处理Game端断开
local function on_close(session_id)
end

--处理Game端发来的消息
local function on_message(key_action, data,src_game_id)
    if not _is_message_on_handle(key_action) then
        return
    end

    data = decode_client_data(data)
    arena_server_message_center:on_game_message(src_game_id,key_action,data)
end

local function on_server_stop()
    flog("info","arena_user_manager.on_server_stop")
    arena_center_instance:on_server_stop()
end

function ArenaUserManageReadyClose()
    flog("info", "ArenaUserManageReadyClose")
    IsServerModuleReadyClose(const.SERVICE_TYPE.arena_service)
end

return {
    on_message = on_message,
    on_close = on_close,
    on_server_stop = on_server_stop,
}

