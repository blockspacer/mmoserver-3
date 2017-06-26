--------------------------------------------------------------------
-- 文件名:	log.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/08/26
-- 描  述:	管理npc类型
--------------------------------------------------------------------
local const = require "Common/constant"
local string_match = string.match
local pairs = pairs
local string_format = string.format

local error_string = {}
for i = const.MESSAGE_LUA_START, const.MESSAGE_LUA_END do
    for j, v in pairs(const) do
        if v == i and string_match(j, '%u%u_MESSAGE_*') then
            error_string[i] = j
        end
    end
end


--------------------------------
--  带有过滤功能的log
-- @param name 一般是严重级别或个人识别字符串，例如"warn"，"error"等等
local _fatal = _fatal
local _error = _error
local _warn = _warn
local _info = _info
local _debug = _debug
local _trace = _trace

local flog = function(name, log_str, actor_id)
    if name == 'fatal' then
        _fatal(log_str)
        assert(false)
    elseif name == 'error' then
        _error(log_str)
        assert(false)
    elseif name == 'warn' then
        _warn(log_str)
    elseif name == 'info' then
        _info(log_str)
    elseif name == "debug" then
        _debug(log_str)
    elseif name == "trace" then
        _trace(log_str)
    elseif name == 'syzDebug' then
        --_trace(log_str)
    elseif name == 'net_msg' then
        if error_string[log_str] ~= nil then
            _info(error_string[log_str])
        else
            _info("net_msg "..log_str)
        end
    elseif name == "tmlDebug" then
        --_info(log_str)
    elseif name == "salog" then
        _info(string_format("[SALOG] id %s: %s", actor_id, log_str))
    end
end

if false then
    for i = const.MESSAGE_LUA_START, const.MESSAGE_LUA_END do
        flog('net_msg', i)
    end
    flog("syzDebug", "example")
end


return flog