--------------------------------------------------------------------
-- 文件名:	db_hiredis
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/17 0017
-- 描  述:	hi_redis同步接口
--------------------------------------------------------------------
local flog = require "basic/log"
local hiredis = require 'hiredis'
local tonumber = tonumber
local string_format = string.format
local msg_pack =  require "basic/message_pack"

local conn
local mongodb_name

local function on_connect(ip_address, port, mongo)
    conn = hiredis.connect(ip_address, port)
    mongodb_name = string_format("%s_", mongo)

    local test = conn:command("GET", "test_vs1")
    if test == hiredis.NIL then
        _info("hello")
    end
    --test = conn:command("SET", "test_vs", "100")
    --test = conn:command("GET", "test_vs")
    test = conn:command("INCR", "test_vs3")
   -- test = conn:command("SET", "test_vs", "100")
    if test == hiredis.status.OK then
        _info("hello")
    end
    test = conn:command("ZADD", "zset_test", "10", "jim", "9", "tom", "5", "max")
    test = conn:command("ZREVRANGE", "zset_test", "0", "3", "withscores")
    test = conn:command("ZREVRANK", "zset_test", "jim")
    test = conn:command("ZREVRANK", "zset_test", "tom")
    test = conn:command("ZREVRANK", "zset_test", "sam")
    if test == hiredis.NIL then
        local a = tonumber(test)
        _info("hello")
    end
    test = conn:command("MGET", "test_vs", "test_vs2", "test_vs3", "test_vs4")
    --test = conn:command("EXPIRE", "test_vs", 10)
    test = conn:command("GET", "test_vs")
    return conn
end

local function get(key, is_public)
    if not is_public then
        key = mongodb_name..key
    end
    local result = conn:command("GET", key)
    if result == nil or result == hiredis.NIL then
        flog("warn", "hiredis get data fail!")
        return
    end

    result = msg_pack.unpack(result)
    return result
end

local function set(key, value, is_public)
    if not is_public then
        key = mongodb_name..key
    end
    value = msg_pack.pack(value)
    local result = conn:command("SET", key, value)
    if result ~= hiredis.status.OK then
        flog("warn", "hiredis set data fail!"..key)
        return false
    end
    return true
end

local function incr(key)
    key = mongodb_name..key
    local result = conn:command("INCR", key)
    if result == nil or result == hiredis.NIL then
        flog("warn", "hiredis INCR data fail! "..key)
        return
    end
    return result
end

local function zadd(set_name, ...)
    set_name = mongodb_name..set_name
    local result = conn:command("ZADD", set_name, ...)
    if result == nil or result == hiredis.NIL then
        flog("warn", "hiredis ZADD set fail! "..set_name)
        return
    end
    return result
end

local function zscore(set_name,...)
    set_name = mongodb_name..set_name
    local result = conn:command("ZSCORE",set_name,...)
    if result == nil or result == hiredis.NIL then
        flog("warn","hiredis ZSCORE fail!"..set_name)
        return
    end
    return result
end

local function zrevrange(set_name, start_index, end_index, b_withscore)
    set_name = mongodb_name..set_name
    local result
    if b_withscore then
        result = conn:command("ZREVRANGE", set_name, start_index, end_index, "withscores")
    else
        result = conn:command("ZREVRANGE", set_name, start_index, end_index)
    end
        
    if result == nil or result == hiredis.NIL then
        flog("warn", "hiredis ZREVRANGE set fail! "..set_name)
        return
    end
    local length = #result
    local t = {}
    local index = 1
    for i = 1, length - 1, 2 do
        local value = tonumber(result[i + 1])
        if value == nil then
            flog("warn", "ZREVRANGE valule nil")
        end
        t[index] = {key = result[i], value = value}
        index = index + 1
    end
    return t
end

local function zrangebyscore(set_name, min, max, b_withscore)
    set_name = mongodb_name..set_name
    local result
    if b_withscore then
        result = conn:command("ZRANGEBYSCORE", set_name, min, max, "withscores")
    else
        result = conn:command("ZRANGEBYSCORE", set_name, min, max)
    end

    if result == nil or result == hiredis.NIL then
        flog("warn", "hiredis ZRANGEBYSCORE get fail! "..set_name)
        return
    end
    if not b_withscore then
        return result
    end
    local length = #result
    local t = {}
    local index = 1
    for i = 1, length - 1, 2 do
        local value = tonumber(result[i + 1])
        if value == nil then
            flog("warn", "ZREVRANGE valule nil")
        end
        t[index] = {key = result[i], value = value}
        index = index + 1
    end
    return t
end

local function zrange(set_name, min, max, b_withscore)
    set_name = mongodb_name..set_name
    local result
    if b_withscore then
        result = conn:command("ZRANGE", set_name, min, max, "withscores")
    else
        result = conn:command("ZRANGE", set_name, min, max)
    end

    if result == nil or result == hiredis.NIL then
        flog("warn", "hiredis ZRANGE set fail! "..set_name)
        return
    end
    if not b_withscore then
        return result
    end
    local length = #result
    local t = {}
    local index = 1
    for i = 1, length - 1, 2 do
        local value = tonumber(result[i + 1])
        if value == nil then
            flog("warn", "ZREVRANGE valule nil")
        end
        t[index] = {key = result[i], value = value}
        index = index + 1
    end
    return t
end

local function zrevrank(set_name, key_name)
    set_name = mongodb_name..set_name
    local result = conn:command("ZREVRANK", set_name, key_name)
    result = tonumber(result)
    if result ~= nil then
        result = result + 1
    end
    return result
end

local function zrem(set_name, key_name)
    set_name = mongodb_name..set_name
    local result = conn:command("ZREM", set_name, key_name)
    if result == hiredis.NIL then
        result = nil
    end
    return result
end

local function zincrby(set_name,score,key_name)
    set_name = mongodb_name..set_name
    local result = conn:command("ZINCRBY", set_name,score, key_name)
    if result == hiredis.NIL then
        result = nil
    end
    return result
end

local function mget(key_list)
    local list_length = #key_list
    flog("info", "mget key_list lenght "..list_length)

    local page_size = 200
    local index = 1
    local result = {}

    repeat
        local page_index = index
        local temp_key_list = {}
        local count = 1
        for i = index, list_length do
            table.insert(temp_key_list, mongodb_name..key_list[i])
            index = i + 1
            count = count + 1
            if count >= page_size then
                break
            end
        end
        local result_org = conn:command("MGET", unpack(temp_key_list))

        for i, v in pairs(result_org) do
            local id = key_list[i + page_index - 1]
            if v ~= hiredis.NIL and id ~= nil then
                result[id] = msg_pack.unpack(v)
            end
        end
    until(key_list[index] == nil)

    return result
end

local function clear_set(set_name)
    set_name = mongodb_name..set_name
    local result = conn:command("ZREMRANGEBYLEX", set_name, "-", "+")
    if result == hiredis.NIL then
        return
    end
    return result
end

local function expire(key, expire_time)
    key = mongodb_name..key
    local result = conn:command("EXPIRE", key, expire_time)
    if result ~= 1 then
        flog("warn", "hiredis expire data fail!"..key)
        return false
    end
    return true
end

local function hset(set_name, hash_key, value, is_public)
    if not is_public then
        set_name = mongodb_name..set_name
    end
    value = msg_pack.pack(value)
    local result = conn:command("HSET", set_name, hash_key, value)
    if result ~= 1 or result ~= 0 then
        flog("warn", "hiredis hset data fail! "..set_name..hash_key)
        return false
    end
    return true
end

local function hsetnx(set_name, hash_key, value, is_public)
    if not is_public then
        set_name = mongodb_name..set_name
    end
    value = msg_pack.pack(value)
    local result = conn:command("HSETNX", set_name, hash_key, value)
    if result ~= 1 then
        return false
    end
    return true
end

local function hget(set_name, hash_key, is_public)
    if not is_public then
        set_name = mongodb_name..set_name
    end
    local result = conn:command("HGET", set_name, hash_key)
    if result == nil or result == hiredis.NIL then
        flog("warn", "hiredis hget data fail! "..hash_key)
        return
    end

    result = msg_pack.unpack(result)
    return result
end

local function hlen(set_name, is_public)
    if not is_public then
        set_name = mongodb_name..set_name
    end
    local result = conn:command("HLEN", set_name)
    if result == nil or result == hiredis.NIL then
        flog("warn", "hiredis hlen fail! "..set_name)
        return
    end
    return result
end

local function hmget(set_name, key_list, is_public)
    if not is_public then
        set_name = mongodb_name..set_name
    end

    local list_length = #key_list
    flog("info", "mget key_list lenght "..list_length)
    if list_length == 0 then
        return {}
    end

    local page_size = 200
    local index = 1
    local result = {}

    repeat
        local page_index = index
        local temp_key_list = {}
        local count = 1
        for i = index, list_length do
            table.insert(temp_key_list, key_list[i])
            index = i + 1
            count = count + 1
            if count >= page_size then
                break
            end
        end
        local result_org = conn:command("HMGET", set_name, unpack(temp_key_list))
        if result_org == nil or result_org == hiredis.NIL then
            break
        end

        for i, v in pairs(result_org) do
            local id = key_list[i + page_index - 1]
            if v ~= hiredis.NIL and id ~= nil then
                result[id] = msg_pack.unpack(v)
            end
        end
    until(key_list[index] == nil)

    return result
end

local function hkeys(set_name, is_public)
    if not is_public then
        set_name = mongodb_name..set_name
    end

    local result = conn:command("HKEYS", set_name)

    return result
end

local function hdel(set_name, hash_key, is_public)
    if not is_public then
        set_name = mongodb_name..set_name
    end
    local result = conn:command("HDEL", set_name, hash_key)
    if result ~= 1 then
        return false
    end
    return true
end

local function hgetall(set_name)
    set_name = mongodb_name..set_name
    local result_org = conn:command("HGETALL", set_name)
    local result = {}
    if result_org == nil or result_org == hiredis.NIL then
        return result
    end
    local len = #result_org
    for i = 1, len, 2 do
        local id = result_org[i]
        local v = result_org[i + 1]
        if v ~= nil and v ~= hiredis.NIL and id ~= nil then
            result[id] = msg_pack.unpack(v)
        end
    end

    return result
end

local function del(key, is_public)
    if not is_public then
        key = mongodb_name..key
    end

    local result = conn:command("DEL", key)
    if result ~= 1 then
        return false
    end
    return true
end


return  {
    on_connect = on_connect,
    get = get,
    set = set,
    incr = incr,
    zadd = zadd,
    zscore = zscore,
    zrangebyscore = zrangebyscore,
    zrange = zrange,
    zrevrange = zrevrange,
    zrevrank = zrevrank,
    zrem = zrem,
    zincrby = zincrby,
    mget = mget,
    clear_set = clear_set,
    expire = expire,
    hset = hset,
    hget = hget,
    hlen = hlen,
    hmget = hmget,
    hkeys = hkeys,
    hdel = hdel,
    del = del,
    hgetall = hgetall,
    hsetnx = hsetnx,
}