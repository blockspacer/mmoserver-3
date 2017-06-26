--------------------------------------------------------------------
-- 文件名:	fast_math.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/16 0016
-- 描  述:	数学库优化版
--------------------------------------------------------------------
local math_floor = math.floor

local sin_table = {}
for i = 1, 360 do
    local v = math.sin(math.rad(i))
    sin_table[i] = v
end

local cos_table = {}
for i = 1, 360 do
    local v = math.cos(math.rad(i))
    cos_table[i] = v
end


local function sin_angle(angle)
    angle = math_floor(angle)
    return sin_table[angle]
end

local function cos_angle(angle)
    angle = math_floor(angle)
    return cos_table[angle]
end

return {
    sin_angle = sin_angle,
    cos_angle = cos_angle,
}
