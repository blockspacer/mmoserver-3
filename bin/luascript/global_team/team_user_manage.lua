--------------------------------------------------------------------
-- 文件名:	team_user_manage.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/2
-- 描  述:	组队玩家管理
--------------------------------------------------------------------

local player = require "global_team/team_player"
local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local const = require "Common/constant"
local onlineuser = require "global_team/team_online_user"

local function _is_message_on_handle(key_action)
    if key_action == const.GT_MESSAGE_LUA_GAME_RPC then
        return true
    end
    return false
end

--处理新客户端连接
local function on_connect(session_id)

end

--处理客户端断开
local function on_close(session_id)
end

--处理game发来的消息
local function on_message( key_action, data, game_id)
    if not _is_message_on_handle(key_action) then
        return
    end

    flog("info", "on_message: key_action "..key_action)
    data = decode_client_data(data)
    local user = onlineuser.get_user(data.actor_id)
    if user == nil then
        user = player()
        onlineuser.add_user(data.actor_id,user)
    end
    data.game_id = game_id
    user:on_message(key_action, data)
end

return {
    on_connect = on_connect,
    on_close = on_close,
    on_message = on_message,
}