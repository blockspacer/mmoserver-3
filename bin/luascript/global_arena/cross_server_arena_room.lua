--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/4/26 0026
-- Time: 16:44
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local challenge_arena = require "data/challenge_arena"
local matching_players = require "global_arena/cross_server_arena_matching_players"
local cross_server_arena_room_state = require "global_arena/cross_server_arena_room_state"
local challenge_arena_config = require "configs/challenge_arena_config"
local get_now_time_second = _get_now_time_second
local get_fight_server_info = require("basic/common_function").get_fight_server_info
local net_work = require "basic/net"
local send_message_to_fight = net_work.send_message_to_fight
local table = table

local arena_parameter = challenge_arena.Parameter

local first_arena_grade_id = 0
local arena_grade_configs = {}
for _,v in pairs(challenge_arena.QualifyingGrade) do
    arena_grade_configs[v.ID] = v
    if v.NextGrade == 0 then
        first_arena_grade_id = v.ID
    end
end

--竞技场段位索引，混战赛匹配使用
local tmp_grade_config = arena_grade_configs[first_arena_grade_id]
if tmp_grade_config == nil then
    flog("error","arena grade configs error!!")
end

local tmp_index = 1
local arena_grade_index = {}
while tmp_grade_config ~= nil do
    arena_grade_index[tmp_grade_config.ID]=tmp_index
    tmp_index = tmp_index + 1
    if tmp_grade_config.ExGrade ~= tmp_grade_config.ID then
        tmp_grade_config = arena_grade_configs[tmp_grade_config.ExGrade]
    end
end

--混战赛匹配表
local arena_dogfight_matching_configs = {}
local arena_dogfight_matching_create_time = {}
for _,v in pairs(challenge_arena.Matching2) do
    arena_dogfight_matching_configs[v.CreateTime] = v
    table.insert(arena_dogfight_matching_create_time,v.CreateTime)
end

table.sort(arena_dogfight_matching_create_time)

local function get_dogfight_matching_config(create_time)
    local limit = 0
    for i=1,#arena_dogfight_matching_create_time,1 do
        if arena_dogfight_matching_create_time[i] < create_time then
            limit = arena_dogfight_matching_create_time[i]
        else
            break
        end
    end
    return arena_dogfight_matching_configs[limit]
end

local agree_time = 30

local cross_server_arena_room = {}
cross_server_arena_room.__index = cross_server_arena_room

setmetatable(cross_server_arena_room, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function cross_server_arena_room.__ctor(self,room_id,grade_id,current_time)
    self.room_id = room_id
    self.grade_id = grade_id
    self.actors = {}
    self.count = 0
    self.create_time = current_time
    self.close = false
    self.start_fight_time = current_time
    self.ready_time = 0
    self.room_timer = nil
    self.scene_id = 0
    self.state = cross_server_arena_room_state.matching
    self.agree_end_time = 0
    flog("tmlDebug","create new room!room_id:"..room_id..",grade_id:"..grade_id..",current_time:"..current_time)
    --战斗服信息
    self.ip = ""
    self.port = 0
    self.fight_id = ""
    self.token = ""
    self.fight_server_id = 0
end

--加入新玩家
function cross_server_arena_room.add_player(self,actor_id,current_time)
    flog("tmlDebug","cross_server_arena_room.add_player,actor_id:"..actor_id)
    local player = matching_players.get_user(actor_id)
    if player == nil then
        flog("warn","cross_server_arena_room|add_player can not find player,actor_id="..actor_id)
        return
    end

    if self.actors[actor_id] ~= nil then
        return
    end

    self.actors[actor_id] = {}
    self.actors[actor_id].agree = false
    self.count = self.count + 1
    if self:check_room_close(current_time) then
        self:set_close_state(true)
    end

    player:send_message_to_game({func_name="arena_dogfight_matching_successs",room_id=self.room_id})
    if self.state ~= cross_server_arena_room_state.matching then
        player:request_agree(self.room_id,current_time + agree_time)
    end
end

local function remove_player_internal(self,actor_id)
    flog("tmlDebug","arena_dogfight_room.remove_player_internal")
    if self.actors[actor_id] ~= nil then
        self.actors[actor_id] = nil
        self.count = self.count - 1
        if self.state == cross_server_arena_room_state.agree then
            self:check_agree()
        end
        return true
    end
    return false
end

--玩家离开
function cross_server_arena_room.remove_player(self,actor_id)
    flog("tmlDebug","arena_dogfight_room.remove_player")
    return remove_player_internal(self,actor_id)
end

--判断是否可以关闭房间
function cross_server_arena_room.check_room_close(self,current_time)
    if self.ready_time > 0 then
        --开战后一段时间房间关闭
        if current_time - self.ready_time > arena_parameter[26].Value[1] then
            return true
        end
    elseif self.count >= arena_parameter[25].Value[1] then
        return true
    end
    return false
end

--设置房间关闭状态
function cross_server_arena_room.set_close_state(self,close)
    self.close = close
end

--获取房间关闭状态
function cross_server_arena_room.is_close(self)
    return self.close
end

--获取房间开战状态
function cross_server_arena_room.get_fighting_state(self)
    return self.fighting
end

--判断是否可以开始战斗
function cross_server_arena_room.check_room_can_start(self,current_time)
    flog("tmlDebug","arena_dogfight_room.check_room_can_start,current_time:"..current_time..",self.create_time:"..self.create_time)
    if self.state ~= cross_server_arena_room_state.matching then
        return false
    end

    local dogfight_matching_config = get_dogfight_matching_config(current_time - self.create_time)
    if dogfight_matching_config ~= nil then
        flog("tmlDebug","find dogfight_matching_config,self.count:"..self.count..",dogfight_matching_config.PlayerNum:"..dogfight_matching_config.PlayerNum)
        if self.count >= dogfight_matching_config.PlayerNum then
            return true
        end
    end
    return false
end

--开始确认
function cross_server_arena_room.start_fight(self,current_time)
    flog("tmlDebug","arena_dogfight_room.start_fight")
    self.state = cross_server_arena_room_state.agree
    local agree_end_time = get_now_time_second() + agree_time
    flog("tmlDebug","agree_end_time "..agree_end_time..",current_time "..current_time)
    for actor_id,_ in pairs(self.actors) do
        local player = matching_players.get_user(actor_id)
        if player ~= nil then
            player:request_agree(agree_end_time)
        end
    end
end

--检查确认状态
function cross_server_arena_room.check_agree(self)
    flog("tmlDebug","arena_dogfight_room.check_agree")
    if self.state ~= cross_server_arena_room_state.agree then
        return false
    end

    if table.isEmptyOrNil(self.actors) then
        cross_server_arena_matching_center.destroy_room(self.room_id)
        return
    end

    local agree_count = 0
    local player_count = 0
    for _,actor in pairs(self.actors) do
        if actor.agree then
            agree_count = agree_count + 1
        end
        player_count = player_count + 1
    end

    if agree_count >= challenge_arena_config.get_arena_dogfight_min_player_count() then
        self:start_create_scene()
    elseif player_count < challenge_arena_config.get_arena_dogfight_min_player_count() then
        self.state = cross_server_arena_room_state.agree_fail
        for actor_id,_ in pairs(self.actors) do
            local player = matching_players.get_user(actor_id)
            if player ~= nil then
                player:send_message_to_game({func_name="dogfight_matching_fail_because_player_not_enough"})
            end
        end
    end
    return true
end

function cross_server_arena_room.player_agree(self,actor_id)
    flog("tmlDebug","arena_dogfight_room.player_agree")
    local player = matching_players.get_user(actor_id)
    if player == nil then
        return
    end

    if self.actors[actor_id] ~= nil then
        --开始确认之后进入的玩家，确认时可能此房间已经重新回到匹配状态
        if self.state == cross_server_arena_room_state.agree_fail then
            player:send_message_to_game({func_name="player_agree_arena_reply",result=const.error_dogfight_arena_player_not_enough})
            return
        end
        self.actors[actor_id].agree = true
        if self.state == cross_server_arena_room_state.ready or self.state == cross_server_arena_room_state.fighting then
            send_message_to_fight( self.fight_server_id, const.GD_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "on_new_player_enter_dogfight_arena",fight_id=self.fight_id,actors={[actor_id]={actor_name=player.actor_name,vocation=player.vocation}}})
            self:player_connet_fight_server(actor_id)
        else
            self:check_agree()
            player:send_message_to_game({func_name="player_agree_arena_reply",result=0})
        end
    end
end

function cross_server_arena_room.start_create_scene(self)
    flog("tmlDebug","arena_dogfight_room.start_create_scene")
    flog("tmlDebug","player count:"..self.count)
    self.state = cross_server_arena_room_state.create
    local fight_server_id,ip,port,token,fight_id = get_fight_server_info(const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA)
    if fight_server_id == nil then
        return false
    end
    self.fight_server_id = fight_server_id
    self.ip = ip
    self.port = port
    self.token = token
    self.fight_id = fight_id
    send_message_to_fight( fight_server_id, const.GD_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "on_create_dogfight_arena",room_id=self.room_id,grade_id=self.grade_id,fight_id=fight_id,token=token,fight_type=const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA})
end

function cross_server_arena_room.on_create_dogfight_arena_complete(self,success,start_fight_time)
    flog("tmlDebug","arena_dogfight_room.on_create_dogfight_arena_complete ,success is "..tostring(success))
    self.ready_time = get_now_time_second()
    local player = nil
    if success == true then
        self.start_fight_time = start_fight_time
        self.state = cross_server_arena_room_state.ready
        local actors = {}
        for actor_id,actor in pairs(self.actors) do
            if actor.agree then
                player = matching_players.get_user(actor_id)
                if player ~= nil then
                    actors[actor_id] = {}
                    actors[actor_id].actor_name = player.actor_name
                    actors[actor_id].vocation = player.vocation
                else
                    flog("warn","cross_server_arena_room.on_create_dogfight_arena_complete can not find player!")
                end
            end
        end
        send_message_to_fight( self.fight_server_id, const.GD_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "on_new_player_enter_dogfight_arena",fight_id=self.fight_id,actors=actors})
        for actor_id,_ in pairs(actors) do
            self:player_connet_fight_server(actor_id)
        end
    else
        for actor_id,_ in pairs(self.actors) do
            player = matching_players.get_user(actor_id)
            if player ~= nil then
                player:send_message_to_game({func_name="create_dogfight_scene_fail"})
            end
        end
    end
end

function cross_server_arena_room.player_connet_fight_server(self,actor_id)
    local player = matching_players.get_user(actor_id)
    if player ~= nil then
        player:send_message_to_game({func_name="create_dogfight_scene_success",fight_server_id=self.fight_server_id,ip=self.ip,port=self.port,token=self.token,fight_id=self.fight_id})
    end
end

function cross_server_arena_room.on_dogfight_arena_start_fight(self)
    self.state = cross_server_arena_room_state.fighting
end

--判断是否可加入
function cross_server_arena_room.check_can_join_in_room(self,current_time,grade_id)
    flog("tmlDebug","arena_dogfight_room.check_can_join_in_room,current_time:"..current_time..",grade_id:"..grade_id..",create_time:"..self.create_time)
    local dogfight_matching_config = get_dogfight_matching_config(current_time - self.create_time)
    if dogfight_matching_config ~= nil and arena_grade_index[grade_id] ~= nil and arena_grade_index[self.grade_id] ~= nil then
        if arena_grade_index[self.grade_id] + dogfight_matching_config.GradeVariation >= arena_grade_index[grade_id] and arena_grade_index[grade_id] >= arena_grade_index[self.grade_id] - dogfight_matching_config.GradeVariation then
            flog("tmlDebug","can join in room!!!")
            return true
        end
    end
    flog("tmlDebug","can not join in room!!!")
    return false
end

--获取人数
function cross_server_arena_room.get_count(self)
    return self.count
end

function cross_server_arena_room.arena_dogfight_fightover(self,score_data)
    flog("tmlDebug","arena_dogfight_room.arena_dogfight_fightover")
    local player = nil
    for actor_id,_ in pairs(self.actors) do
        player = matching_players.get_user(actor_id)
        if player ~= nil then
            player:send_message_to_game({func_name="arena_dogfight_fightover",score_data=score_data})
        end
    end
    self.state = cross_server_arena_room_state.done
end

function cross_server_arena_room.get_room_create_time(self)
    return self.create_time
end

function cross_server_arena_room.get_state(self)
    return self.state
end

function cross_server_arena_room.can_destroy(self)
    if self.state == cross_server_arena_room_state.fighting or self.state == cross_server_arena_room_state.ready then
        return false
    end
    if self.count > 0 then
        return false
    end
    return true
end

function cross_server_arena_room.update(self,current_time)
    if self.state == cross_server_arena_room_state.matching and self:check_room_can_start(current_time) then
        self:start_fight(current_time)
        cross_server_arena_matching_center.on_set_predict_dogfight_matching_time(current_time - self:get_room_create_time())
    end
    if self:is_close() == false then
        if self:check_room_close(current_time) then
            self:set_close_state(true)
        end
    end
end

function cross_server_arena_room.is_have_actor(self,actor_id)
    if self.actors[actor_id] == nil then
        return false
    end
    return true
end

function cross_server_arena_room.get_room_id(self)
    return self.room_id
end

return cross_server_arena_room

