--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/20 0020
-- Time: 18:17
-- To change this template use File | Settings | File Templates.
--
local objectid = objectid
local const = require "Common/constant"
local flog = require "basic/log"
local system_friends_chat_config = require "configs/system_friends_chat_config"
local center_server_manager = require "center_server_manager"

mail_helper = {}

local mail_helper = mail_helper

function mail_helper.send_mail(actor_id,system_mail_id,attachment_org,send_time,params)
    flog("tmlDebug","mail_helper.send_mail actor_id:"..actor_id)
    local mail_id = objectid()

    local mail_config = system_friends_chat_config.get_mail_config(system_mail_id)
    if mail_config == nil then
        system_mail_id = system_mail_id or "nil"
        flog("error", "send_mail : find mail_config fail  id "..system_mail_id)
        return
    end

    local attachment = table.copy(attachment_org)
    --清理无效附件
    local error_index = {}
    for i, v in pairs(attachment) do
        if v.item_id == nil or v.count == nil then
            table.insert(error_index, i)
        end
    end
    for i, v in pairs(error_index) do
        attachment[v] = nil
    end

    for i = 1, 5 do
        local rwd = mail_config["Reward"..i]
        if rwd ~= nil and #rwd == 2 then
            table.insert(attachment, {item_id = rwd[1], count = rwd[2]})
        end
    end

    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.mail_service, const.OM_MESSAGE_LUA_GAME_RPC, {func_name="on_new_mail",actor_id = actor_id,mail_info={mail_id=mail_id,system_mail_id=system_mail_id,attachment=attachment,send_time=send_time,params=params,read=false,extract=false}})
end

function mail_helper.format_mail_content_by_scheme_id(mail_id, ...)
    local mail_config = system_friends_chat_config.get_mail_config(mail_id)
    if mail_config == nil then
        mail_id = mail_id or "nil"
        flog("error", "format_mail_content_by_scheme_id : find mail_config fail  id "..mail_id)
        return
    end
    local content_text = system_friends_chat_config.get_mail_content(mail_id)
    return string.format(content_text, ...)
end

function mail_helper.send_mail_by_scheme_id(actor_id, mail_id, attachment, content)
    local mail_config = system_friends_chat_config.get_mail_config(mail_id)
    if mail_config == nil then
        mail_id = mail_id or "nil"
        flog("error", "send_mail_by_scheme_id : find mail_config fail  id "..mail_id)
        return
    end

    local content_text = content or system_friends_chat_config.get_mail_content(mail_id)
    local mail_name = system_friends_chat_config.get_mail_name(mail_id)
    local mail_title = mail_name
    local mail_sender = system_friends_chat_config.get_mail_sender(mail_id)
    local mail_type = mail_config.MessageType
    mail_helper.send_mail(actor_id,mail_type,mail_name,mail_title,mail_sender,content_text, attachment,_get_now_time_second())
end

return mail_helper

