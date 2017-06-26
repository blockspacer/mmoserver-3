--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/17 0017
-- Time: 18:11
-- To change this template use File | Settings | File Templates.
--

local net_work = require "basic/net"
local send_to_client = net_work.send_to_client
local const = require "Common/constant"
local flog = require "basic/log"
local online_user = require "fight_server/fight_server_online_user"
local fight_avatar_connect_state = require "fight_server/fight_avatar_connect_state"
local table = table

fight_server_center = fight_server_center or {}
local fight_server_center = fight_server_center

local fights = {}
local actorid_sessionid = {}

function fight_server_center:add_fight(fight_id,token,fight_type,members)
    fights[fight_id] = {}
    fights[fight_id].token = token
    fights[fight_id].fight_type = fight_type
    fights[fight_id].members = table.copy(members)
end

function fight_server_center:remove_fight(fight_id)
    fights[fight_id] = nil
end

function fight_server_center:add_member(fight_id,actor_id)
    if fights[fight_id] ~= nil then
        table.insert(fights[fight_id].members,actor_id)
    end
end

function fight_server_center:on_connet_fight_server(session_id,input)
    if input.fight_id == nil or input.token == nil or input.actor_id == nil then
        return false
    end
    if fights[input.fight_id] == nil then
        flog("tmlDebug","not have fight!fight_id "..input.fight_id)
        return false
    end

    local data = {}
    data.result = 0
    data.func_name = "ConnetFightServerRet"
    local fight = fights[input.fight_id]
    if fight.token ~= input.token then
        data.result = const.error_fight_server_token_not_match
        send_to_client(session_id, const.DC_MESSAGE_LUA_GAME_RPC, data)
        return false
    end
    for i=1,#fight.members,1 do
        if fight.members[i] == input.actor_id then
            local connet = false
            local player = online_user.get_user(input.actor_id)
            if player ~= nil then
                connet = true
                if player.replace == nil or not player.replace then
                    player:set_client_session_id(session_id)
                    if fight.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
                        player:start_team_dungeon()
                    elseif fight.fight_type == const.FIGHT_SERVER_TYPE.MAIN_DUNGEON then
                        player:start_main_dungeon()
                    elseif fight.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
                        player:start_qualifying_arena()
                    elseif fight.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
                        player:start_dogfight_arena()
                    elseif fight.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
                        player:start_task_dungeon()
                    else
                        flog("tmlDebug","fight_server_center:on_connet_fight_server fight type error")
                    end
                    player:fight_send_to_game({func_name="on_client_connect_fight_server"})
                else
                    if session_id ~= player:get_client_session_id() then
                        clear_fight_avatar_reconnect_data(player:get_client_session_id(),true)
                         player:set_client_session_id(session_id)
                    else
                        clear_fight_avatar_reconnect_data(player:get_client_session_id(),false)
                    end
                    --player:reconnect(false)
                    if fight.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
                        player:on_connect_team_dungeon_server()
                    elseif fight.fight_type == const.FIGHT_SERVER_TYPE.MAIN_DUNGEON then
                        player:on_connect_main_dungeon_server()
                    elseif fight.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
                        player:on_connect_qualifying_arena_server()
                    elseif fight.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
                        player:on_connect_dogfight_arena_server()
                    elseif fight.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
                        player:on_connect_task_dungeon_server()
                    else
                        flog("tmlDebug","fight_server_center:on_connet_fight_server fight type error")
                    end
                end
            else
                flog("tmlDebug","fight_server_center:on_connet_fight_server player == nil")
            end
            if connet == false then
                flog("error","fight_server_center:on_connet_fight_server fight type error!")
            end
            send_to_client(session_id, const.DC_MESSAGE_LUA_GAME_RPC, data)
            player:set_connect_state(fight_avatar_connect_state.connect)
            return true
        end
    end
    data.result = const.error_is_not_fight_member
    send_to_client(session_id, const.DC_MESSAGE_LUA_GAME_RPC, data)
    return false
end

function fight_server_center:on_reconnet_fight_server(session_id,input)
    if input.fight_id == nil or input.token == nil or input.actor_id == nil then
        return false
    end

    local data = {}
    data.result = 0
    data.func_name = "ReconnetFightServerRet"

    if fights[input.fight_id] == nil then
        flog("tmlDebug","not have fight!fight_id "..input.fight_id)
        data.result = const.error_fight_server_token_not_match
        send_to_client(session_id, const.DC_MESSAGE_LUA_GAME_RPC, data)
        return false
    end

    local fight = fights[input.fight_id]
    if fight.token ~= input.token then
        data.result = const.error_fight_server_token_not_match
        send_to_client(session_id, const.DC_MESSAGE_LUA_GAME_RPC, data)
        return false
    end

    for i=1,#fight.members,1 do
        if fight.members[i] == input.actor_id then
            local player = online_user.get_user(input.actor_id)
            if player ~= nil then
                local connect_state = player:get_connect_state()
                if connect_state == nil then
                    data.result = const.error_fight_server_token_not_match
                    send_to_client(session_id, const.DC_MESSAGE_LUA_GAME_RPC, data)
                    return false
                end
                if session_id ~= player:get_client_session_id() then
                    clear_fight_avatar_reconnect_data(player:get_client_session_id(),true)
                     player:set_client_session_id(session_id)
                else
                    clear_fight_avatar_reconnect_data(player:get_client_session_id(),false)
                end
                player:set_connect_state(fight_avatar_connect_state.connect)
                player:reconnect(true)
                send_to_client(session_id, const.DC_MESSAGE_LUA_GAME_RPC, data)
            end
            return true
        end
    end
    data.result = const.error_is_not_fight_member
    send_to_client(session_id, const.DC_MESSAGE_LUA_GAME_RPC, data)
    return false
end

return fight_server_center