--------------------------------------------------------------------
-- 文件名:	global_server_data.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/13 0013
-- 描  述:	服务器全局数据
--------------------------------------------------------------------
local timer = require "basic/timer"
local const = require "Common/constant"
local db_hiredis = require "basic/db_hiredis"

local params = {
    average_level = {default = 1},
}
local data_sync_timer

local global_server_data = {}

local function set_global_data(key, value)
    --global_server_data[key] = value
    db_hiredis.hset("global_server_data", key, value)
end


local function get_server_level()
    return global_server_data.average_level
end

local function refresh_data()
    for i, v in pairs(params) do
        local data = db_hiredis.hget("global_server_data", i)
        if data ~= nil then
            global_server_data[i] = data
        else
            global_server_data[i] = v.default
        end
    end
end


local function _server_start()
    refresh_data()
    if data_sync_timer == nil then
        local rand_sec = math.random(300000)
        data_sync_timer = timer.create_timer(refresh_data, rand_sec + 1800000, const.INFINITY_CALL)
    end
end
register_function_on_start(_server_start)

return {
    set_global_data = set_global_data,
    get_server_level = get_server_level,
    _server_start = _server_start,
}