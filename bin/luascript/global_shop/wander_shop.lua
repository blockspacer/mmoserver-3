--------------------------------------------------------------------
-- 文件名:	wander_shop.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/1 0001
-- 描  述:	云游商人
--------------------------------------------------------------------
local flog = require "basic/log"
local const = require "Common/constant"
local broadcast_message = require("basic/net").broadcast_message
local wander_scheme = require("data/system_store").wander
local string_split = require("basic/scheme").string_split
local store_param = require("data/system_store").Parameter
local timer = require "basic/timer"
local date_to_day_second = require("basic/scheme").date_to_day_second

local wander_timer
local wander_appear = false


local wander_exist_range = {}
local refresh_time = store_param[2].value
refresh_time = string_split(refresh_time,"|")
for _, time in pairs(refresh_time) do
    time = string_split(time,":")
    local start_time = date_to_day_second({hour = time[1], min = time[2], sec = 0})
    local end_time = date_to_day_second({hour = time[1], min = time[2], sec = 0}) + const.WANDER_LAST_TIME
    table.insert(wander_exist_range, {start_time = start_time, end_time = end_time})
end

local wander_list = {}
local function create_wander_list()
    wander_list = {}

    local index_list = {}
    for i, v in pairs(wander_scheme) do
        if index_list[v.num] == nil then
            index_list[v.num] = {}
        end

        table.insert(index_list[v.num], i)
    end

    for i, v in pairs(index_list) do
        local index = v[math.random(#v)]
        local item = wander_scheme[index].item
        wander_list[i] = {index = index, id = item[1], count = item[2]}
    end
end


local is_debug = false
local function wander_timer_callback()
    if is_debug then
        return
    end

    local cur_time = date_to_day_second()
    local is_in_refresh = false
    for _, v in pairs(wander_exist_range) do
        if cur_time > v.start_time and cur_time < v.end_time then
            is_in_refresh = true
            break
        end
    end

    if wander_appear and not is_in_refresh then
        wander_appear = false
        wander_list = {}
        broadcast_message(const.SC_MESSAGE_LUA_WANDER_DISAPPEAR, {})
    elseif not wander_appear and is_in_refresh then
        wander_appear = true
        create_wander_list()
        broadcast_message(const.SC_MESSAGE_LUA_WANDER_APPEAR, {wander_list = wander_list})
    end
end


local function wander_buy(cell, count, index)
    if wander_list[cell] == nil or wander_list[cell].index ~= index then
        return const.error_wander_goods_not_exist
    end

    if wander_list[cell].count < count then
        return const.error_wander_goods_not_enough
    end

    wander_list[cell].count = wander_list[cell].count - count
    return 0, wander_list
end

local function get_wander_list()
    return wander_list
end

local function gm_wander_appear(debug)
    if debug == 1 then
        is_debug = true
        wander_appear = true
        create_wander_list()
        broadcast_message(const.SC_MESSAGE_LUA_WANDER_APPEAR, {wander_list = wander_list})
    else
        is_debug = false
    end
end

local function on_server_start()
    if wander_timer == nil then
        wander_timer = timer.create_timer(wander_timer_callback, 5000, const.INFINITY_CALL)
    end
end

return {
    on_server_start = on_server_start,
    wander_buy = wander_buy,
    gm_wander_appear = gm_wander_appear,
    get_wander_list = get_wander_list,
}