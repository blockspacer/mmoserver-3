--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/5 0005
-- Time: 16:34
-- To change this template use File | Settings | File Templates.
--
local decode_client_data = require("basic/net").decode_client_data
local const = require "Common/constant"
line_center = require "global_line/line_center"
local line_center = line_center

--处理Game端断开
local function on_close(session_id)
end

local function on_message(key_action, data,src_game_id)
    if key_action ~= const.SL_MESSAGE_LUA_GAME_RPC then
        return
    end
    data = decode_client_data(data)
    if data.func_name == nil then
        return
    end
    line_center[data.func_name](src_game_id,data)
end

local function on_update_games_info(games_info)
    line_center.on_update_games_info(games_info)
end

return {
    on_message = on_message,
    on_close = on_close,
    on_update_games_info = on_update_games_info,
}