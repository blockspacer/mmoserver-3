--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/23 0023
-- Time: 11:11
-- To change this template use File | Settings | File Templates.
--

local flog = require "basic/log"
local objectid = objectid
local _get_fight_serverid = _get_fight_id

local function get_fight_serverid(type)
    return _get_fight_serverid(type)
end

local function get_fight_server_info(type)
    local fight_server_id,ip,port = get_fight_serverid(type)
    if fight_server_id == -1 then
        flog("error","fight server is not start!")
        return
    end
    local token = objectid()
    local fight_id = objectid()
    return fight_server_id,ip,port,token,fight_id
end

return {
    get_fight_server_info = get_fight_server_info,
}

