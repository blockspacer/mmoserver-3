--------------------------------------------------------------------
-- 文件名:	timer.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/22
-- 描  述:	定时器
--------------------------------------------------------------------
local flog = require "basic/log"
local timer_function_list = {}
local _create_timer = _create_timer
local _destory_timer = _destory_timer
local _get_now_time_mille = _get_now_time_mille

--创建定时器
--callback 回调函数
--interval 时间间隔
--call_mode 调用参数：0为1次，其他为无限
local function create_timer(callback, interval, call_mode, times_left, param)
    if callback == nil then
        flog("error", "create_timer callback can not be nil !")
    end
    local id = _create_timer(interval, call_mode)
    timer_function_list[id] = {times_left = times_left, callback = callback, param = param}
    return id
end

local function destroy_timer(trigger_id)
    _destory_timer(trigger_id)
end

function CppCallLuaTimer(trigger_id)
    local trigger_info = timer_function_list[trigger_id]
    if trigger_info == nil then
        flog("error", "CppCallLuaTimer: Trigger not exist "..trigger_id)
    end

    trigger_info.callback(trigger_info.param)
    if trigger_info.times_left ~= nil then
        trigger_info.times_left = trigger_info.times_left - 1
        if trigger_info.times_left <= 0 then
            destroy_timer(trigger_id)
            timer_function_list[trigger_id] = nil
        end
    end
end

local function get_now_time_mille()
    return _get_now_time_mille()
end

return {
    create_timer = create_timer,
    destroy_timer = destroy_timer,
    get_now_time_mille = get_now_time_mille,
}