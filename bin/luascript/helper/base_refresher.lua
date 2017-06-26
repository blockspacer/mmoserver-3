--------------------------------------------------------------------
-- 文件名:	base_refresher.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/1/11 0011
-- 描  述:	刷新器基本函数
--------------------------------------------------------------------

local base_refresher = {}

function base_refresher.get_last_refresh_time(self)
    return self.last_refresh_time
end

function base_refresher.set_last_refresh_time(self, time)
    self.last_refresh_time = time
end

return base_refresher