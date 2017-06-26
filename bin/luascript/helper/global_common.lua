--------------------------------------------------------------------
-- 文件名:	global_common.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/5/16 0016
-- 描  述:	global模块通用函数
--------------------------------------------------------------------
local flog = require "basic/log"
local tostring = tostring

local function on_player_session_changed(self, input)
    local new_session_id = tonumber(input.new_session_id)
    if new_session_id == nil then
        flog("error", "on_player_session_changed "..tostring(input.new_session_id))
        return
    end
    self.session_id = new_session_id
end


return {
    on_player_session_changed = on_player_session_changed,
}