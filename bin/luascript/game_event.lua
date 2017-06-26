--------------------------------------------------------------------
-- 文件名:	game_event.lua
-- 版  权:	(C) 华风软件
-- 创建人:	hou(houontherun@gmail.com)
-- 日  期:	2016/08/08
-- 描  述:	场景文件，最小的游戏世界
--------------------------------------------------------------------
local json = require "basic/json"
local register_service = require("basic/net").register_service
local regist_all_games_id = require("basic/net").regist_all_games_id
local const = require "Common/constant"
local fight_server_user_manager = nil
local center_server_manager = require "center_server_manager"
local user_manage = nil
local game_id = _get_serverid()
local decode_client_data = require("basic/net").decode_client_data
local db_hiredis = require "basic/db_hiredis"
local get_server_config = require("configs/common_sa_config_config").get_server_config
local set_open_day = require("basic/scheme").set_open_day
local timer = require "basic/timer"
local server_config = require "server_config"
game_manager = require 'helper/game_manager_command'
SERVER_ID_IN_CONFIG = -1
local is_server_start = false

local HU = require "hotfix/luahotupdate"
local md5_name = "luascript/md5/md5_"..game_id..".lua"
HU.Init("/hotfix/hotupdatelist", {"/luascript"}, nil, nil, md5_name) --please replace the second parameter with you src path

local _info = _info
local _warn = _warn
local _error = _error
local assert = assert
local pairs = pairs

function OnPlayerLogOut(session_id)
    _info("OnPlayerLogOut "..string.format("%16.0f",session_id))
    --HU.Update()

    local function delay_close_session()
        user_manage.on_close(session_id)
        center_server_manager.on_close(game_id,session_id)
    end
    user_manage.on_player_disconnect(session_id, delay_close_session)

    -- local profiler = require "profiler"
    -- profiler.start()        --profile
end

function OnClientMessage(session_id, key_action, data)
    --[[_info("len "..string.len(data))
    for i = 1,string.len(data) do
        _info(""..string.sub(data, i, i).." = "..string.byte(data, i))
    end]]
    if not is_server_start then
        return
    end

    _info("PlayerLuaRequest "..string.format("%16.0f",session_id))
    user_manage.on_message(session_id, key_action, data)
    _info("PlayerLuaRequest end"..string.format("%16.0f",session_id))
end

local message_handler = {}
function register_server_message_handler(key_action, handle_function)
    if type(key_action) ~= "number" or key_action <= const.MESSAGE_LUA_START or key_action >= const.MESSAGE_LUA_END then
        _error("register_server_message_handler: key_action is not legal " ..key_action )
        return false
    end

    if type(handle_function) ~= "function" then
        _error("register_server_message_handler: The handle_function is not function " ..key_action )
        return false
    end

    message_handler[key_action] = message_handler[key_action] or {}

    table.insert(message_handler[key_action], handle_function)
    return true
end


function OnTranspondMessage(src_server_id, key_action, data)
    _info("OnTranspondMessage "..key_action)
    center_server_manager.on_message(game_id,key_action, data,src_server_id)
    user_manage.on_fight_server_message(src_server_id, key_action, data)
    local hander_table = message_handler[key_action]
    if hander_table ~= nil then
        data = decode_client_data(data)
        for _, handler in pairs(hander_table) do
            handler(data)
        end
    end
end

local function read_server_config(server_name,path,game_id)
    local server_config = server_config.init(path)
    --_info(table.serialize(server_config))
    if server_config.center_server == nil then
        _error("can not find center_server config!!!")
        assert(false)
        return
    end
    if server_config.game == nil then
        _error("can not find game config!!!")
        assert(false)
        return
    end
    if server_config.game[server_name] ~= nil then
        local log = require "basic/flog"
        log.set_level(server_config.game[server_name].log_level)
    end
    for sname,services in pairs(server_config.center_server) do
        if server_config.game[sname] == nil then
            _error("can not find game config!!!gane_name:"..sname)
            assert(false)
            return
        end
        for service_name,_ in pairs(services) do
            register_service(const.SERVICE_TYPE[service_name])
            center_server_manager.on_register_service(server_config.game[sname].id,const.SERVICE_TYPE[service_name])
        end
    end

    if server_config.redis == nil then
        _error("can not read redis config!")
        assert(false)
        return
    end
    local conn = db_hiredis.on_connect(server_config.redis.address, server_config.redis.port, server_config.mongo.dbname)
    if conn == nil then
        _error("connect redis error!")
        assert(false)
        return
    end
    db_hiredis.del("role_state")
    db_hiredis.del("account_state")

    local server_scheme_config = get_server_config(server_config.server_id)
    if server_config.server_id == nil or server_scheme_config == nil then
        _error("get server_config fail!")
        assert(false)
        return
    end
    local new_open_time = set_open_day(server_scheme_config.Time)
    if new_open_time == nil then
        _error("Open day format error!")
        assert(false)
        return
    end
    SERVER_ID_IN_CONFIG = server_config.server_id
end

local function timing_log()
    local online_num = game_manager.online_num_from_redis()
    _info("Online Player Number: "..online_num)
end

--服务器初始化完成，外部模块可以开始调用
local init_function_on_server_start = {}
function OnServerStart(server_name,path)
    _info("OnServerStart server_name "..server_name)
    user_manage = require "login_server/user_manage"
    read_server_config(server_name,path,game_id)
    for _, func in pairs(init_function_on_server_start) do
        func()
    end

    timer.create_timer(timing_log, 300000, const.INFINITY_CALL)
    is_server_start = true
end

function register_function_on_start(callback)
    if type(callback) ~= "function" then
        _error("error in register_function_on_start: callback not a function "  )
        return
    end
    table.insert(init_function_on_server_start, callback)
end

function AllModuleReadyClose()
    _info("AllModuleReadyClose")
    _lua_ready_close()
end

function OnGameServerReadyClose()
    _info("OnGameServerReadyClose")
    center_server_manager.on_server_stop(game_id)
end

function OnServerStop()
    _info("OnServerStop")
    if user_manage.on_server_stop ~= nil then
        user_manage.on_server_stop()
    end
end

function OnFightToGameMessage(src_game_id,key_action,data)
    _info("OnFightToGameMessage:"..key_action)
    user_manage.on_fight_server_message(src_game_id,key_action,data)
    center_server_manager.on_message(game_id, key_action, data,src_game_id)
end

function OnGameToFightMessage(game_id,key_action,data)
    _info("OnGameToFightMessage key_action:"..key_action)
    if fight_server_user_manager == nil then
        return
    end

    fight_server_user_manager.on_game_message(game_id,key_action,data)
end

function OnFightEntityMessage(session_id,key_action,data)
    _info("OnFightEntityMessage session_id:"..string.format("%16.0f",session_id))
    if fight_server_user_manager == nil then
        return
    end
    fight_server_user_manager.on_message(session_id,key_action,data)
end

function OnFightClientDisconnect(session_id)
    _info(string.format("OnFightEntityMessage session_id:%16.0f",session_id))
    fight_server_user_manager.on_disconnect(session_id)
end

function OnFightServerStart(server_name)
    _info("OnFightServerStart server name "..server_name)
    fight_server_user_manager = require "fight_server/fight_server_user_manager"
end

function OnFightServerClose()
    _info("OnFightServerClose")
    if fight_server_user_manager ~= nil then
        fight_server_user_manager.on_fight_server_close()
    end
end

-- TODO:服务器断线
function OnServerDisconnect(endservertype, serverid)
    if endservertype == const.SERVER_TYPE.SERVER_TYPE_GATE then
        user_manage.kick_player_on_gate(serverid)
    end
end

function OnScriptReload()
    _info("OnScriptReload")
    HU.Update()
end

--gameservers={{gameid=123,type=0},{gameid=123,type=0}}
function OnUpdateGameServerInfo(gameservers)
    _info("OnUpdateGameServerInfo")
    for key, value in pairs(gameservers) do
        _info("---------------------------------")
        for k, v in pairs (value) do
            _info("The key " .. k .. "value is "..v)
        end
    end
    center_server_manager.on_update_games_info(gameservers)
    regist_all_games_id(gameservers)
end