--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/4/26 0026
-- Time: 15:08
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local matching_players = require "global_arena/cross_server_arena_matching_players"
local timer = require "basic/timer"
local _get_now_time_second = _get_now_time_second
local match_player = require "global_arena/cross_server_arena_player"
local cross_server_arena_room = require "global_arena/cross_server_arena_room"
local challenge_arena_config = require "configs/challenge_arena_config"

local rooms = {}
local predict_dogfight_matching_time = 300
local waiting_players = {}

local dogfight_room_id = 1
local function get_dogfight_room_id()
    dogfight_room_id = dogfight_room_id + 1
    if dogfight_room_id > 100000000 then
        dogfight_room_id = 1
    end
    return dogfight_room_id
end

local function destroy_room(room_id)
    if rooms[room_id] ~= nil then
        rooms[room_id] = nil
    end
end

local function leave_dogfight_matching(actor_id)
    flog("tmlDebug","cross_server_arena_matching_center|leave_dogfight_matching")
    waiting_players[actor_id] = nil
    local player = matching_players.get_user(actor_id)
    if player ~= nil then
        local romm_id = player:get_room_id()
        local room = rooms[romm_id]
        if room ~= nil and room:remove_player(actor_id) then
            if room:can_destroy() then
                destroy_room(romm_id)
            end
        end
    end
end

local function on_create_dogfight_arena_complete(input,game_id)
    flog("tmlDebug","cross_server_arena_matching_center|on_create_dogfight_arena_complete")
    if input.room_id == nil then
        return
    end
    if rooms[input.room_id] == nil then
        return
    end
    rooms[input.room_id]:on_create_dogfight_arena_complete(input.success,input.start_fight_time)
end

local function on_dogfight_arena_fight_over(input,game_id)
    if input.room_id == nil then
        return
    end

    local room = rooms[input.room_id]
    if room == nil then
        return
    end
    room:arena_dogfight_fightover(input.score_data)
end

local function try_matching(actor_id,grade_id,current_time)
    flog("tmlDebug","cross_server_arena_matching_center.try_matching,actor_id:"..actor_id..",grade_id:"..grade_id..",current_time:"..current_time)
    for _,room in pairs(rooms) do
        if not room:is_close() then
            if room:check_can_join_in_room(current_time,grade_id) then
                room:add_player(actor_id,current_time)

                if room:check_room_can_start(current_time) then
                    room:start_fight(current_time)
                    predict_dogfight_matching_time = current_time - room:get_room_create_time()
                end

                return true
            end
        end
    end
    return false
end

local function on_player_start_matching(input,game_id)
    if input.actor_id == nil then
        return
    end
    local actor_id = input.actor_id
    local player = matching_players.get_user(actor_id)
    if player ~= nil then
        local room_id = player:get_room_id()
        if room_id > 0 then
            if rooms[room_id] ~= nil and rooms[room_id]:is_have_actor() then
                flog("warn","player should not matching when start matching!!!actor_id="..actor_id)
                player:send_message_to_game({func_name="on_player_start_matching_reply",result=const.error_arena_dogfight_matching})
                return
            end
        end
        player:init(game_id,actor_id,input.actor_name,input.vocation,input.grade_id)
    else
        player = match_player(game_id,actor_id,input.actor_name,input.vocation,input.grade_id)
        matching_players.add_user(actor_id,player)
    end

    local current_time = _get_now_time_second()
    if not try_matching(actor_id,input.grade_id,current_time) then
        flog("tmlDebug","can not matching room,waiting!!!")
        waiting_players[actor_id] = {}
        waiting_players[actor_id].actor_id = actor_id
        waiting_players[actor_id].grade_id = input.grade_id
        waiting_players[actor_id].start_time = current_time
    end
    player:send_message_to_game({func_name="on_player_start_matching_reply",result=0,predict_dogfight_matching_time=predict_dogfight_matching_time})
end

local function update()
    local current_time = _get_now_time_second()
    for _,room in pairs(rooms) do
        room:update(current_time)
    end
    --等待分配的人
    for _,player in pairs(waiting_players) do
        if try_matching(player.actor_id,player.grade_id,current_time) then
            flog("tmlDebug","join dogfight room")
            waiting_players[player.actor_id] = nil
        elseif current_time - player.start_time > challenge_arena_config.get_dogfight_wait_time() then
            flog("tmlDebug","create new room")
            waiting_players[player.actor_id] = nil
            local room_id = get_dogfight_room_id()
            while rooms[room_id] ~= nil do
                room_id = get_dogfight_room_id()
            end
            rooms[room_id] = cross_server_arena_room(room_id,player.grade_id,current_time)
            rooms[room_id]:add_player(player.actor_id,player.grade_id,current_time)
        end
    end
end

local function on_server_start()
    timer.create_timer(update,1000,const.INFINITY_CALL)
end

local function on_set_predict_dogfight_matching_time(time)
    predict_dogfight_matching_time = time
end

local function on_notice_can_not_connect_dogfight_fight_server(input)
    leave_dogfight_matching(input.actor_id)
    matching_players.del_user(input.actor_id)
end

local function on_dogfight_arena_start_fight(input)
    if input.room_id == nil then
        return
    end
    if rooms[input.room_id] == nil then
        return
    end
    rooms[input.room_id]:on_dogfight_arena_start_fight()
end

local function player_agree_arena(input)
    if input.room_id ~= nil and rooms[input.room_id] ~= nil then
        rooms[input.room_id]:player_agree(input.actor_id)
    end
end

local function cancel_dogfight_matching(input)
    local result = 0
    leave_dogfight_matching(input.actor_id)
    if not input.quit then
        local player = matching_players.get_user(input.actor_id)
        if player ~= nil then
            player:send_message_to_game({result=result,func_name="reply_cancel_dogfight_matching"})
        end
    end
    matching_players.del_user(input.actor_id)
end

local function on_arena_player_logout(input)
    leave_dogfight_matching(input.actor_id)
    matching_players.del_user(input.actor_id)
end

return {
    on_create_dogfight_arena_complete = on_create_dogfight_arena_complete,
    on_dogfight_arena_fight_over = on_dogfight_arena_fight_over,
    on_player_start_matching = on_player_start_matching,
    on_server_start = on_server_start,
    on_set_predict_dogfight_matching_time = on_set_predict_dogfight_matching_time,
    destroy_room = destroy_room,
    on_notice_can_not_connect_dogfight_fight_server = on_notice_can_not_connect_dogfight_fight_server,
    on_dogfight_arena_start_fight = on_dogfight_arena_start_fight,
    player_agree_arena = player_agree_arena,
    on_arena_player_logout =on_arena_player_logout,
    cancel_dogfight_matching = cancel_dogfight_matching,
}