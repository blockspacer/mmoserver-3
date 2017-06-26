--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/20 0020
-- Time: 9:28
-- To change this template use File | Settings | File Templates.
--

local decode_client_data = require("basic/net").decode_client_data
local flog = require "basic/log"
local const = require "Common/constant"
local mail_center = require "global_mail/mail_center"

--处理新客户端连接
local function on_connect(session_id)

end

--处理客户端断开
local function on_close(session_id)

end

--处理客户端发来的消息
local function on_message( key_action, data, game_id)
    if key_action ~= const.OM_MESSAGE_LUA_GAME_RPC then
        return
    end

    data = decode_client_data(data)
    mail_center:on_message(data)
end

local function on_server_stop()
    flog("info", "mail server on_server_stop")
    mail_center:on_server_stop()
end

function MailUserManageReadyClose()
    flog("info", "MailUserManageReadyClose")
    IsServerModuleReadyClose(const.SERVICE_TYPE.mail_service)
end

return {
    on_connect = on_connect,
    on_close = on_close,
    on_message = on_message,
    on_server_stop = on_server_stop,
}

