--------------------------------------------------------------------
-- 文件名:	pet_generate.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/27 0027
-- 描  述:	宠物产出
--------------------------------------------------------------------
local daily_refresher = require("helper/daily_refresher")

local scheme_param = require("data/common_parameter_formula").Parameter
local DAILY_REFRESH_HOUR = scheme_param[37].Parameter
local DAILY_REFRESH_MIN = scheme_param[38].Parameter
local MAX_TYPEB_ONE_DAY = scheme_param[39].Parameter     --当天全服出现B类宠物数量上限
local RATE_TYPEB = scheme_param[40].Parameter     --每次产出宠物出现B的概率。（百万分之）

local current_typeb_num = 0
local pet_generate_daily_refresher
local function _refresh_daily_data()
    current_typeb_num = 0
end

local function get_new_pet_type()
    pet_generate_daily_refresher:check_refresh()
    if current_typeb_num >= MAX_TYPEB_ONE_DAY then
        return "A"
    end
    local rand_num = math.random(1000000)
    if rand_num <= RATE_TYPEB then
        current_typeb_num = current_typeb_num + 1
        return "B"
    end
    return "A"
end

local function on_server_start()
    local current_time = _get_now_time_second()
    pet_generate_daily_refresher = daily_refresher(_refresh_daily_data, current_time, DAILY_REFRESH_HOUR, DAILY_REFRESH_MIN)
    pet_generate_daily_refresher:check_refresh()
end

return {
    get_new_pet_type = get_new_pet_type,
    on_server_start = on_server_start,
}