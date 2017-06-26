--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/9 0009
-- Time: 17:53
-- To change this template use File | Settings | File Templates.
--

local flog = require "basic/log"
local fight_server_center = require "fight_server/fight_server_center"
local get_now_time_second = _get_now_time_second
local const = require "Common/constant"
local entity_factory = require "entity_factory"
local challenge_arena_config = require "configs/challenge_arena_config"
local online_user = require "fight_server/fight_server_online_user"
require "Common/combat/Entity/EntityManager"

local EntityType = EntityType

local ArenaState =
{
    no_start = 1,       --未开始
    playing = 2,        --进行中
    over = 3,           --已结束
    done = 4,           --已完成
}

local qualifying_arena_fight_room = {}
qualifying_arena_fight_room.__index = qualifying_arena_fight_room

setmetatable(qualifying_arena_fight_room, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {
}
qualifying_arena_fight_room.__params = params


function qualifying_arena_fight_room.__ctor(self,data)
    self.fight_id = data.fight_id
    self.start_time = get_now_time_second()
    self.end_time = self.start_time + challenge_arena_config.get_qualifying_arena_fight_ready_time() +challenge_arena_config.get_qualifying_arena_duration()
    self.actor_id = data.actor_id
    self.opponent_type = data.opponent_type
    self.opponent_id = data.arena_opponent_id
    self.playerdata = data.playerdata
    self.grade_id = data.grade_id
    self.state = ArenaState.no_start
    self.player_leave = false
    local fight_members = {}
    table.insert(fight_members,self.actor_id)
    fight_server_center:add_fight(data.fight_id,data.token,data.fight_type,fight_members)
    return true
end

function qualifying_arena_fight_room.initialize(self)
    self.aoi_scene_id = arena_scene_manager.create_qualifying_scene(self.fight_id)
    local scene = arena_scene_manager.find_scene(self.aoi_scene_id)
    if scene == nil then
        return false
    end

    if self.opponent_type == const.ARENA_CHALLENGE_OPPONENT_TYPE.player then
        local entity = entity_factory.create_entity(const.ENTITY_TYPE_ARENA_DUMMY)
        if entity == nil then
            flog("error", "Failed create arena opponent: " .. self.opponent_id)
            return false
        end

        if entity:init(self.playerdata) == false then
            flog("error", "Failed init arena opponent")
            return false
        end
        entity:recalc()
        --进入场景
        entity.scene_id = self.aoi_scene_id
        local pos = arena_scene_manager.get_qualifying_scene_born_pos(2)
        entity.posX = pos[1]
        entity.posY = pos[2]
        entity.posZ = pos[3]
        entity:enter_aoi_scene()
        local puppet = scene:get_entity_manager().GetPuppet(self.entity_id)
        if puppet ~= nil then
            local rotation = {}
            rotation.eulerAngles = {}
            rotation.eulerAngles.y = pos[4]
            puppet:SetRotation(rotation)
        end
        scene:get_entity_manager().SetEntityEnabled(entity.entity_id,false)
    else
        local arena_grade_config = challenge_arena_config.get_arena_grade_config(self.grade_id)
        if arena_grade_config == nil then
            flog("error","can not find arena config!grade_id "..self.grade_id)
            return false
        end
        local next_grade_config = challenge_arena_config.get_arena_grade_config(arena_grade_config.ExGrade)
        if next_grade_config == nil then
            flog("error","can not find next arena config!grade_id "..self.grade_id)
            return false
        end
        local keeper_config = challenge_arena_config.get_keeper_config(arena_grade_config.ExGrade)
        if keeper_config == nil then
            flog("error","can not find next arena keeper config!grade_id "..self.grade_id)
            return false
        end
        local pos = arena_scene_manager.get_qualifying_scene_born_pos(2)
        keeper_config.PosX = pos[1]
        keeper_config.PosY = pos[2]
        keeper_config.PosZ = pos[3]
        local monster = scene:get_entity_manager().CreateScenePuppet(keeper_config,EntityType.Monster)
        if monster == nil then
            return false
        end
        monster:SetEnabled(false)
        local rotation = {}
        rotation.eulerAngles = {}
        rotation.eulerAngles.y = pos[4]
        monster:SetRotation(rotation)
        monster:StartHangup()
    end
    return true
end

function qualifying_arena_fight_room.update(self,current_time)
    if self.state == ArenaState.over or self.state == ArenaState.done then
        return
    end

    if current_time > self.end_time then
        self.state = ArenaState.over
        local scene = arena_scene_manager.find_scene(self.aoi_scene_id)
        if scene ~= nil then
            scene:SetAllEntityEnabled(false)
            scene:SetAllEntityAttackStatus(false)
        end
    end

end

function qualifying_arena_fight_room.check_members(self,actor_id)
    return self.actor_id == actor_id
end

function qualifying_arena_fight_room.get_aoi_scene_id(self)
    return self.aoi_scene_id
end

function qualifying_arena_fight_room.is_over(self)
    return self.state == ArenaState.over
end

function qualifying_arena_fight_room.qualifying_arena_fight_over(self)
    if self.state == ArenaState.done then
        return
    end
    self.state = ArenaState.done
    if self.player_leave then
        return
    end
    local player = online_user.get_user(self.actor_id)
    if player ~= nil then
        player:fight_send_to_game({func_name="on_qualifying_arena_fight_result",success=false})
    end
end

function qualifying_arena_fight_room.is_all_player_leave(self)
    if self.state ~= ArenaState.done then
        return false
    end

    local scene = arena_scene_manager.find_scene(self.aoi_scene_id)
    if scene ~= nil then
        return scene:is_all_player_leave()
    end
    return false
end

function qualifying_arena_fight_room.destroy(self)
    if self.aoi_scene_id ~= nil then
        local scene = arena_scene_manager.find_scene(self.aoi_scene_id)
        if scene ~= nil then
            scene:set_scene_state(const.SCENE_STATE.done)
        end
        self.aoi_scene_id = nil
    end
end

function qualifying_arena_fight_room.leave_qualifying_arena_fight_room(self,actor_id)
    flog("tmlDebug","qualifying_arena_fight_room.leave_qualifying_arena_fight_room")
end

function qualifying_arena_fight_room.set_qualifying_arena_done(self)
    self.state = ArenaState.done
    self.player_leave = true
    local scene = arena_scene_manager.find_scene(self.aoi_scene_id)
    if scene ~= nil then
        scene:SetAllEntityEnabled(false)
        scene:SetAllEntityAttackStatus(false)
    end
end

function qualifying_arena_fight_room.check_fight_over(self)
    return self.state == ArenaState.over or self.state == ArenaState.done
end

return qualifying_arena_fight_room

