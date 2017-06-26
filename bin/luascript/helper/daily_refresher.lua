--------------------------------------------------------------------
-- 文件名:	daily_refresher.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/10/28
-- 描  述:  每日刷新数据
--------------------------------------------------------------------
local os_date = os.date
local os_time = os.time
local _get_now_time_second = _get_now_time_second

local daily_refresher = {}
daily_refresher.__index = daily_refresher
local base_refresher = require "helper/base_refresher"
for i, v in pairs(base_refresher) do
    daily_refresher[i] = v
end

setmetatable(daily_refresher, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function daily_refresher.__ctor(self, callback, last_refresh_time, refresh_hour, refresh_min)
    self.callback = callback
    self.last_refresh_time = last_refresh_time
    self.refresh_hour = refresh_hour or 0
    self.refresh_min = refresh_min or 0
end


function daily_refresher.check_refresh(self, avatar)
    local time_now = _get_now_time_second()
    local time_refresh = os_date("*t", time_now)
    time_refresh.hour = self.refresh_hour
    time_refresh.min = self.refresh_min
    time_refresh = os_time(time_refresh)

    if self.last_refresh_time < time_refresh and time_now > time_refresh then
        self.callback(avatar)
        self.last_refresh_time = time_now
        return true
    else
        return false
    end
end


return daily_refresher