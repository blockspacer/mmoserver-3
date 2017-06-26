--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/25 0025
-- Time: 16:45
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"

local params = {

}

local imp_red_points = {}
imp_red_points.__index = imp_red_points

setmetatable(imp_red_points,{
    __call = function(cls,...)
        local self = setmetatable({},cls)
        self:__ctor(...)
        return self
    end
})

imp_red_points.__params = params

local function reset_red_points(self)
    self.offline_message = false
    self.friend_applicants = false
    self.unread_mail = false
end

local function check_all_model_init_complete(self)
    if self.friend_init_complete == false then
        return
    end
    if self.mail_init_complete == false then
        return
    end
    self:query_red_points_info()
end

function imp_red_points.on_reds(self,input,syn_data)
    self.offline_message = input.offline_message
    self.friend_applicants = input.friend_applicants
    self:send_message_to_mail_server({func_name="is_have_unread_mail"})
end

function imp_red_points:__ctor()
    reset_red_points(self)
    self.friend_init_complete = false
    self.mail_init_complete = false
end

function imp_red_points:query_red_points_info()
    reset_red_points(self)
    self:send_message_to_friend_server({func_name="on_reds"})

end

function imp_red_points:set_friend_init_complete(value)
    self.friend_init_complete = value
    check_all_model_init_complete(self)
end

function imp_red_points:set_mail_init_complete(value)
    self.mail_init_complete = value
    check_all_model_init_complete(self)
end

function imp_red_points:is_have_unread_mail_reply(input,sync_data)
    self.unread_mail = input.unread_mail
    local red_points = {}
    red_points.result = 0
    red_points.unread_mail = self.unread_mail
    red_points.offline_message = self.offline_message
    red_points.friend_applicants = self.friend_applicants
    self:send_message(const.SC_MESSAGE_LUA_REDS, red_points)
end

function imp_red_points:mail_player_init_complete(input,sync_data)
    self:set_mail_init_complete(true)
end

function imp_red_points.imp_red_points_init_from_other_game_dict(self,dict)
    self.offline_message = dict.offline_message
    self.friend_applicants = dict.friend_applicants
    self.unread_mail = dict.unread_mail
end

function imp_red_points.imp_red_points_write_to_other_game_dict(self,dict)
    dict.offline_message = self.offline_message
    dict.friend_applicants = self.friend_applicants
    dict.unread_mail = self.unread_mail
end

return imp_red_points

