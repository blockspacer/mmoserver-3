--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/13 0013
-- Time: 18:33
-- To change this template use File | Settings | File Templates.
--
local flog = require "basic/log"
local fight_server_center = require "fight_server/fight_server_center"
local get_now_time_second = _get_now_time_second
local const = require "Common/constant"
local entity_factory = require "entity_factory"
local challenge_arena_config = require "configs/challenge_arena_config"
local online_user = require "fight_server/fight_server_online_user"
local dogfight_arena_fight_room_player = require "fight_server/dogfight_arena_fight_room_player"
require "Common/combat/Entity/EntityManager"
local table = table
local net_work = require "basic/net"
local fight_send_to_game = net_work.fight_send_to_game
local math_random = math.random
local math_ceil = math.ceil

local EntityType = EntityType

local ArenaState =
{
    no_start = 1,       --未开始
    playing = 2,        --进行中
    over = 3,           --已结束
    done = 4,           --已完成
}

local dogfight_arena_fight_room = {}
dogfight_arena_fight_room.__index = dogfight_arena_fight_room

setmetatable(dogfight_arena_fight_room, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {
}
dogfight_arena_fight_room.__params = params


function dogfight_arena_fight_room.__ctor(self,data)
    self.dirty = false
    self.fight_id = data.fight_id
    self.start_time = get_now_time_second()
    self.end_time = self.start_time + challenge_arena_config.get_dogfight_arena_duration()
    self.grade_id = data.grade_id
    self.state = ArenaState.no_start
    self.room_id = data.room_id
    --匹配混战赛服务器id
    self.game_id = data.game_id
    self.start_fight_time = self.start_time + challenge_arena_config.get_dogfight_arena_fight_ready_time()
    self.born_index = 0             --玩家出生位置
    self.members = {}
    self.score_data = {}
    local fight_members = {}
    self.player_count = 0
    fight_server_center:add_fight(data.fight_id,data.token,data.fight_type,fight_members)
    return true
end

function dogfight_arena_fight_room.initialize(self)
    self.aoi_scene_id = arena_scene_manager.create_dogfight_scene(self.fight_id)
    local scene = arena_scene_manager.find_scene(self.aoi_scene_id)
    if scene == nil then
        return false
    end
    scene:set_start_fight_time(self.start_fight_time)
    scene:set_game_id(self.game_id)
    scene:set_room_id(self.room_id)
    scene:set_grade_id(self.grade_id)
    return true
end

function dogfight_arena_fight_room.update(self,current_time)
    if self.state == ArenaState.over or self.state == ArenaState.done then
        return
    end

    if current_time > self.end_time then
        self.state = ArenaState.over
        local arena_grade_config = challenge_arena_config.get_arena_grade_config(self.grade_id)
        if arena_grade_config ~= nil then
            self.dirty = true
            if arena_grade_config.MeleeReward1[2] ~= nil then
                for _,actor in pairs(self.members) do
                    actor:add_scene_score(arena_grade_config.MeleeReward1[2])
                end
            end
        end

        local scene = arena_scene_manager.find_scene(self.aoi_scene_id)
        if scene ~= nil then
            scene:SetAllEntityEnabled(false)
            scene:SetAllEntityAttackStatus(false)
        end
    end

    if self.dirty == true then
        local actors = {}
        for _,actor in pairs(self.members) do
            table.insert(actors,actor)
        end
        if #actors > 1 then
            table.sort(actors,function(a,b)
                return a:get_session_score() >= b:get_session_score()
            end)
        end
        self.score_data = {}
        for i=1,#actors,1 do
            actors[i].rank = i
            self.score_data[i]={actor_id=actors[i].actor_id,actor_name=actors[i].actor_name,vocation=actors[i].vocation,rank=actors[i].rank,scene_score=actors[i].scene_score,plunder_score=actors[i].plunder_score,total_score=actors[i].session_score}
        end
    end
end

function dogfight_arena_fight_room.check_members(self,actor_id)
    if self.members[actor_id] ~= nil then
        return true
    end
    return false
end

function dogfight_arena_fight_room.get_aoi_scene_id(self)
    return self.aoi_scene_id
end

function dogfight_arena_fight_room.is_over(self)
    return self.state == ArenaState.over
end

function dogfight_arena_fight_room.dogfight_arena_fight_over(self)
    if self.state == ArenaState.done then
        return
    end

    self.state = ArenaState.done
    for _,actor_score in pairs(self.score_data) do
        local actor = self.members[actor_score.actor_id]
        if actor ~= nil and actor.arena_address ~= nil then
            fight_send_to_game(actor.arena_address,const.SA_MESSAGE_LUA_GAME_ARENA_RPC,{func_name="on_dogfight_arena_fight_over_score",total_score=actor_score.total_score})
        end
    end
    fight_send_to_game(self.game_id,const.GCA_MESSAGE_LUA_GAME_RPC,{func_name="on_dogfight_arena_fight_over",room_id=self.room_id,score_data=table.copy(self:get_score_data())})
end

function dogfight_arena_fight_room.is_all_player_leave(self)
    if self.state ~= ArenaState.done then
        return false
    end

    local scene = arena_scene_manager.find_scene(self.aoi_scene_id)
    if scene ~= nil then
        return scene:is_all_player_leave()
    end
    return false
end

function dogfight_arena_fight_room.destroy(self)
    if self.aoi_scene_id ~= nil then
        local scene = arena_scene_manager.find_scene(self.aoi_scene_id)
        if scene ~= nil then
            scene:set_scene_state(const.SCENE_STATE.done)
        end
        self.aoi_scene_id = nil
    end
end

function dogfight_arena_fight_room.get_start_fight_time(self)
    return self.start_fight_time
end

function dogfight_arena_fight_room.leave_dogfight_arena_fight_room(self,actor_id)
    flog("tmlDebug","dogfight_arena_fight_room.leave_dogfight_arena_fight_room")
    local player = self.members[actor_id]
    if player ~= nil then
        player:set_leave_state(true)
    end
end

function dogfight_arena_fight_room.get_born_pos(self)
    self.born_index = self.born_index + 1
    return arena_scene_manager.get_dogfight_scene_born_pos(self.born_index)
end

function dogfight_arena_fight_room.get_room_id(self)
    return self.room_id
end

function dogfight_arena_fight_room.get_countdown(self)
    return self.end_time - get_now_time_second()
end

function dogfight_arena_fight_room.player_enter_scene(self,actor_id,arena_total_score,arena_address)
    local player = self.members[actor_id]
    if player == nil then
        return
    end
    player:set_total_score(arena_total_score)
    player:set_arena_address(arena_address)
    player:set_leave_state(false)
end

function dogfight_arena_fight_room.add_dogfight_occupy_score(self,actor_id,score)
    flog("tmlDebug","dogfight_arena_fight_room.add_dogfight_occupy_score")
    if self.state == ArenaState.over or self.state == ArenaState.done then
        return
    end
    local player = self.members[actor_id]
    if player == nil then
        return
    end
    player:add_scene_score(score)
    player:score_change(score,nil)
    self.dirty = true
end

function dogfight_arena_fight_room.kill_entity(self,killer_id,loser_type,loser_id)
    flog("tmlDebug","dogfight_arena_fight_room.kill_entity")
    if self.state == ArenaState.over or self.state == ArenaState.done then
        return
    end

    local killer = self.members[killer_id]
    if killer == nil then
        flog("tmlDebug","dogfight_arena_fight_room.kill_entity killer==nil killer_id:"..killer_id)
        return
    end

    local arena_grade_config = challenge_arena_config.get_arena_grade_config(self.grade_id)
    if arena_grade_config == nil then
        flog("tmlDebug","arena_center.on_kill_entity arena_grade_config==nil grade_id:"..self.grade_id)
        return
    end

    local killer_addon = 0
    local loser_addon = 0
    local loser_name = nil
    if loser_type == const.ENTITY_TYPE_MONSTER then
        if arena_grade_config.Reward14[2] ~= nil then
            killer:add_scene_score(arena_grade_config.Reward14[2])
            killer_addon = killer_addon + arena_grade_config.Reward14[2]
            self.dirty = true
        end
    else
        if arena_grade_config.Reward13[2] ~= nil then
            killer:add_scene_score(arena_grade_config.Reward13[2])
            killer_addon = killer_addon + arena_grade_config.Reward13[2]
            self.dirty = true
        end
        local loser = self.members[loser_id]
        if loser ~= nil then
            loser:add_die_count()
            local arena_plunder_score_config = challenge_arena_config.get_arena_plunder_score_config(loser:get_die_count())
            if arena_plunder_score_config ~= nil then
                local random_ratio = math_random(arena_plunder_score_config.Plunderlowlimit,arena_plunder_score_config.Plunderuplimit)
                flog("tmlDebug","random_ratio "..random_ratio..",total_score "..loser:get_total_score())
                local plunder_score = math_ceil(loser:get_total_score()*random_ratio/10000)
                if plunder_score < 0 then
                    plunder_score = 0
                end
                killer:add_plunder_score(plunder_score)
                killer_addon = killer_addon + plunder_score
                loser:add_plunder_score(-plunder_score)
                loser_addon = loser_addon - plunder_score
                self.dirty = true
            else
                flog("tmlDebug","can not find arena_plunder_score_config,die_count "..loser:get_die_count())
            end
            loser_name = loser.actor_name
            loser:score_change(loser_addon,killer.actor_name)
        else
            flog("tmlDebug","can not find loser,loser id "..loser_id)
        end
    end
    killer:score_change(killer_addon,loser_name)
end

function dogfight_arena_fight_room.get_score_data(self)
    flog("tmlDebug","dogfight_arena_fight_room.get_score_data")
    return self.score_data
end

function dogfight_arena_fight_room.on_new_player_enter_dogfight_arena(self,actor_id,actor_name,vocation)
    flog("tmlDebug","dogfight_arena_fight_room.on_new_player_enter_dogfight_arena")
    if self.members[actor_id] ~= nil then
        return
    end
    self.player_count = self.player_count + 1
    self.members[actor_id] = dogfight_arena_fight_room_player(actor_id,actor_name,vocation,self.player_count)
    self.dirty = true
end

function dogfight_arena_fight_room.check_fight_over(self)
    return self.state == ArenaState.over or self.state == ArenaState.done
end

return dogfight_arena_fight_room

