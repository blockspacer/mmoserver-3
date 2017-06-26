--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/4/26 0026
-- Time: 14:31
-- To change this template use File | Settings | File Templates.
--

local decode_client_data = require("basic/net").decode_client_data
local const = require "Common/constant"
local cross_server_arena_message_center = require "global_arena/cross_server_arena_message_center"
cross_server_arena_matching_center = require "global_arena/cross_server_arena_matching_center"

local function _is_message_on_handle(key_action)
    if key_action == const.GCA_MESSAGE_LUA_GAME_RPC then
        return true
    end
    return false
end

local function on_close(session_id)
end

--处理Game端发来的消息
local function on_message(key_action, data,src_game_id)
    if not _is_message_on_handle(key_action) then
        return
    end

    data = decode_client_data(data)
    cross_server_arena_message_center.on_message(src_game_id,key_action, data)
end

local function _server_start()
    cross_server_arena_matching_center.on_server_start()
end

register_function_on_start(_server_start)

return {
    on_message = on_message,
    on_close = on_close,
}



