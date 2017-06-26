--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/21 0021
-- Time: 10:21
-- To change this template use File | Settings | File Templates.
--


require "entities/fight_avatar"
local fight_server_user = require "fight_server/fight_server_user"
local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local const = require "Common/constant"
team_dungeon_scene_manager = require "scene/team_dungeon_scene_manager"
team_dungeon_center = require "team_dungeon/team_dungeon_center"
main_dungeon_scene_manager = require "scene/main_dungeon_scene_manager"
main_dungeon_center = require "fight_server/main_dungeon_center"
arena_scene_manager = require "scene/arena_scene_manager"
task_dungeon_scene_manager = require "scene/task_dungeon_scene_manager"
task_dungeon_center = require "fight_server/task_dungeon_center"
local fight_server_message_center = require "fight_server/fight_server_message_center"
local fight_avatar_connect_state = require "fight_server/fight_avatar_connect_state"

local online_user = {}

--处理客户端连接
local function on_connect(session_id)
    local new_user = fight_server_user()
    if not new_user:init(session_id) then
        return
    end
    online_user[session_id] = new_user
end

--处理客户端断开
local function on_close(session_id)
    if online_user[session_id] ~= nil then
        online_user[session_id]:on_logout(session_id)
        online_user[session_id] = nil
    end
end

local function on_disconnect(session_id)
    flog("tmlDebug",string.format("fight avatar disconnect session_id %16.0f",session_id))
    if online_user[session_id] == nil then
        return
    end
    local user = online_user[session_id]
    local connect_state = user:get_fight_avatar_connect_state()
    if connect_state == nil then
        online_user[session_id] = nil
        return
    end

    local function delay_disconnect()
        on_close(session_id)
    end
    if connect_state == fight_avatar_connect_state.connect then
        --竞技场结束后断开可以离开
        if user:check_can_leave() then
            flog("tmlDebug","fight avatar can leave!")
            on_close(session_id)
            return
        end
        user:set_connect_state(fight_avatar_connect_state.offline,delay_disconnect)
    else
        if connect_state == fight_avatar_connect_state.over then
            user:notice_fight_avatar_leave_scene()
            on_close(session_id)
        elseif connect_state == fight_avatar_connect_state.done then
            on_close(session_id)
        else
            flog("warn","fight avatar disconnect,connect state "..connect_state)
        end
    end
end

--处理客户端发来的消息
local function on_message(session_id, key_action, data)
    if key_action == const.CD_MESSAGE_LUA_GAME_RPC then
        if online_user[session_id] == nil then
            on_connect(session_id)
        end
        if online_user[session_id] ~= nil then
            flog("tmlDebug", "fight_server_user_manager on_message key_action "..key_action)
            data = decode_client_data(data)
            online_user[session_id]:on_message(key_action, data)
        end
    end
end

local function on_game_message(game_id,key_action,data)
    if key_action ~= const.GD_MESSAGE_LUA_GAME_RPC then
        return
    end
    flog("tmlDebug", "fight_server_user_manager on_game_message from game:"..game_id..",key_action:"..key_action)
    data = decode_client_data(data)
    fight_server_message_center:on_game_message(game_id,key_action,data)
end

local function on_fight_server_close()
    for session_id,_ in pairs(online_user) do
        on_close(session_id)
    end
    _fight_ready_close()
end

function clear_fight_avatar_reconnect_data(session_id,clear)
    if online_user[session_id] ~= nil then
        online_user[session_id]:remove_delay_disconnect_timer()
    end
    if clear then
        online_user[session_id] = nil
    end
end

function avatar_notice_fight_avatar_close(session_id)
    on_close(session_id)
end

return {
    on_message = on_message,
    on_close = on_close,
    on_game_message=on_game_message,
    on_fight_server_close = on_fight_server_close,
    on_disconnect = on_disconnect,
}

