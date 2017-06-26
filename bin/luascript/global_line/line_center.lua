--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/5 0005
-- Time: 16:55
-- To change this template use File | Settings | File Templates.
--

local json = require "basic/json"
local const = require "Common/constant"
local common_scene_config = require "configs/common_scene_config"
local timer = require "basic/timer"
local table = table
local db_hiredis = require "basic/db_hiredis"
local net_work = require "basic/net"
local send_to_game = net_work.forward_message_to_game
local flog = require "basic/log"
local common_parameter_formula_config = require "configs/common_parameter_formula_config"
local debug_config = require "debug_config"
local server_config = require "server_config"

local _error = _error
local _get_now_time_second = _get_now_time_second

local scene_timer = nil
local line_scene_type = const.LINE_SCENE_TYPE
local line_scene_type_config ={}
--开启等待中
local creating_scenes = {}
local pre_close_scenes = {}
--开启预关闭等待
local waiting_start_pre_close_scenes = {}
local start_pre_close_scene_timer = nil
--正在开启的game进程信息
local game_servers = {}
local line_game = {}
local game_line = {}

local id = 0
local function generate_id()
    id = id + 1
    return id
end

--轮询game服务器，以确定服务器是否异常退出，并清理相关数据
local function roll_polling_game_state()

end

local function remove_timer()
    if scene_timer ~= nil then
        timer.destroy_timer(scene_timer)
        scene_timer = nil
    end
end

local function scene_timer_handler()
    if table.isEmptyOrNil(creating_scenes) then
        remove_timer()
        return
    end
    local current_time = _get_now_time_second()
    for scene_id,games in pairs(creating_scenes) do
        for game_id,game in pairs(games) do
            --超过30秒没有回应
            if current_time - game.create_time > 300 then
                flog("warn","create scene timeout "..scene_id)
                games[game_id] = nil
                if table.isEmptyOrNil(games) then
                    creating_scenes[scene_id] = nil
                end
                if table.isEmptyOrNil(creating_scenes) then
                    remove_timer()
                end
            end
        end
    end
end

local function create_timer()
    if scene_timer == nil then
        scene_timer = timer.create_timer(scene_timer_handler,1000,const.INFINITY_CALL)
    end
end

local function create_scene(game_id,scene_id)
    if creating_scenes[scene_id] ~= nil and creating_scenes[scene_id][game_id] ~= nil then
        return
    end
    local result = db_hiredis.zscore("scene_"..scene_id,tostring(game_id))
    if result == nil then
        if creating_scenes[scene_id] == nil then
            creating_scenes[scene_id] = {}
        end
        if creating_scenes[scene_id][game_id] == nil then
            creating_scenes[scene_id][game_id] = {}
            creating_scenes[scene_id][game_id].create_time = _get_now_time_second()
            send_to_game(game_id,const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_create_scene",scene_id = scene_id})
            create_timer()
        end
    end
end

local function remove_start_pre_close_scene_timer()
    if scene_timer ~= nil then
        timer.destroy_timer(scene_timer)
        scene_timer = nil
    end
end

local function start_pre_close_scene_timer_handler()
    if table.isEmptyOrNil(waiting_start_pre_close_scenes) then
        remove_start_pre_close_scene_timer()
        return
    end
    local current_time = _get_now_time_second()
    for scene_id,games in pairs(waiting_start_pre_close_scenes) do
        for game_id,game in pairs(games) do
            --超过30秒没有回应
            if current_time - game.start_time > 30 then
                flog("warn","start pre-close scene timeout "..scene_id)
                games[game_id] = nil
                if table.isEmptyOrNil(games) then
                    waiting_start_pre_close_scenes[scene_id] = nil
                end
                if table.isEmptyOrNil(waiting_start_pre_close_scenes) then
                    remove_start_pre_close_scene_timer()
                end
            end
        end
    end
end

local function create_start_pre_close_timer()
    if start_pre_close_scene_timer == nil then
        start_pre_close_scene_timer = timer.create_timer(start_pre_close_scene_timer_handler,1000,const.INFINITY_CALL)
    end
end

local function start_pre_close_scene(game_id,scene_id)
    if waiting_start_pre_close_scenes[scene_id] ~= nil and waiting_start_pre_close_scenes[scene_id][game_id] ~= nil then
        return
    end
    local result = db_hiredis.zscore("scene_"..scene_id,tostring(game_id))
    if result == nil then
        if waiting_start_pre_close_scenes[scene_id] == nil then
            waiting_start_pre_close_scenes[scene_id] = {}
        end
        if waiting_start_pre_close_scenes[scene_id][game_id] == nil then
            waiting_start_pre_close_scenes[scene_id][game_id] = {}
            waiting_start_pre_close_scenes[scene_id][game_id].create_time = _get_now_time_second()
            send_to_game(game_id,const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_start_pre_close_scene",scene_id = scene_id})
            create_start_pre_close_timer()
        end
    end
end

local function init()
    _info("line_center init")
    local server_config = server_config.get_server_config()
    if server_config.game == nil then
        _error("can not find game config!!!")
        assert(false)
        return
    end
    local scenes = common_scene_config.get_main_scene_table()
    for scene_id,_ in pairs(scenes) do
        db_hiredis.del("scene_"..scene_id)
    end

    for _,server in pairs(server_config.game) do
        if server.line_scene_type == nil then
            _error("server config is error!line_scene_type == nil")
            assert(false)
        end
        if server.line_scene_type == line_scene_type.start or server.line_scene_type == line_scene_type.allow then
            table.insert(line_scene_type_config,{id=server.id,line_scene_type=server.line_scene_type})
        end
    end
    if #line_scene_type_config > 1 then
        table.sort(line_scene_type_config,function(a,b)
            return a.id < b.id
        end)
    end
    for i=1,#line_scene_type_config,1 do
        line_game[i] = line_scene_type_config[i].id
        game_line[line_scene_type_config[i].id] = i
    end
    timer.create_timer(roll_polling_game_state,600000,const.INFINITY_CALL)
end

local function on_create_scene_ret(game_id,input)
    flog("tmlDebug","on_create_scene_ret time ".._get_now_time_second())
    flog("debug","game_id "..input.game_id..",scene_id "..input.scene_id)
    if input.result == 0 or input.result == const.error_scene_already_create then
        if creating_scenes[input.scene_id] == nil then
            flog("debug","creating_scenes[input.scene_id] == nil")
            return
        end
        if creating_scenes[input.scene_id][input.game_id] == nil then
            flog("debug","creating_scenes[input.scene_id][game_id] == nil")
            return
        end

        local result = db_hiredis.zscore("scene_"..input.scene_id,tostring(input.game_id))
        if result == nil then
            db_hiredis.zadd("scene_"..input.scene_id,0,tostring(input.game_id))
        end
        creating_scenes[input.scene_id][input.game_id] = nil
        if table.isEmptyOrNil(creating_scenes[input.scene_id]) then
            creating_scenes[input.scene_id] = nil
        end
    end
end

local function on_start_pre_close_scene_ret(game_id,input)
    flog("tmlDebug","on_start_pre_close_scene_ret time ".._get_now_time_second())
    if input.result == 0 then
        local result = db_hiredis.zscore("scene_"..input.scene_id,tostring(game_id))
        if result == nil then
            db_hiredis.zadd("scene_"..input.scene_id,input.count,tostring(game_id))
        end
        if waiting_start_pre_close_scenes[input.scene_id] ~= nil and waiting_start_pre_close_scenes[input.scene_id][game_id] ~= nil then
            waiting_start_pre_close_scenes[input.scene_id][game_id] = nil
            if table.isEmptyOrNil(waiting_start_pre_close_scenes[input.scene_id]) then
                waiting_start_pre_close_scenes[input.scene_id] = nil
            end
        end
        if pre_close_scenes[input.scene_id] ~= nil then
            for i=#pre_close_scenes[input.scene_id],1,-1 do
                if pre_close_scenes[input.scene_id][i].id == game_id then
                    table.remove(pre_close_scenes[input.scene_id],i)
                end
            end
        end
    end
end

local function on_scene_player_count_change(game_id,input)
    local scene_id = input.scene_id
    if scene_id == nil then
        return
    end
    local addon = input.addon
    --流畅分线
    local fluency_count = 0
    local lines = db_hiredis.zrangebyscore("scene_"..scene_id,-10000,common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_FLUENCY,true)
    if lines ~= nil then
        flog("tmlDebug","on_scene_player_count_change lines="..table.serialize(lines))
        fluency_count = #lines
    end
    --场景新进入玩家
    if addon > 0 then
        --流畅服务器小于等于1时，先开启预关闭服务器
        local pre_start = false
        if fluency_count <= 1 then
            if pre_close_scenes[scene_id] ~= nil and #pre_close_scenes[scene_id] > 0 then
                pre_start = true
                --检查是否已开启
                start_pre_close_scene(pre_close_scenes[scene_id][0].id,scene_id)
            end
        end
        --没有开启预关闭服务器且当前流畅服务器数量为0
        if not pre_start and fluency_count == 0 then
            --获取所有已开启场景分线
            lines = db_hiredis.zrangebyscore("scene_"..scene_id,-10000,10000,false)
            for i = 1,#line_scene_type_config,1 do
                local exist = false
                if lines ~= nil then
                    for j = 1,#lines,1 do
                        if line_scene_type_config[i].id == tonumber(lines[j]) then
                            exist = true
                            break
                        end
                    end
                end
                if not exist then
                    --测试版
                    local create = false
                    if SERVER_ID_IN_CONFIG < 9000 or debug_config.scenes[line_scene_type_config[i].id] == nil then
                        create = true
                    else
                        for s =1,#debug_config.scenes[line_scene_type_config[i].id],1 do
                            if debug_config.scenes[line_scene_type_config[i].id][s] == scene_id then
                                create = true
                                break
                            end
                        end
                    end
                    if create then
                        create_scene(line_scene_type_config[i].id,scene_id)
                    end
                    break
                end
            end
        end
    elseif addon < 0 then
        if  pre_close_scenes[scene_id] ~= nil then
            for i=#pre_close_scenes[scene_id],1,-1 do
                if pre_close_scenes[scene_id][i].id == game_id then
                    pre_close_scenes[scene_id][i].count = pre_close_scenes[scene_id][i].count - 1
                    if pre_close_scenes[scene_id][i].count <= 0 then
                        --关闭
                        send_to_game(game_id,const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_destroy_pre_close_scene",scene_id = scene_id})
                        table.remove(pre_close_scenes[scene_id],i)
                    end
                    break
                end
            end
        end
        --如果超过四个流畅，需要预关闭
        if fluency_count >= 4 then
            local cnt = 0
            for i = 1,#line_scene_type_config,1 do
                for j = 1,fluency_count,1 do
                    if line_scene_type_config[i].id == tonumber(lines[j].key) then
                        cnt = cnt + 1
                        if cnt >= 4 then
                            if pre_close_scenes[scene_id] == nil then
                                pre_close_scenes[scene_id] = {}
                            end
                            db_hiredis.zrem("scene_"..scene_id, tostring(game_id))
                            if tonumber(lines[j].value) <= 0 then
                                --关闭
                                send_to_game(game_id,const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_destroy_pre_close_scene",scene_id = scene_id})
                            else
                                table.insert(pre_close_scenes[scene_id],{id=line_scene_type_config[i].id,count=tonumber(lines[j].value)})
                            end
                        end
                        break
                    end
                end
            end
        end
    end
end

local function on_update_games_info(gameservers)
    --新增进程
    local adds = {}
    for i=1,#gameservers,1 do
        local game_id = gameservers[i].gameid
        local add = true
        for j=1,#game_servers,1 do
            if game_id == game_servers[j].gameid then
                add = false
                break
            end
        end
        if add then
            table.insert(adds,table.copy(gameservers[i]))
        end
    end

    --关闭进程
    local removes = {}
    for i=1,#game_servers,1 do
        local game_id = game_servers[i].gameid
        local remove = true
        for j=1,#gameservers,1 do
            if game_id == gameservers[j].gameid then
                remove = false
                break
            end
        end
        if remove then
            table.insert(removes,table.copy(game_servers[i]))
        end
    end

    if #line_scene_type_config > 0 then
        for i=1,#adds,1 do
            for j=1,#line_scene_type_config,1 do
                if line_scene_type_config[j].id == adds[i].gameid then
                    if line_scene_type_config[j].line_scene_type == line_scene_type.start then
                        flog("tmlDebug","debug ="..table.serialize(debug_config))
                        flog("tmlDebug","debug.scenes ="..table.serialize(debug_config.scenes))
                        if SERVER_ID_IN_CONFIG > 9000 and debug_config.scenes[adds[i].gameid] ~= nil then
                            --测试版
                            for s=1,#debug_config.scenes[adds[i].gameid],1 do
                                create_scene(line_scene_type_config[j].id,debug_config.scenes[adds[i].gameid][s])
                            end
                        else
                            local scenes = common_scene_config.get_main_scene_table()
                            for scene_id,_ in pairs(scenes) do
                                create_scene(line_scene_type_config[j].id,scene_id)
                            end
                        end
                    end
                end
            end
            send_to_game(adds[i].gameid,const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_update_game_line_info",game_line=game_line,line_game = line_game})
        end
        game_servers = table.copy(gameservers)
    end
    for i=1,#removes,1 do
        local scenes = common_scene_config.get_main_scene_table()
        for scene_id,_ in pairs(scenes) do
            db_hiredis.zrem("scene_"..scene_id, tostring(removes[i].gameid))
            if not table.isEmptyOrNil(pre_close_scenes[scene_id]) then
                for h=#pre_close_scenes[scene_id],1,-1 do
                    if pre_close_scenes[scene_id][h].id == removes[i].gameid then
                        table.remove(pre_close_scenes[scene_id],h)
                    end
                end
            end
            if creating_scenes[scene_id] ~= nil then
                creating_scenes[scene_id][removes[i].gameid] = nil
            end
            if waiting_start_pre_close_scenes[scene_id] ~= nil then
                waiting_start_pre_close_scenes[scene_id][removes[i].gameid] = nil
            end
        end
    end
end

register_function_on_start(init)

return {
    on_create_scene_ret = on_create_scene_ret,
    on_scene_player_count_change = on_scene_player_count_change,
    on_start_pre_close_scene_ret = on_start_pre_close_scene_ret,
    on_update_games_info = on_update_games_info,
}

