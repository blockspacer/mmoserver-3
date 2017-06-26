--------------------------------------------------------------------
-- 文件名:	faction_user_manage.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/2/17
-- 描  述:	帮会玩家管理
--------------------------------------------------------------------

local player = require "global_faction/faction_player"
local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local const = require "Common/constant"
local faction_factory = require "global_faction/faction_factory"
local onlinerole = require "global_faction/faction_online_user"

local online_player = {}

local function _is_message_on_handle(key_action)
    if key_action == const.GF_MESSAGE_LUA_GAME_RPC then
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
    if data.actor_id == nil or data.actor_id == 0 then
        if faction_factory[data.func_name] ~= nil then
            faction_factory[data.func_name](data)
        end
    else
        local user = onlinerole.get_user(data.actor_id)
        if user == nil then
            user = player()
            onlinerole.add_user(data.actor_id,user)
        end
        data.game_id = game_id
        user:on_message(key_action, data)
    end
end

local function _server_start()
    faction_factory.on_server_start()
end
register_function_on_start(_server_start)

local function on_server_stop()
    flog("info", "faction server on_server_stop")
    faction_factory.on_server_stop()
end

function FactionUserManageReadyClose()
    flog("info", "FactionUserManageReadyClose")
    IsServerModuleReadyClose(const.SERVICE_TYPE.faction_service)
end

local function on_update_games_info(games_info)
    faction_factory.on_update_games_info(games_info)
end

return {
    on_connect = on_connect,
    on_close = on_close,
    on_message = on_message,
    on_server_stop = on_server_stop,
    on_update_games_info = on_update_games_info,
}