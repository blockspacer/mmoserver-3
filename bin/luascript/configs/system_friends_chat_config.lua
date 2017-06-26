--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/19 0019
-- Time: 16:42
-- To change this template use File | Settings | File Templates.
--

local common_char_chinese_config = require "configs/common_char_chinese_config"
local system_friends_chat = require "data/system_friends_chat"
local parameter = system_friends_chat.Parameter


local mail_time_limit = 30
if parameter[17] ~= nil then
    mail_time_limit = parameter[17].Value
end

local mail_count_limit = 50
if parameter[16] ~= nil then
    mail_count_limit = parameter[16].Value
end

local mail_configs = {}
for _,v in pairs(system_friends_chat.Mail) do
    mail_configs[v.ID] = v
end

local function get_mail_time_limit()
    return mail_time_limit*86400
end

local function get_mail_max_count()
    return mail_count_limit
end

local function get_mail_config(id)
    return mail_configs[id]
end

local function get_mail_content(id)
    local config = get_mail_config(id)
    if config == nil then
        return ""
    end
    if config.TextContent > 0 then
        return common_char_chinese_config.get_table_text(config.TextContent)
    end
    return config.TextContent1
end

local function get_mail_sender(id)
    local config = get_mail_config(id)
    if config == nil then
        return ""
    end
    if config.MailSender > 0 then
        return common_char_chinese_config.get_table_text(config.MailSender)
    end
    return config.MailSender1
end

local function get_mail_name(id)
    local config = get_mail_config(id)
    if config == nil then
        return ""
    end
    if config.MailName > 0 then
        return common_char_chinese_config.get_table_text(config.MailName)
    end
    return config.MailName1
end

local system_message_configs = {}
for _,v in pairs(system_friends_chat.SystemMessage) do
    system_message_configs[v.ID] = v
end

local function get_system_message_config(id)
    return system_message_configs[id]
end

local function get_chat_content(id)
    local config = get_system_message_config(id)
    if config == nil then
        return ""
    end
    if config.TextContent > 0 then
        return common_char_chinese_config.get_table_text(config.TextContent)
    end
    return config.TextContent1
end

local function get_chat_nearby_distance()
    return parameter[14].Value
end

return {
    get_mail_time_limit = get_mail_time_limit,
    get_mail_max_count = get_mail_max_count,
    get_mail_config = get_mail_config,
    get_mail_content =get_mail_content,
    get_mail_sender = get_mail_sender,
    get_mail_name = get_mail_name,
    get_system_message_config = get_system_message_config,
    get_chat_content = get_chat_content,
    get_chat_nearby_distance = get_chat_nearby_distance,
}