--------------------------------------------------------------------
-- 文件名:	weekly_refresher.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/11/10
-- 描  述:  每周刷新数据
--------------------------------------------------------------------
local os_date = os.date
local os_time = os.time
local _get_now_time_second = _get_now_time_second

local weekly_refresher = {}
weekly_refresher.__index = weekly_refresher
local base_refresher = require "helper/base_refresher"
for i, v in pairs(base_refresher) do
    weekly_refresher[i] = v
end

setmetatable(weekly_refresher, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function weekly_refresher.__ctor(self, callback, last_refresh_time, refresh_wday, refresh_hour, refresh_min)
    self.callback = callback
    self.last_refresh_time = last_refresh_time
    self.refresh_wday = refresh_wday or 2       --星期几，Sunday为1，Monday为2
    self.refresh_hour = refresh_hour or 0
    self.refresh_min = refresh_min or 0
end


function weekly_refresher.check_refresh(self, avatar)
    local time_now = _get_now_time_second()
    local time_refresh = os_date("*t", time_now)
    local delta_day = time_refresh.wday - self.refresh_wday

    time_refresh.hour = self.refresh_hour
    time_refresh.min = self.refresh_min
    time_refresh = os_time(time_refresh) - delta_day * 86400  --86400是一天的秒数

    if self.last_refresh_time < time_refresh and time_now > time_refresh then
        self.callback(avatar)
        self.last_refresh_time = time_now
        return true
    else
        return false
    end
end


return weekly_refresher