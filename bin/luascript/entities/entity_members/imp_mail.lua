----------------------------------------------------------------------
-- 文件名:	imp_mail.lua
-- 版  权:	(C) 华风软件
-- 创建人:	tanmingliang
-- 日  期:	2017/01/19
-- 描  述:	邮件模块
--------------------------------------------------------------------
local flog = require "basic/log"
local const = require "Common/constant"
local create_item = require "entities/items/item"

local params = {

}

local imp_mail = {}
imp_mail.__index = imp_mail

setmetatable(imp_mail, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_mail.__params = params

function imp_mail.__ctor(self)

end

--根据dict初始化
function imp_mail.imp_mail_init_from_dict(self, dict)

end

function imp_mail.imp_mail_write_to_dict(self, dict)

end

function imp_mail.imp_mail_write_to_sync_dict(self, dict)

end

function imp_mail.on_get_mails_info(self,intput,syn_data)
    self:send_message_to_mail_server({func_name = "on_get_mails_info"})
end

function imp_mail.on_read_mail(self,input,sync_data)
    if input.mail_id == nil then
        return
    end
    self:send_message_to_mail_server({func_name = "on_read_mail",mail_id=input.mail_id})
end

function imp_mail.on_get_mail_attachment(self,input,sync_data)
    if input.mail_id == nil then
        return
    end
    self:send_message_to_mail_server({func_name = "on_get_mail_attachment",mail_id=input.mail_id})
end

function imp_mail.on_get_all_mails_attachments(self,input,sync_data)
    self:send_message_to_mail_server({func_name = "on_get_all_mails_attachments"})
end

function imp_mail.on_delete_mail(self,input,syn_data)
    if input.mail_id == nil then
        return
    end
    self:send_message_to_mail_server({func_name = "on_delete_mail",mail_id=input.mail_id})
end

function imp_mail.on_clear_mails(self,input,sync_data)
    self:send_message_to_mail_server({func_name = "on_clear_mails"})
end

function imp_mail.on_add_new_mails(self,input,sync_data)
    input.func_name = "GetMailsInfoReply"
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,input)
end

function imp_mail.on_extract_mail_attachment(self,input,sync_data)
    local error = 0
    local items = input.items
    local attachment_count = input.attachment_count
    if attachment_count > self:get_empty_slot_number() then
        error = const.error_no_empty_cell
    else
        --添加奖励
        local items_special = {}
        local items_normal = {}
        local rewards = {}
        for _, item in pairs(items) do
            if item.special then
                local exist_count = rewards[item.item_data.id] or 0
                table.insert(items_special, item.item_data)
                rewards[item.item_data.id] = item.item_data.cnt + exist_count
            else
                if item.item_id ~= nil and item.count ~= nil then
                    local exist_count = rewards[item.item_id] or 0
                    items_normal[item.item_id] = item.count + exist_count
                    rewards[item.item_id] = item.count + exist_count
                end
            end
        end
        if not table.isEmptyOrNil(items_normal) then
            self:add_new_rewards(items_normal)
        end

        for _, item_data in pairs(items_special) do
            local pos = self:get_first_empty()
            local new_item = create_item()
            new_item:init_from_dict(item_data)
            self:add_item(pos, new_item)
        end
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GetRewardsNotice",rewards=rewards})
        self:imp_assets_write_to_sync_dict(sync_data)
    end
    self:send_message_to_mail_server({func_name="on_extract_mail_attachment_reply",result = error,mail_id=input.mail_id,all=input.all})
end

return imp_mail