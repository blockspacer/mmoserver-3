--------------------------------------------------------------------
-- 文件名:	user_manage.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/2
-- 描  述:	玩家登录管理
--------------------------------------------------------------------

local login_user = require "login_server/login_user"
local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local const = require "Common/constant"
normal_scene_manager = require "scene/normal_scene_manager"
local game_server_message_center = require "login_server/game_server_message_center"
local _avatar_change_game = _avatar_change_game
local net_work = require "basic/net"
local send_to_client = net_work.send_to_client

local online_user = {}
local changing_session = {}

local is_prepare_shutdown = false

local function is_ready_close()
    if is_prepare_shutdown and table.isEmptyOrNil(online_user) then
        OnGameServerReadyClose()
    end
end

--处理新客户端连接
local function on_connect(session_id)
    local new_user = login_user()
    if not new_user:init(session_id) then
        return
    end
    new_user:goto_state("login")
    online_user[session_id] = new_user
end


--处理客户端断开
local function on_close(session_id)
    local is_clear = true
    if online_user[session_id] ~= nil then
        local function clean_user_data()
            if online_user[session_id] ~= nil then
                online_user[session_id]:on_clear_data(session_id)
                online_user[session_id] = nil
            end
            is_ready_close()
        end

        is_clear = online_user[session_id]:on_logout(session_id, clean_user_data)
        if is_clear then
            clean_user_data()
        end
    end
    is_ready_close()
end

local function on_player_disconnect(session_id, callback)
    if online_user[session_id] ~= nil then
        online_user[session_id]:on_disconnect(session_id, callback)
    end
end


--处理客户端发来的消息
local function on_message(session_id, key_action, data, game_id)
    --邮件中心模块
    if key_action == const.OM_MESSAGE_LUA_GAME_RPC then
        return
    end

    if key_action == const.SG_MESSAGE_GAME_RPC_TRANSPORT then
        return
    end

    if key_action == const.SG_MESSAGE_CLIENT_RPC_TRANSPORT then
        return
    end

    if key_action == const.GS_MESSAGE_LUA_GAME_RPC then
        return
    end

    if key_action == const.GT_MESSAGE_LUA_GAME_RPC then
        return
    end

    if key_action == const.GR_MESSAGE_LUA_GAME_RPC then
        return
    end

    if key_action == const.GF_MESSAGE_LUA_GAME_RPC then
        return
    end

    if key_action == const.GG_MESSAGE_LUA_GAME_RPC then
        return
    end

    --已转移到其他进程
    if changing_session[session_id] then
        flog("warn","player already change to other game!key_action "..key_action)
        return
    end

    if online_user[session_id] == nil then
        on_connect(session_id)
    end

    if online_user[session_id] ~= nil then
        flog("syzDebug", "on_message: key_action "..key_action)
        data = decode_client_data(data)
        --data.game_id = game_id
        online_user[session_id]:on_message(key_action, data)
    end
end

local function on_player_change_game_line(input)

    local session_id = tonumber(input.login_user_data.session_id)
    changing_session[session_id] = nil
    _avatar_change_game(session_id)
    if online_user[session_id] == nil then
        on_connect(session_id)
    end
    online_user[session_id]:init_from_dict(input.login_user_data)
    online_user[session_id]:init_actor_data(input.actor_data,input.operation)
end

local function on_fight_server_message(game_id,key_action,data)
    if key_action ~= const.OG_MESSAGE_LUA_GAME_RPC then
        return
    end
    flog("tmlDebug", "user_manage on_fight_server_message from game:"..game_id..",key_action:"..key_action)
    data = decode_client_data(data)
    if data.func_name == "on_player_change_game_line" then
        on_player_change_game_line(data)
    else
        game_server_message_center:on_fight_server_message(game_id,key_action,data)
    end
end

local function kick_player_on_gate(gate_server_id)
    for session_id, player in pairs(online_user) do
        local player_gate_id = _urshift(session_id, 16)
        player_gate_id = _and(player_gate_id, 65535)
        if player_gate_id == gate_server_id then
            on_close(session_id)
        end
    end
end

local function on_server_stop()
    is_prepare_shutdown = true
    is_ready_close()
end

local function on_session_changed(data)
    local old_session = tonumber(data.old_session)
    local new_session = tonumber(data.new_session)
    local change_type = data.type
    local device_id = data.device_id

    local user = online_user[old_session]
    if user ~= nil then
        if change_type == "replace" then
            flog("info", "replace_session "..tostring(user.actor_id))
            online_user[old_session] = nil
            online_user[new_session] = user
            user:init(new_session)
            user:goto_state("actor")
            _avatar_change_game(new_session)
        else
            flog("info", "reconnect session "..tostring(user.actor_id))
            if user.device_id == device_id then
                online_user[old_session] = nil
                online_user[new_session] = user
                user:init(new_session)
                user.enter_playing_type = change_type
                user:goto_state("playing")
                send_to_client(new_session, const.SC_MESSAGE_LOGIN_CLIENT_RECONNECT, {result = 0})
                _avatar_change_game(new_session)
            else
                send_to_client(new_session, const.SC_MESSAGE_LOGIN_CLIENT_RECONNECT, {result = const.error_device_id_changed})
            end
        end
        _kickoffline(old_session)
    else
        _kickoffline(new_session)
    end
end
register_server_message_handler(const.OG_CHANGE_USER_SESSION_ID, on_session_changed)

local function get_login_user_data(session_id)
    if online_user[session_id] == nil then
        return nil
    end
    local dict = {}
    online_user[session_id]:write_to_dict(dict)
    return dict
end

local function start_change_game_line(session_id)
    changing_session[session_id] = true
    --清除数据
    if online_user[session_id] == nil then
        return
    end
    online_user[session_id]:start_change_game_line()
    online_user[session_id] = nil
end

return {
    on_connect = on_connect,
    on_close = on_close,
    on_message = on_message,
    on_fight_server_message = on_fight_server_message,
    kick_player_on_gate = kick_player_on_gate,
    on_server_stop = on_server_stop,
    get_login_user_data = get_login_user_data,
    start_change_game_line = start_change_game_line,
    on_player_disconnect = on_player_disconnect,
    on_session_changed = on_session_changed,
}