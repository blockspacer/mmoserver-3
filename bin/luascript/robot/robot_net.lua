--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/24 0024
-- Time: 10:39
-- To change this template use File | Settings | File Templates.
--

local msg_pack = require "basic/message_pack"
local msg_pack_pack = msg_pack.pack
local msg_pack_unpack = msg_pack.unpack
local flog = require "basic/log"
local table = table
local _robot_send_message_to_game = _robot_send_message_to_game
local string = string

local function send_message(robot_id,key_action,data)
    flog("debug", "send_to_game robot_id "..robot_id.." key_action "..key_action.." data: "..table.serialize(data))
    local buf = msg_pack_pack(data)
    _robot_send_message_to_game(robot_id,key_action,buf)
end

local function decode_message(msg_str)
    if msg_str == nil then
        return nil
    end

    local decode_func = function ()
        return msg_pack_unpack(msg_str)
    end
    local err_handler = function ()
        local len = string.len(msg_str)
        flog("error", "decode fail : len is "..len.."  message is "..table.serialize(msg_str))
    end
    local ret, message = xpcall(decode_func, err_handler)

    if ret then
        flog("debug", "decode success : "..table.serialize(message))
    else
        --flog("error", "decode error : len is "..string_len(message).."  message is "..table_serialize(message))
        return nil
    end

    return message
end

return{
    send_message = send_message,
    decode_message = decode_message,
}

