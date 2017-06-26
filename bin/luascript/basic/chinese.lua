--------------------------------------------------------------------
-- 文件名:	chinese.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/08
-- 描  述:	处理文本字符串
--------------------------------------------------------------------
local flog = require "basic/log"
local tostring = tostring
local pairs = pairs

local chinese_data = {}
local data_in_all = {}

local function init_data()
    chinese_data = require "data/common_char_chinese"
    for i, member in pairs(chinese_data) do
        for j , v in pairs(member) do
            data_in_all[j] = v
        end
    end
end

local function get_chinese_text(text_id)
    if data_in_all == nil or data_in_all[text_id] == nil or data_in_all[text_id].NR == nil then
        return tostring(text_id)
    end
    return data_in_all[text_id].NR
end

init_data()

if false then
    flog("syzDebug", get_chinese_text(3121031))
    flog("syzDebug", get_chinese_text(3000001))
    flog("syzDebug", get_chinese_text(100001))
    flog("syzDebug", get_chinese_text(900000002))
    flog("syzDebug", get_chinese_text(102))
end

return get_chinese_text