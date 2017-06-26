--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/14 0014
-- Time: 10:42
-- To change this template use File | Settings | File Templates.
--

local cross_server_arena_matching_center = require "global_arena/cross_server_arena_matching_center"

local function on_message(game_id,key_action,input)
    if input.func_name ~= nil then
        if cross_server_arena_matching_center[input.func_name] ~= nil then
            cross_server_arena_matching_center[input.func_name](input,game_id)
        end
    end
end

return {
    on_message = on_message,
}
