--------------------------------------------------------------------
-- 文件名:	fashion_effect.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/28 0028
-- 描  述:	时装类道具
--------------------------------------------------------------------

local item_effect = require "entities/items/item_effect"
local flog = require "basic/log"

local add_buff_effect = ExtendClass(item_effect)

function add_buff_effect:__ctor()
    self.buff_id = 0
end

function add_buff_effect:effect(launcher,target,count)
    return launcher:use_fashion_item(self.fashion_id, self.last_days, self.item_id)
end

function add_buff_effect:parse_effect(id,param1,param2)
    self.fashion_id = tonumber(param1)
    self.last_days = tonumber(param2)
    self.item_id = id

    if self.fashion_id == nil or self.last_days == nil then
        flog("error", "fashion_effect parse_effect error "..param1.." "..param2)
    end
    return true
end

return add_buff_effect