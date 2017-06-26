--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/28 0028
-- Time: 15:02
-- To change this template use File | Settings | File Templates.
--
local forward_message_to_game = require("basic/net").forward_message_to_game
local flog = require "basic/log"
local const = require "Common/constant"

local services = {}

local function on_register_service(game_id,service_type)
    _info("service type "..service_type.." register on game "..game_id)
    services[service_type] = {game_id=game_id }
    if _get_serverid() ~= game_id then
        return
    end
    if service_type == const.SERVICE_TYPE.arena_service then
        services[service_type].user_manager = require "global_arena/arena_user_manager"
    elseif service_type == const.SERVICE_TYPE.country_service then
        services[service_type].user_manager = require "global_country/country_user_manage"
    elseif service_type == const.SERVICE_TYPE.faction_service then
        services[service_type].user_manager = require "global_faction/faction_user_manage"
    elseif service_type == const.SERVICE_TYPE.mail_service then
        services[service_type].user_manager = require "global_mail/mail_user_manager"
    elseif service_type == const.SERVICE_TYPE.ranking_service then
        services[service_type].user_manager = require "global_ranking/ranking_user_manage"
    elseif service_type == const.SERVICE_TYPE.shop_service then
        services[service_type].user_manager = require "global_shop/shop_user_manager"
    elseif service_type == const.SERVICE_TYPE.team_service then
        services[service_type].user_manager = require "global_team/team_user_manage"
    elseif service_type == const.SERVICE_TYPE.friend_service then
        services[service_type].user_manager = require "global/global_user_manager"
    elseif service_type == const.SERVICE_TYPE.cross_server_arena_service then
        services[service_type].user_manager = require "global_arena/cross_server_arena_user_manager"
    elseif service_type == const.SERVICE_TYPE.line_service then
        services[service_type].user_manager = require "global_line/line_manager"
    end
end

local function on_register_services(game_id,services)

end

local function on_unregister_service(service_type)
    services[service_type] = nil
end

local function on_unregister_services(input)
end

local function send_message_to_center_server(service_type,key_action,data)
    if services[service_type] == nil then
        flog("error","can not find service type "..service_type)
        return
    end
    forward_message_to_game(services[service_type].game_id,key_action,data)
end

local function on_message(game_id, key_action, data,src_server_id)
    for _,service in pairs(services) do
        if service.game_id == game_id and service.user_manager ~= nil then
            service.user_manager.on_message(key_action, data,src_server_id)
        end
    end
end

local function on_close(game_id,session_id)
    for _,service in pairs(services) do
        if service.game_id == game_id and service.user_manager ~= nil then
            service.user_manager.on_close(session_id)
        end
    end
end

local close_service_hash = {}
function IsServerModuleReadyClose(service_type)
    if service_type ~= nil then
        close_service_hash[service_type] = nil
    end

    flog("info", "UserManageReadyClose close_service_hash "..table.serialize(close_service_hash))
    if table.isEmptyOrNil(close_service_hash) then
        AllModuleReadyClose()
    end
end


local function on_server_stop(game_id)
    for service_type,service in pairs(services) do
        if service.game_id == game_id and service.user_manager ~= nil and service.user_manager.on_server_stop ~= nil then
            close_service_hash[service_type] = true
        end
    end
    flog("info", "UserManageReadyClose start, close_service_hash "..table.serialize(close_service_hash))
    for service_type,service in pairs(services) do
        if service.game_id == game_id and service.user_manager ~= nil and service.user_manager.on_server_stop ~= nil then
            service.user_manager.on_server_stop()
        end
    end
    IsServerModuleReadyClose()
end

local function on_get_service_address(service_type)
    if services[service_type] == nil then
        return nil
    end
    return services[service_type].game_id
end

local function on_update_games_info(games_info)
    for service_type,service in pairs(services) do
        if service.user_manager ~= nil and service.user_manager.on_update_games_info ~= nil then
            service.user_manager.on_update_games_info(games_info)
        end
    end
end

return {
    on_register_service = on_register_service,
    on_register_services = on_register_services,
    on_unregister_service = on_unregister_service,
    on_unregister_services = on_unregister_services,
    send_message_to_center_server = send_message_to_center_server,
    on_message = on_message,
    on_close = on_close,
    on_server_stop = on_server_stop,
    on_get_service_address = on_get_service_address,
    on_update_games_info = on_update_games_info,
}

