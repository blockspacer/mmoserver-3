--------------------------------------------------------------------
-- 文件名:	country_user_manage.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/9
-- 描  述:	国家玩家管理
--------------------------------------------------------------------

local player = require "global_country/country_player"
local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local country_donation = require "global_country/country_donation"
local const = require "Common/constant"
local onlinerole = require "global_country/country_online_user"
local country_war = require "global_country/country_war"
local country_election = require "global_country/country_election"

local function _is_message_on_handle(key_action)
    if key_action == const.GC_MESSAGE_LUA_GAME_RPC then
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
local function on_message(key_action, data, game_id)
    if not _is_message_on_handle(key_action) then
        return
    end

    flog("info", "on_message: key_action "..key_action)
    data = decode_client_data(data)
    local user = onlinerole.get_user(data.actor_id)
    if user == nil then
        user = player()
        onlinerole.add_user(data.actor_id,user)
    end
    data.game_id = game_id
    user:on_message(key_action, data)
end

local function _server_start()
    country_donation.on_server_start()
    country_war.on_server_start()
    country_election.on_server_start()
end
register_function_on_start(_server_start)

local function on_server_stop()
    flog("info", "country on_server_stop")
    country_donation.on_server_stop()
    country_election.on_server_stop()
end

local close_hash = {
    country_donation = true,
    country_election = true,
}

function CountryUserManageReadyClose(module_name)
    flog("info", "CountryUserManageReadyClose "..module_name)
    close_hash[module_name] = nil
    if table.isEmptyOrNil(close_hash) then
        flog("info", "CountryUserManageReadyClose all ready")
        IsServerModuleReadyClose(const.SERVICE_TYPE.country_service)
    end
end

return {
    on_connect = on_connect,
    on_close = on_close,
    on_message = on_message,
    on_server_stop = on_server_stop,
}