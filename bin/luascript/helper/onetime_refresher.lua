--------------------------------------------------------------------
-- 文件名:	onetime_refresher.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/11/18
-- 描  述:  一次刷新数据的定时器
--------------------------------------------------------------------
local _get_now_time_second = _get_now_time_second

local onetime_refresher = {}
onetime_refresher.__index = onetime_refresher
local base_refresher = require "helper/base_refresher"
for i, v in pairs(base_refresher) do
    onetime_refresher[i] = v
end

setmetatable(onetime_refresher, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})



function onetime_refresher.__ctor(self, callback, last_refresh_time, refresh_interval)
    self.callback = callback
    self.last_refresh_time = last_refresh_time
    self.refresh_interval = refresh_interval or 0
    self.time_refresh = last_refresh_time + self.refresh_interval
end


function onetime_refresher.check_refresh(self, avatar)
    local time_now = _get_now_time_second()
    if time_now > self.time_refresh then
        self.callback(avatar)
        self.last_refresh_time = time_now
        return true
    else
        return false, self.last_refresh_time
    end
end


function onetime_refresher.get_refresh_interval(self)
    return self.refresh_interval
end

return onetime_refresher