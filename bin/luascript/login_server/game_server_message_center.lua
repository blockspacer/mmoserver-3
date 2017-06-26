--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/21 0021
-- Time: 13:46
-- To change this template use File | Settings | File Templates.
--

local online_user = require "onlinerole"
local flog = require "basic/log"
local const = require "Common/constant"
local center_server_manager = require "center_server_manager"
local line = require "global_line/line"

game_server_message_center = game_server_message_center or {}
local game_server_message_center = game_server_message_center

local service_rpc = {[const.SERVICE_TYPE.team_service]=const.GT_MESSAGE_LUA_GAME_RPC}

function game_server_message_center:on_fight_server_message(game_id,key_action,input)
    --临时转接
    if input.service_type ~= nil then
        local avatar = online_user.get_user(input.actor_id)
        if avatar ~= nil then
            center_server_manager.send_message_to_center_server(input.service_type,service_rpc[input.service_type],input)
        else
            flog("tmlDebug","game_server_message_center:on_fight_server_message can not find avatar!server name:"..input.server_name)
        end
        return
    end
    if input.func_name ~= nil then
        if self[input.func_name] ~= nil then
            self[input.func_name](input)
            return
        end
        if input.actor_ids ~= nil then
            for i=1,#input.actor_ids,1 do
                self:avatar_message(input.actor_ids[i],key_action,input)
            end
        elseif input.actor_id ~= nil then
            self:avatar_message(input.actor_id,key_action,input)
        end
    end
end

function game_server_message_center.on_create_scene(input)
    local result = normal_scene_manager.create_scene(input.scene_id)
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.line_service,const.SL_MESSAGE_LUA_GAME_RPC,{func_name="on_create_scene_ret",result = result,scene_id=input.scene_id,game_id=_get_serverid()})
end

function game_server_message_center.on_start_pre_close_scene(input)
    local scene = normal_scene_manager.find_scene(input.scene_id)
    local count = 0
    if scene == nil then
        normal_scene_manager.create_scene(input.scene_id)
    else
        count = scene:get_player_count()
    end
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.line_service,const.SL_MESSAGE_LUA_GAME_RPC,{func_name="on_start_pre_close_scene_ret",result = 0,scene_id=input.scene_id,count=count})
end

function game_server_message_center.on_destroy_pre_close_scene(input)
    local scene = normal_scene_manager.find_scene(input.scene_id)
    if scene ~= nil and scene:get_player_count() <= 0 then
        normal_scene_manager.destroy_scene(input.scene_id)
    end
end

function game_server_message_center.on_update_game_line_info(input)
    line.on_update_game_line_info(input)
end

function game_server_message_center.on_create_faction_scene(input)
    if faction_scene_manager == nil then
        faction_scene_manager = require "scene/faction_scene_manager"
    end
    local result,aoi_scene_id = faction_scene_manager.create_scene(input.faction_id,input.country)
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.faction_service,const.GF_MESSAGE_LUA_GAME_RPC,{func_name="on_create_faction_scene_ret",result = result,faction_id=input.faction_id,aoi_scene_id=aoi_scene_id})
end

function game_server_message_center:avatar_message(actor_id,key_action,input)
    local avatar = online_user.get_user(actor_id)
    if avatar == nil then
        flog("info","can not find avatar in game server!!!")
        return
    end
    avatar:on_message(key_action,input)
end

return game_server_message_center