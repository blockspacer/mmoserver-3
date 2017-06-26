--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/6/22 0022
-- Time: 10:56
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local string_match = string.match
local pairs = pairs
local string_format = string.format

local log_level = {
    trace = 1,
    debug = 2,
    syzDebug = 2,
    tmlDebug = 2,
    info = 3,
    net_msg = 3,
    salog = 3,
    warn = 4,
    error = 5,
    fatal = 6,
}

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

local level = nil

local function log(filter,info,...)
    if level ~= nil and log_level[filter] < level then
        return
    end
    local log_str = string_format(info,...)
    if filter == 'fatal' then
        _fatal(log_str)
        assert(false)
    elseif filter == 'error' then
        _error(log_str)
        assert(false)
    elseif filter == 'warn' then
        _warn(log_str)
    elseif filter == 'info' then
        _info(log_str)
    elseif filter == "debug" then
        _debug(log_str)
    elseif filter == "trace" then
        _trace(log_str)
    elseif filter == 'syzDebug' then
        _info(log_str)
    elseif filter == 'net_msg' then
        if error_string[log_str] ~= nil then
            _info(error_string[log_str])
        else
            _info(string_format("net_msg %s",log_str))
        end
    elseif filter == "tmlDebug" then
        _info(log_str)
    elseif filter == "salog" then
        _info(string_format("[SALOG] %s", log_str))
    end
end

local function set_level(value)
    level = value
end

return {
    log = log,
    set_level = set_level,
}

