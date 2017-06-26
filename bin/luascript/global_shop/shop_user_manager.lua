--------------------------------------------------------------------
-- 文件名:	shop_user_manager.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/2/6
-- 描  述:	国家玩家管理
--------------------------------------------------------------------

local player = require "global_shop/shop_player"
local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local const = require "Common/constant"
local shop_all_server = require "global_shop/shop_all_server"
local wander_shop = require "global_shop/wander_shop"
local onlineuser = require "global_shop/shop_online_user"

local online_player = {}

local function _is_message_on_handle(key_action)
    if key_action == const.GS_MESSAGE_LUA_GAME_RPC then
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

local function _server_start()
    shop_all_server.on_server_start()
    wander_shop.on_server_start()
end
register_function_on_start(_server_start)

local function on_server_stop()
    flog("info", "shop server on_server_stop")
    shop_all_server.on_server_stop()
end

function ShopUserManageReadyClose()
    flog("info", "ShopUserManageReadyClose")
    IsServerModuleReadyClose(const.SERVICE_TYPE.shop_service)
end

return {
    on_connect = on_connect,
    on_close = on_close,
    on_message = on_message,
    on_server_stop = on_server_stop,
}