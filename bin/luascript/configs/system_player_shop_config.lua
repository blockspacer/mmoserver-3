--------------------------------------------------------------------
-- 文件名:	system_player_shop_config.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/6/29 0029
-- 描  述:	商铺、摆摊数据表配置
--------------------------------------------------------------------
local system_player_shop = require "data/system_player_shop"
local stall_cost = {}

local function reload()
    local stall_cost_config = system_player_shop.Parameter[6].Para
    stall_cost.item_id = stall_cost_config[1]
    stall_cost.item_cnt = stall_cost_config[2]
end

reload()

return {
    reload = reload,
    stall_cost = stall_cost,
}
