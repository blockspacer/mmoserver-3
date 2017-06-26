--------------------------------------------------------------------
-- 文件名:	command_cd.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/1/4 0004
-- 描  述:	指令cd时间
--------------------------------------------------------------------
local const = require "Common/constant"
local last_command_time = {}


local function is_command_cool_down(actor_id, command_name, cd_time)
    local current_time = _get_now_time_second()
    last_command_time[actor_id] = last_command_time[actor_id] or {}
    local last_time = last_command_time[actor_id][command_name]
    if last_time ~= nil then
        local expire_time =  last_time + cd_time
        if current_time < expire_time then
            return const.error_command_not_cool_down, expire_time
        end
    end

    last_command_time[actor_id][command_name] = current_time
    return 0
end

local function clear_cool_down_time(actor_id, command_name)
    last_command_time[actor_id] = last_command_time[actor_id] or {}
    last_command_time[actor_id][command_name] = nil
end

local function get_cool_down_expire_time(actor_id, command_name, cd_time)
    last_command_time[actor_id] = last_command_time[actor_id] or {}
    local last_time = last_command_time[actor_id][command_name] or 0
    return last_time + cd_time
end

return {
    is_command_cool_down = is_command_cool_down,
    clear_cool_down_time = clear_cool_down_time,
    get_cool_down_expire_time = get_cool_down_expire_time,
}