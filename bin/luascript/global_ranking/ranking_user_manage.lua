--------------------------------------------------------------------
-- 文件名:	ranking_user_manage.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/1/5
-- 描  述:	排行榜玩家管理
--------------------------------------------------------------------

local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local dungeon_hegemon = require "global_ranking/dungeon_hegemon"
local pet_rank = require "global_ranking/pet_rank"
local pet_generate = require "global_ranking/pet_generate"
local player_rank = require "global_ranking/player_rank"
local ranking_player = require "global_ranking/ranking_player"
local const = require "Common/constant"
local onlineuser = require "global_ranking/ranking_online_user"

local function _is_message_on_handle(key_action)
    if key_action == const.GR_MESSAGE_LUA_GAME_RPC then
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
        user = ranking_player()
        onlineuser.add_user(data.actor_id,user)
    end
    data.game_id = game_id
    user:on_message(key_action, data)
end

local function _server_start()
    dungeon_hegemon.on_server_start()
    pet_rank.on_server_start()
    pet_generate.on_server_start()
    player_rank.on_server_start()
end
register_function_on_start(_server_start)

local close_hash = {
    dungeon_hegemon = true,
    pet_rank = true,
    player_rank = true,
}

local function on_server_stop()
    flog("info", "ranking server on_server_stop")
    dungeon_hegemon.on_server_stop()
    pet_rank.on_server_stop()
    player_rank.on_server_stop()
end

function RankingUserManageReadyClose(module_name)
    flog("info", "RankingUserManageReadyClose "..module_name)
    close_hash[module_name] = nil
    if table.isEmptyOrNil(close_hash) then
        flog("info", "RankingUserManageReadyClose all ready")
        IsServerModuleReadyClose(const.SERVICE_TYPE.ranking_service)
    end
end

return {
    on_connect = on_connect,
    on_close = on_close,
    on_message = on_message,
    on_server_stop = on_server_stop,
}