--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/20 0020
-- Time: 10:24
-- To change this template use File | Settings | File Templates.
--

local data_base = require "basic/db_mongo"
local flog = require "basic/log"
local system_friends_chat_config = require "configs/system_friends_chat_config"
local mail_player = require "global_mail/mail_player"

mail_center = mail_center or {}
local mail_center = mail_center
local online_user = {}
local offline_user_callback_ids = {}
local server_stop = false

local function update_offline_player_mail_callback(self, status, playerdata,callback_id)
    if status == false or playerdata == nil then
        flog("warn","imp_global_friend update_offline_player_mail_callback,actor id:"..offline_user_callback_ids[callback_id].actor_id.." mail info:"..table.serialize(offline_user_callback_ids[callback_id].mail_info))
        offline_user_callback_ids[callback_id] = nil
        return
    end
    offline_user_callback_ids[callback_id] = nil
end

local function add_new_mail_to_offline_player(actor_id,mail_info)
    flog("tmlDebug","mail_center.add_new_mail_to_offline_player")
    local callback_id = data_base.db_find_and_modify(mail_center,update_offline_player_mail_callback,"actor_mails",{actor_id=actor_id},{["$push"]={mails=mail_info}},{},0)
    offline_user_callback_ids[callback_id] = {}
    offline_user_callback_ids[callback_id].actor_id = actor_id
    offline_user_callback_ids[callback_id].mail_info = mail_info
end

function mail_center:on_mail_player_init(input)
    flog("tmlDebug","mail_center.on_mail_player_init")
    local player = self:get_user(input.actor_id)
    if player == nil then
        player = mail_player(input.actor_id)
        self:add_user(input.actor_id,player)
        player:query_mails_info()
        player:init(tonumber(input.session_id),input.server_id)
        return
    else
        player:init(tonumber(input.session_id),input.server_id)
    end

    player:mail_player_init_complete()
end

function mail_center:on_mail_player_logout(input)
    flog("tmlDebug","mail_center.on_mail_player_logout")
    local player = self:get_user(input.actor_id)
    if player ~= nil then
        player:on_logout()
    end
end

function mail_center:on_new_mail(input)
    flog("tmlDebug","mail_center.on_new_mail")
    if input.actor_id == nil then
        flog("tmlDebug","mail_center.on_new_mail input.actor_id == nil")
        return
    end
    local player = self:get_user(input.actor_id)
    if player ~= nil then
        player:add_new_mails({input.mail_info})
    else
        add_new_mail_to_offline_player(input.actor_id,input.mail_info)
    end
end

function mail_center:on_message(input)
    flog("tmlDebug","mail_center:on_message input "..table.serialize(input))
    if input.func_name == nil then
        flog("info","global mail mail_center on_message func_name is nil!!!")
        return
    end

    if input.func_name == "on_new_mail" or input.func_name == "on_mail_player_init" or input.func_name == "on_mail_player_logout" then
        if self[input.func_name] == nil then
            flog("info","mail_center have not function name:"..input.func_name)
            return
        end
        self[input.func_name](self,input)
    else
        local player = online_user[input.actor_id]
        if player ~= nil then
            player:on_message(input)
        end
    end
end

function mail_center:get_user(actor_id)
    return online_user[actor_id]
end

function mail_center:add_user(actor_id,user)
    online_user[actor_id] = user
end

function mail_center:delete_user(actor_id)
    online_user[actor_id] = nil
end

local function check_close()
    if server_stop then
        if table.isEmptyOrNil(online_user) then
            MailUserManageReadyClose()
        end
    end
end

function mail_center:clean_mail_user_data(actor_id)
    flog("tmlDebug","clean_mail_user_data actor_id "..actor_id)
    self:delete_user(actor_id)
    check_close()
end

function mail_center:on_server_stop(self)
    server_stop = true
    for actor_id,mail_player in pairs(online_user) do
        mail_player:on_logout()
    end
    check_close()
end

return mail_center