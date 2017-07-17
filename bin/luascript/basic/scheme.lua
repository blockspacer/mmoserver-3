--------------------------------------------------------------------
-- 文件名:	scheme.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/09
-- 描  述:	策划表读取相关
--------------------------------------------------------------------
local common_char_chinese_config = require "configs/common_char_chinese_config"
local string_len = string.len
local string_byte = string.byte
local ipairs = ipairs
local pairs = pairs
local string_gmatch = string.gmatch
local table_insert = table.insert
local math_random = math.random
local tonumber = tonumber
local math_ceil = math.ceil
local math_floor = math.floor
local os_date = os.date
local _get_now_time_second = _get_now_time_second
local math = math
local table = table
local system_friends_chat_config = require "configs/system_friends_chat_config"
local const = require "Common/constant"
local string_format = string.format
local string_sub = string.sub
local fix_string = require "basic/fix_string"

local function string_split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    local i = 1
    for str in string_gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

--生成累计数据表（用于根据权重来获得随机值）
--参数t为权重数组，如{10,10,3,2,1}
--table_key为t中需要生成累计数据表的key值
--生成累计数据表，如{10,10,3,2,1}可生成{10,20,23,25,26}
local function create_add_up_table(t, table_key)
    local add_up_table = {}
    local total_weight = 0
    for i, v in ipairs(t) do
        if table_key ~= nil then
            total_weight = total_weight + v[table_key]
        else
            total_weight = total_weight + v
        end
        table_insert(add_up_table, total_weight)
    end
    return add_up_table
end


--通过累计数据表及限制索引获取随机值得索引
--取值索引范围为(min_count, max_count]，min_count不可得，max_count可得
local function get_random_index_with_weight_by_count(t,max_count, min_count)
    if max_count==nil or t[max_count] == nil then
        max_count = #t
    end

    local t_min_count
    if min_count==nil or t[min_count] == nil then
        t_min_count = 1
    else
        t_min_count = t[min_count] + 1
    end

    local rand_num = math_random(t_min_count, t[max_count])
    local index = 1
    for i, v in ipairs(t) do
        index = i
        if rand_num <= v then
            break
        end
    end
    return index
end

local function get_time_from_string(time_str)
   local t = string_split(time_str, "|")
   return tonumber(t[1]), tonumber(t[2])
end

-- 获取开服时间
local open_time
local function get_open_day()
    local time = _get_now_time_second()
    open_time = open_time or os.time{year=2017, month=2, day=1 }
    local open_day = math_floor((time - open_time) / 86400)
    if open_day < 0 then
        open_day = 0
    end
    return open_day
end

-- 从字符串中获取日期
local function get_time_from_date_string(date_str)
    local date_table = string_split(date_str, "-")
    date_table = date_table or {}
    local year = tonumber(date_table[1])
    local month = tonumber(date_table[2])
    local day = tonumber(date_table[3])
    local hour = tonumber(date_table[4]) or 0
    local min = tonumber(date_table[5]) or 0
    local sec = tonumber(date_table[6]) or 0
    if year == nil or month == nil or day == nil then
        _error("error date str "..date_str)
        return nil
    end
    return os.time{year=year, month=month, day=day , hour = hour, min = min, sec = sec}
end

-- 设置开服时间
local function set_open_day(date_str)
    local new_open_time = get_time_from_date_string(date_str)
    if new_open_time ~= nil then
        open_time = new_open_time
    end
    return new_open_time
end


-- 获取配置表中名字
local function get_config_name(scheme_data)
    local name = scheme_data.Name
    if name == 0 then
        name = scheme_data.Name1
    else
        name = common_char_chinese_config.get_table_text(tonumber(name))
    end

    return name
end

local function string_utf8len(input)
    local len  = string_len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string_byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

local function string2utf8(input)
    local len  = string_len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc }
    local utf8table = {}
    while left ~= 0 do
        local tmp = string_byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        table.insert(utf8table,string_sub(input, -left-i,-left-1))
        cnt = cnt + 1
    end
    return utf8table
end

local function get_sequence_index(data_list, key, value)
    local index
    local length = #data_list
    for i = length, 1, -1 do
        if value >= data_list[i][key] then
            index = i
            break
        end
    end
    if index == nil then
        _warn(string_format("get_sequence_index get wrong value, key %s, value %d", key, value))
        index = 1
    end

    return index
end

-- 二分法查找索引(升序)
local function dichotomy_get_index_ascending(data_list, key, value)
    local left = 1;
    local total_length = #data_list
    local right = total_length
    local mid = math_ceil((left + right)/2)
    while left ~= mid do
        if data_list[mid][key] == value then
            break;
        elseif data_list[mid][key] < value then
            left = mid + 1
        else
            right = mid - 1
        end

        mid = math_ceil((left + right)/2)
    end
    return mid
end


-- 以某个key为索引重新生成配置表
local function recreate_scheme_table_with_key(old_table, key)
    local new_table = {}
    for _, v in pairs(old_table) do
        if v[key] == nil then
            return
        end

        new_table[v[key]] = v
    end
    return new_table
end

--日期时间转换为一天从凌晨开始到指定时间的秒数
--date_table为nil时返回当前时间
local function date_to_day_second(date_table)
    if date_table == nil then
        date_table = os_date("*t", _get_now_time_second())
    end
    return date_table.hour * 3600 + date_table.min * 60 + date_table.sec
end

--从M个数中获得随机的N个不同数字
--如果N > M，那么返回M个数字的重排列
local function get_random_n(N, M)
    if N > M then
        N = M
    end

    local array = {}
    for i = 1 , M do
        array[i] = i
    end
    for i = 1 , N do
        local j = math_random(M - i + 1) + i - 1;
        array[i],array[j] = array[j],array[i]
    end
    local result = {}
    for i = 1 , N do
        result[i] = array[i]
    end
    return result
end

local function get_monster_level_by_levels(levels)
    local count = #levels
    if count == 0 then
        return 1
    end
    table.sort(levels,function(a,b)
        return a > b
    end)

    local tmp1 = 0
    local tmp2 = 0
    if levels[1] ~= nil then
        tmp1 = tmp1 + levels[1]*30
        tmp2 = tmp2 + 30
    end
    if levels[2] ~= nil then
        tmp1 = tmp1 + levels[2]*20
        tmp2 = tmp2 + 20
    end
    if levels[3] ~= nil then
        tmp1 = tmp1 + levels[3]*10
        tmp2 = tmp2 + 10
    end
    if levels[4] ~= nil then
        tmp1 = tmp1 + levels[4]*5
        tmp2 = tmp2 + 5
    end
    return math.ceil(tmp1/tmp2)
end

local function create_system_message_by_id(message_id, attach, ...)
    local message = system_friends_chat_config.get_system_message_config(message_id)
    if message == nil then
        return
    end
    local message_data = {}
    message_data.message_type = message.MessageType
    message_data.data = string_format(system_friends_chat_config.get_chat_content(message_id), ...)
    message_data.time = _get_now_time_second()
    message_data.friend_chat_display = message.FriendChatDisplay
    message_data.attach = attach or {}
    message_data.notice = false
    if message.Notice == 1 then
        message_data.notice = true
    end

    return message_data, message
end

-- 获取table t中key值前n个数据
local function get_top_n(t, n, key)
    local list = {}
    for i, v in pairs(t) do
        local value = v[key]
        local length = #list
        local is_insert = false
        for k = 1, length do
            if value > list[k] then
                table.insert(list, k, v)
                is_insert = true
                if #list > n then
                    table.remove(list, n + 1)
                end
                break
            end
        end
        if not is_insert then
            if length < n then
                table.insert(list, v)
            end
        end
    end
    return list
end


local SEC_OF_MIN = 60
local SEC_OF_HOUR = 3600
local SEC_OF_DAY = 86400
local function get_time_str_from_sec(sec)
    local time_str = ""
    if sec <= 0 then
        _error("get_election_basic_info, remaining_sec error "..tostring(sec))
        return ""
    end

    local last_day = math.ceil(sec / SEC_OF_DAY)
    if last_day > 1 then
        time_str = string_format(fix_string.n_day, last_day)
        return time_str
    end
    local last_hour = math.ceil(sec / SEC_OF_HOUR)
    if last_hour > 1 then
        time_str = string_format(fix_string.n_hour, last_hour)
        return time_str
    end
    local last_min = math.ceil(sec / SEC_OF_MIN)
    if last_min > 1 then
        time_str = string_format(fix_string.n_min, last_min)
        return time_str
    end
    time_str = string_format(fix_string.n_sec, sec)
    return time_str
end

return {
    string_split = string_split,
    create_add_up_table = create_add_up_table,
    get_random_index_with_weight_by_count = get_random_index_with_weight_by_count,
    get_time_from_string = get_time_from_string,
    get_open_day = get_open_day,
    set_open_day = set_open_day,
    get_time_from_date_string = get_time_from_date_string,
    get_config_name = get_config_name,
    string_utf8len = string_utf8len,
    dichotomy_get_index_ascending = dichotomy_get_index_ascending,
    recreate_scheme_table_with_key = recreate_scheme_table_with_key,
    date_to_day_second = date_to_day_second,
    get_random_n = get_random_n,
    get_sequence_index = get_sequence_index,
    get_monster_level_by_levels =get_monster_level_by_levels,
    create_system_message_by_id = create_system_message_by_id,
    string2utf8 = string2utf8,
    get_top_n = get_top_n,
    get_time_str_from_sec = get_time_str_from_sec,
}