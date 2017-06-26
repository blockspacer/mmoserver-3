--------------------------------------------------------------------
-- 文件名:	game_manager_command.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/29 0029
-- 描  述:	运营gm指令
--------------------------------------------------------------------
local online_user = require "onlinerole"
local db_hiredis = require "basic/db_hiredis"
local data_base = require "basic/db_mongo"
local flog = require "basic/log"
local const = require "Common/constant"
local mail_helper = require "global_mail/mail_helper"
local _send_to_gamemanager = _send_to_gamemanager
local net_work = require "basic/net"
local send_to_game = net_work.forward_message_to_game
local timer = require "basic/timer"
local table = table
local _get_now_time_second = _get_now_time_second
local broadcast_message = require("basic/net").broadcast_message

--某些公告需要多次
local notices = {}
local tick_timer = nil
local game_manager = {}

local function _modify_database_callback(param, status, callback_id)
    local client_id = param.client_id
    local actor_id = param.actor_id
    local key = param.key

    local redis_key = "role_lock:"..actor_id
    db_hiredis.set(redis_key, false)

    if status == 0  then
        return _send_to_gamemanager(client_id, "Find actor Fail! "..actor_id)
    end

    _send_to_gamemanager(client_id, string.format("%s modify %s success", actor_id, key))
end


function game_manager.modify_player_data(client_id, actor_id, key, value)
    local player = online_user.get_user(actor_id)
    local role_state = db_hiredis.hget("role_state", actor_id)
    if player == nil then
        if role_state == nil then
            local redis_key = "role_lock:"..actor_id
            db_hiredis.set(redis_key, true)
            db_hiredis.expire(redis_key, 30)        --30秒后过期，防止一直被锁定

            local param = {actor_id = actor_id, client_id = client_id, key = key }
            data_base.db_update_doc(param,_modify_database_callback,"actor_info",{actor_id=actor_id},{["$set"] = {[key] = value}}, 1, 0)
            return
        end
    end
    send_to_game(role_state.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {key = key, value = value, func_name="on_gm_set_avatar_value", actor_id = actor_id})
    _send_to_gamemanager(client_id, string.format("%s modify %s success", actor_id, key))
end

function game_manager.send_mail_to_player(client_id, player_id, mail_id, item, param)
    flog("info", "game_manager.send_mail_to_player")
    mail_helper.send_mail(player_id, mail_id, item, _get_now_time_second(), param)
    _send_to_gamemanager(client_id, "send_mail success")
end

function game_manager.send_mail_to_player_in_batch(client_id, player_id_list, mail_id, item, param)
    flog("info", "game_manager.send_mail_to_player")
    for _, player_id in pairs(player_id_list) do
        mail_helper.send_mail(player_id, mail_id, item, _get_now_time_second(), param)
    end
    _send_to_gamemanager(client_id, "send_mail success")
end


local function _get_actor_id_callback(client_id, status, doc)
    if status == 0 or table.isEmptyOrNil(doc) then
        return _send_to_gamemanager(client_id, "Find actor Fail! "..status)
    end
    _send_to_gamemanager(client_id, string.format("Actor %s, actor id is %s", doc.actor_name, doc.actor_id))
end

function game_manager.get_actor_id(client_id, actor_name)
    data_base.db_find_one(client_id, _get_actor_id_callback, "actor_info", {actor_name = actor_name}, {})
end

local function _get_actor_id_in_batch_callback(client_id, status, doc)
    if status == 0 or table.isEmptyOrNil(doc) then
        return _send_to_gamemanager(client_id, "Find actor in batch Fail!")
    end
    _send_to_gamemanager(client_id, table.serialize(doc))
end

function game_manager.get_actor_id_in_batch(client_id, actor_name_table)
    if not table.isEmptyOrNil(actor_name_table) then
        data_base.db_find_n(client_id, _get_actor_id_in_batch_callback, "actor_info", {actor_name = {["$in"] = actor_name_table}}, {actor_name = 1, actor_id = 1})
    end
end


function game_manager.script_reload(client_id)
    OnScriptReload()
    _send_to_gamemanager(client_id, "script_reload success")
end

function game_manager.broadcast_loudspeaker(client_id, notice_id, ...)
    gm_broadcast_loudspeaker(notice_id, ...)
    _send_to_gamemanager(client_id, "broadcast_loudspeaker success")
end

function game_manager.send_mail_to_all_player(client_id, mail_id, item, param)
    flog("info", "game_manager.send_mail_to_player")
    local player_ids = db_hiredis.hkeys("actor_all")
    for _, player_id in pairs(player_ids) do
       mail_helper.send_mail(player_id, mail_id, item, _get_now_time_second(), param)
    end
    _send_to_gamemanager(client_id, "send_mail_to_all_player success")
end

function game_manager.online_num_from_redis()
    return db_hiredis.hlen("role_state")
end

function game_manager.get_online_num(client_id)
    local num = game_manager.online_num_from_redis()
    _send_to_gamemanager(client_id, "online number:"..num)
end

local function tick_handle()
    if table.isEmptyOrNil(notices) then
        return
    end
    local current_time = _get_now_time_second()
    for i=#notices,1,-1 do
        if notices[i].next_send_time < current_time then
            broadcast_message(const.SC_MESSAGE_LUA_CHAT_BROADCAST,notices[i].data)
            notices[i].current_count = notices[i].current_count + 1
            if notices[i].current_count >= notices[i].count then
                table.remove(notices,i)
            else
                notices[i].next_send_time=_get_now_time_second() + notices[i].interval
            end
        end
    end
end

local function init()
    tick_timer = timer.create_timer(tick_handle,1000,const.INFINITY_CALL)
end

function game_manager.add_repeat_notice(data,count,interval)
    if count <= 1 then
        return
    end
    table.insert(notices,{data=data,count=count,interval=interval,current_count=1,next_send_time=_get_now_time_second() + interval})
end

init()

return game_manager