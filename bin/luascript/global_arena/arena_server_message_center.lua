--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/14 0014
-- Time: 10:42
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local arena_center = arena_center_instance

arena_server_message_center = arena_server_message_center or {}
local arena_server_message_center = arena_server_message_center

function arena_server_message_center:on_game_message(game_id,key_action,input)
    if input.func_name == nil then
        return
    end
    arena_center[input.func_name](arena_center,input,game_id)
end

return arena_server_message_center

