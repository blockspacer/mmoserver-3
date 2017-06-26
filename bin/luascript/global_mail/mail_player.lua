--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/25 0025
-- Time: 9:45
-- To change this template use File | Settings | File Templates.
--

local data_base = require "basic/db_mongo"
local flog = require "basic/log"
local send_to_game = require("basic/net").forward_message_to_game
local send_to_client = require("basic/net").send_to_client
local const = require "Common/constant"
local system_friends_chat_config = require "configs/system_friends_chat_config"
local mail_info = require "global_mail/mail_info"
local timer = require "basic/timer"
local _get_now_time_second = _get_now_time_second

local mail_player = {}
mail_player.__index = mail_player

setmetatable(mail_player,{
    __call=function(cls,...)
        local self = setmetatable({},cls)
        self:__ctor(...)
        return self
    end
})

function mail_player:__ctor(actor_id)
    self.actor_id = actor_id
    self.session_id = 0
    self.server_id = 0
    self.save_mail_timer = nil
    self.mails = {}
    self.is_logout = false
    self.init_mails = false
    --玩家登录时新增的邮件,此时邮件数据还没有初始化
    self.tmp_mails = nil
end

function mail_player:init(session_id,server_id)
    self.session_id = session_id
    self.server_id = server_id
end

function mail_player:send_message_to_game(msg_data)
    flog("tmlDebug","mail_center.send_message_to_game")
    if self.server_id == nil then
        flog("tmlDebug","mail_center.send_message_to_game server_id == nil")
        return
    end

    msg_data.actor_id = self.actor_id
    send_to_game(self.server_id, const.OG_MESSAGE_LUA_GAME_RPC,  msg_data)
end

function mail_player.send_message(self, key_action, msg_data)
    send_to_client(self.session_id, key_action, msg_data)
end

local function save_mail_info_callback(self, status)
    if status == false then
        flog("info","mail player save mail info fail!!!")
        return
    end
    if self.is_logout then
        mail_center:clean_mail_user_data(self.actor_id)
    end
end

local function save_mail_info(self)
    local player_mail_data = {}
    player_mail_data.actor_id = self.actor_id
    player_mail_data.mails = {}
    for _,mail in pairs(self.mails) do
        local mailinfo = {}
        mail:write_to_dict(mailinfo)
        table.insert(player_mail_data.mails,mailinfo)
    end
    data_base.db_update_doc(self,save_mail_info_callback,"actor_mails",{actor_id=self.actor_id},player_mail_data,1,0)
end

local function write_mails_to_sync_dict(self,dict)
    dict.mails = {}
    dict.unread_mail = self:is_have_unread()
    for _,mail in pairs(self.mails) do
        local mailinfo = {}
        mail:write_to_dict(mailinfo)
        table.insert(dict.mails,mailinfo)
    end
end

local function remove_save_mail_timer(self)
    if self.save_mail_timer ~= nil then
        timer.destroy_timer(self.save_mail_timer)
        self.save_mail_timer = nil
    end
end

local function init_mails_info(self,dict)
    self.mails = {}
    local current_time = _get_now_time_second()
    local mails_info = table.get(dict,"mails",{})
    for _,mail in pairs(mails_info) do
        if mail.send_time ~= nil and current_time - mail.send_time < system_friends_chat_config.get_mail_time_limit() then
            local mailinfo = mail_info()
            mailinfo:init_from_dict(mail)
            table.insert(self.mails,mailinfo)
        end
    end
    if #self.mails > 1 then
        table.sort(self.mails,function(a,b)
            return b.send_time < a.send_time
        end)
    end
    for i=#self.mails,system_friends_chat_config.get_mail_max_count()+1,-1 do
        table.remove(self.mails,i)
    end

    remove_save_mail_timer(self)
    self.save_mail_timer = timer.create_timer(function()
        save_mail_info(self)
    end,600000,10000000)
end

local function _db_callback_query_player_mail_data(self, status, player_mail_data,callback_id)
    if status == false then
        flog("info","mail_player|_db_callback_query_player_mail_data fail!actor_id:"..self.actor_id)
        return
    end
    if player_mail_data == nil then
        flog("info","mail_player|_db_callback_query_player_mail_data fail!player_mail_data == nil")
        player_mail_data = {}
        player_mail_data.actor_id = self.actor_id
    end
    --flog("tmlDebug","_db_callback_query_player_mail_data player_mail_data:"..table.serialize(player_mail_data))
    init_mails_info(self,player_mail_data)
    self:mail_player_init_complete()
end


local function add_new_mail(self,mailinfo)
    local delete_count = #self.mails - system_friends_chat_config.get_mail_max_count() + 1
    for i = delete_count,1,-1 do
        local delete_index = 0
        local delete_time = _get_now_time_second()
        for j=1,#self.mails,1 do
            if self.mails[j].send_time < delete_time then
                delete_time = self.mails[j].send_time
                delete_index = j
            end
        end
        if delete_index > 0 then
            flog("tmlDebug","delete mail when player online,mail count too many!mail info:"..table.serialize(self.mails[delete_index]))
            table.remove(self.mails,delete_index)
        end
    end

    flog("tmlDebug","add new mail when player online!mail info:"..table.serialize(mailinfo))
    local _mail_info = mail_info()
    _mail_info:init_from_dict(mailinfo)
    table.insert(self.mails,_mail_info)
end

function mail_player:query_mails_info()
    data_base.db_find_one(self, _db_callback_query_player_mail_data, "actor_mails", {actor_id = self.actor_id}, {})
end

function mail_player:on_logout()
    self.is_logout = true
    save_mail_info(self)
    remove_save_mail_timer(self)
end

local function _add_new_mails(self,mails_info)
    for i=1,#mails_info,1 do
        add_new_mail(self,mails_info[i])
    end
    local data = {}
    data.result = 0
    data.func_name = "AddNewMail"
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,data)
end

function mail_player:add_new_mails(mails_info)
    if self.init_mails == false then
        if self.tmp_mails == nil then
            self.tmp_mails = {}
        end

        for i=1,#mails_info,1 do
            table.insert(self.tmp_mails,table.copy(mails_info[i]))
        end
        return
    end
    _add_new_mails(self,mails_info)
end

function mail_player:is_have_unread()
    if #self.mails == 0 then
        return false
    end
    for _,mail in pairs(self.mails) do
        if not mail:is_read() then
            return true
        end
    end
    return false
end

function mail_player:on_get_mails_info()
    flog("tmlDebuf","mail_player:on_get_mails_info")
    local reply_data = {}
    reply_data.result = 0
    reply_data.func_name = "GetMailsInfoReply"
    write_mails_to_sync_dict(self,reply_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,reply_data)
end

function mail_player:on_read_mail(input)
    for i=1,#self.mails,1 do
        if self.mails[i]:get_mail_id() == input.mail_id then
            self.mails[i]:set_read()
            break
        end
    end

    local reply_data = {}
    reply_data.result = 0
    reply_data.func_name = "ReadMailReply"
    write_mails_to_sync_dict(self,reply_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,reply_data)
end

function mail_player:on_get_mail_attachment(input)
    local result = 0
    for i=1,#self.mails,1 do
        if self.mails[i]:get_mail_id() == input.mail_id then
            if self.mails[i]:is_extract() == true then
                result = const.error_mail_already_extract_attachment
                break
            end
            if self.mails[i]:get_attachment_count() <= 0 then
                result = const.error_mail_have_not_attachment
                break
            end
            --添加奖励
            local attachment = self.mails[i]:get_attachment()
            local count = #attachment
            if count <= 0 then
                result = const.error_mail_have_not_attachment
                break
            end
            self:send_message_to_game({func_name="on_extract_mail_attachment",items=table.copy(attachment),mail_id=input.mail_id,attachment_count=count,all=false})
            return
        end
    end
    self:reply_get_mail_attachment(result)
end

function mail_player:on_extract_mail_attachment_reply(input)
    local result = input.result
    if result == 0 then
        for i=1,#self.mails,1 do
            if self.mails[i]:get_mail_id() == input.mail_id then
                self.mails[i]:set_extract()
            end
        end
    end
    if input.all == false then
        self:reply_get_mail_attachment(result)
    else
        self:reply_get_all_mail_attachment(result)
    end
end

function mail_player:reply_get_mail_attachment(result)
    local reply_data = {}
    reply_data.result = result
    reply_data.func_name = "GetMailAttachmentReply"
    write_mails_to_sync_dict(self,reply_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,reply_data)
end

function mail_player:on_get_all_mails_attachments(input)
    local result = 0
    self:reply_get_all_mail_attachment(result)
end

function mail_player:reply_get_all_mail_attachment(result)
    if result == 0 then
        for i=1,#self.mails,1 do
            if self.mails[i]:is_extract() == false and self.mails[i]:get_attachment_count() > 0 then
                --添加奖励
                local attachment = self.mails[i]:get_attachment()
                local count = #attachment
                if count <= 0 then
                    result = const.error_mail_have_not_attachment
                    break
                end
                self:send_message_to_game({func_name="on_extract_mail_attachment",items=table.copy(attachment),mail_id=self.mails[i]:get_mail_id(),attachment_count=count,all=true})
                return
            end
        end
    end
    local reply_data = {}
    reply_data.result = result
    reply_data.func_name = "GetAllMailsAttachmentReply"
    write_mails_to_sync_dict(self,reply_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,reply_data)
end

function mail_player:on_delete_mail(input)
    local result = const.error_mail_not_exist
    for i=#self.mails,1,-1 do
        if self.mails[i]:get_mail_id() == input.mail_id then
            result = 0
            if self.mails[i]:is_read() == true then
                table.remove(self.mails,i)
            else
                result = const.error_mail_not_read
            end
            break
        end
    end

    local reply_data = {}
    reply_data.result = result
    reply_data.func_name = "DeleteMailReply"
    write_mails_to_sync_dict(self,reply_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,reply_data)
end

function mail_player:on_clear_mails(input)
    for i=#self.mails,1,-1 do
        if self.mails[i]:is_read() == true then
            table.remove(self.mails,i)
        end
    end
    local reply_data = {}
    reply_data.result = 0
    reply_data.func_name = "ClearMailsReply"
    write_mails_to_sync_dict(self,reply_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,reply_data)
end

function mail_player:get_session_id()
    return self.session_id
end

function mail_player:on_message(input)
    if self[input.func_name] == nil then
        return
    end
    self[input.func_name](self,input)
end

function mail_player:is_have_unread_mail(input)
    self:send_message_to_game({func_name="is_have_unread_mail_reply",unread_mail=self:is_have_unread()})
end

function mail_player:mail_player_init_complete()
    self:send_message_to_game({func_name="mail_player_init_complete"})
    self.init_mails = true
    if not table.isEmptyOrNil(self.tmp_mails) then
        _add_new_mails(self,self.tmp_mails)
    end
end

function mail_player:on_mail_player_game_id_change(input)
    flog("tmlDebug","mail_player:on_mail_player_game_id_change")
    self.server_id = input.actor_game_id
end

mail_player.on_player_session_changed = require("helper/global_common").on_player_session_changed

return mail_player
