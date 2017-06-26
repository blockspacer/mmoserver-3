--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/21 0021
-- Time: 10:27
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local online_user = require "fight_server/fight_server_online_user"
local entity_factory = require "entity_factory"
local flog = require "basic/log"
local qualifying_arena_fight_center = require "fight_server/qualifying_arena_fight_center"
local net_work = require "basic/net"
local fight_send_to_game = net_work.fight_send_to_game
local dogfight_arena_fight_center = require "fight_server/dogfight_arena_fight_center"
local task_dungeon_center = require "fight_server/task_dungeon_center"

fight_server_message_center = fight_server_message_center or {}
local fight_server_message_center = fight_server_message_center

function fight_server_message_center:on_game_message(game_id,key_action,input)
    if key_action == const.GD_MESSAGE_LUA_GAME_RPC then
        if input.func_name ~= nil then
            if input.func_name == "on_create_team_dungeon" then
                team_dungeon_center:create_team_dungeons(input)
            elseif input.func_name == "on_create_main_dungeon" then
                main_dungeon_center:create_main_dungeon(input)
            elseif input.func_name == "on_create_qualifying_arena" then
                local success = qualifying_arena_fight_center:create_qualifying_arena(input)
                fight_send_to_game(game_id,const.OG_MESSAGE_LUA_GAME_RPC,{actor_id=input.actor_id,func_name="on_create_qualifying_arena_complete",success=success})
            elseif input.func_name == "on_create_dogfight_arena" then
                input.game_id = game_id
                local success = dogfight_arena_fight_center:create_dogfight_arena(input)
                fight_send_to_game(game_id,const.GCA_MESSAGE_LUA_GAME_RPC,{func_name="on_create_dogfight_arena_complete",success=success,start_fight_time=dogfight_arena_fight_center:get_start_fight_time(input.fight_id),room_id=input.room_id})
            elseif input.func_name == "on_create_task_dungeon" then
                local success = task_dungeon_center:create_task_dungeon(input,game_id)
                if input.team_info == nil then
                    fight_send_to_game(game_id,const.OG_MESSAGE_LUA_GAME_RPC,{actor_id=input.actor_id,func_name="on_create_task_dungeon_complete",success=success,dungeon_id = input.dungeon_id,fight_id=input.fight_id,port=input.port,ip=input.ip,token=input.token,fight_server_id=input.fight_server_id,fight_type=input.fight_type})
                else
                    fight_send_to_game(game_id,const.GT_MESSAGE_LUA_GAME_RPC,{actor_id=input.actor_id,team_id=input.team_info.team_id,func_name="on_create_task_dungeon_complete",success=success,dungeon_id = input.dungeon_id,fight_id=input.fight_id,port=input.port,ip=input.ip,token=input.token,fight_server_id=input.fight_server_id,fight_type=input.fight_type})
                end
            elseif input.func_name == "on_new_player_enter_dogfight_arena" then
                dogfight_arena_fight_center:on_new_player_enter_dogfight_arena(input)
            else
                local fight_avatar = nil
                if input.func_name == "on_initialize_fight_avater" then
                    fight_avatar = online_user.get_user(input.actor_id)
                    if fight_avatar == nil then
                        fight_avatar = entity_factory.create_entity(const.ENTITY_TYPE_FIGHT_AVATAR)
                        online_user.add_user(input.actor_id,fight_avatar)
                        fight_avatar:set_src_game_id(game_id)
                        fight_avatar[input.func_name](fight_avatar,input)
                    else
                        fight_avatar:set_src_game_id(game_id)
                        flog("info","already have fight avatar,actor_id:"..input.actor_id)
                        fight_avatar[input.func_name](fight_avatar,input)
                    end
                else
                    if input.actor_ids ~= nil then
                        for i=1,#input.actor_ids,1 do
                            self:avatar_message(input.actor_ids[i],game_id,key_action,input)
                        end
                    else
                        self:avatar_message(input.actor_id,game_id,key_action,input)
                    end
                end
            end
        end
    end
end

function fight_server_message_center:avatar_message(actor_id,game_id,key_action,input)
    local fight_avatar = online_user.get_user(actor_id)
    if fight_avatar == nil then
        flog("info","fight_server_message_center:avatar_message can not find fight avatar in fight server!!!")
        return
    end
    fight_avatar:set_src_game_id(game_id)
    fight_avatar:on_message(key_action,input)
    if input.func_name == "on_logout" then
        online_user.del_user(input.actor_id)
    end
end

return fight_server_message_center

