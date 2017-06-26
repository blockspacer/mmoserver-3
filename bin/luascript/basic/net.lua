--------------------------------------------------------------------
-- 文件名:	net.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/09
-- 描  述:	收发网络消息
--------------------------------------------------------------------
local msg_pack = require "basic/message_pack"

--MSG_LOGIN_ACTIONID
local flog = require "basic/log"
local _send_to_client = _send_to_client
local _forward_message_to_global = _forward_message_to_global
local _forward_message_to_game = _forward_message_to_game
local _broadcast_message = _broadcast_message
local _broadcast_to_aoi = _broadcast_to_aoi
local _get_serverid = _get_serverid
local table_serialize = table.serialize
local xpcall = xpcall
local string_len = string.len
local msg_pack_pack = msg_pack.pack
local msg_pack_unpack = msg_pack.unpack
local _send_message_to_fight = _send_to_fight
local _send_to_game = _send_to_game
local _broadcast_message_to_all_game = _broadcast_message_to_all_game
local _register_service = _register_service

local all_games_id = {}

local function send_to_client(session_id, key_action, msg_data)
    if session_id == nil then
        flog("error", "send_to_client: session_id can not be nil")
        return
    end
    flog("debug", "send_to_client "..string.format("%16.0f",session_id).." key_action "..key_action.." data: "..table_serialize(msg_data))
    local buf = msg_pack_pack(msg_data)
    flog("tmlDebug", "after msg pack pack!!!")
    _send_to_client(session_id, key_action, buf)
end

local function forward_message_to_global(session_id,key_action,msg_data)
    if session_id == nil then
        flog("error", "forward_message_to_global: session_id can not be nil")
        return
    end
    local buf = msg_pack_pack(msg_data)
    flog("info", "forward_message_to_global "..session_id.." key_action "..key_action.." data: "..table_serialize(msg_data))
    _forward_message_to_global(session_id, key_action, buf)
end

local function forward_message_to_game(dst_game_id,key_action, msg_data)
    local buf = msg_pack_pack(msg_data)
    flog("debug", "forward_message_to_game dst_game_id "..dst_game_id.." key_action "..key_action.." data: "..table_serialize(msg_data))
    _forward_message_to_game( dst_game_id,key_action, buf)
end

local function send_message_to_fight(dst_game_id,key_action,msg_data)
    local buf = msg_pack_pack(msg_data)
    flog("debug", "send_message_to_fight ".." key_action "..key_action.." data: "..table_serialize(msg_data))
    _send_message_to_fight(dst_game_id,key_action, buf)
end

local function fight_send_to_game(game_id,key_action,msg_data)
    local buf = msg_pack_pack(msg_data)
    flog("debug", "_send_to_game ".." key_action "..key_action.." data: "..table_serialize(msg_data))
    _send_to_game(game_id,key_action, buf)
end

local function decode_client_data(msg_str)
    if msg_str == nil then
        return nil
    end
    --[[flog("syzDebug", "decode_client_data  len: "..string_len(msg_str))
    for i = 1, string_len(msg_str) do
        flog("syzDebug", string.byte(msg_str, i))
    end]]

    local decode_func = function ()
        return msg_pack_unpack(msg_str)
    end
    local err_handler = function ()
        --flog("error", "err")
        local len = string_len(msg_str)
        flog("error", "decode fail : len is "..len.."  message is "..table_serialize(msg_str))
    end
    local ret, message = xpcall(decode_func, err_handler)

    if ret then
        flog("debug", "decode success : "..table_serialize(message))
    else
        --flog("error", "decode error : len is "..string_len(message).."  message is "..table_serialize(message))
        return nil
    end

    return message
end

local function broadcast_message(key_action, msg_data, country)
    country = country or 0
    local buf = msg_pack_pack(msg_data)
    flog("debug", "broadcast_message ".." key_action "..key_action.." data: "..table_serialize(msg_data))
    _broadcast_message( key_action, buf, country)
end

local function broadcast_message_to_all_game(key_action, msg_data)
    local buf = msg_pack_pack(msg_data)
    flog("debug", "_broadcast_message_to_all_game ".." key_action "..key_action.." data: "..table_serialize(msg_data))
    --_broadcast_message_to_all_game( key_action, buf)

    for _, v in pairs(all_games_id) do
         _forward_message_to_game( v.gameid ,key_action, buf)
    end
end

local function broadcast_to_aoi(proxyid,key_action,msg_data,if_include_self)
    if proxyid == 0 then
        assert(false)
    end
    local buf = msg_pack_pack(msg_data)
    flog("debug", "broadcast_message ".." key_action "..key_action.." data: "..table_serialize(msg_data))
    _broadcast_to_aoi(proxyid,key_action,buf,if_include_self)
end

local function get_serverid()
    return _get_serverid()
end

local function register_service(service_type)
    _info("register_service service_type:"..service_type)
    _register_service(service_type)
end

local function regist_all_games_id(gameservers)
    all_games_id = gameservers
end

return {
    send_to_client = send_to_client,
    decode_client_data = decode_client_data,
    forward_message_to_global = forward_message_to_global,
    forward_message_to_game = forward_message_to_game,
    broadcast_message = broadcast_message,
    broadcast_to_aoi = broadcast_to_aoi,
    get_serverid = get_serverid,
    send_message_to_fight = send_message_to_fight,
    fight_send_to_game = fight_send_to_game,
    broadcast_message_to_all_game = broadcast_message_to_all_game,
    register_service = register_service,
    regist_all_games_id = regist_all_games_id,
}