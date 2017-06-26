--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/13 0013
-- Time: 18:32
-- To change this template use File | Settings | File Templates.
--

local timer = require "basic/timer"
local const = require "Common/constant"
local dogfight_arena_fight_room = require "fight_server/dogfight_arena_fight_room"
local flog = require "basic/log"
local get_now_time_second = _get_now_time_second
local fight_server_center = require "fight_server/fight_server_center"

local dogfight_arena_fight_center = {}
dogfight_arena_fight_center.__index = dogfight_arena_fight_center

setmetatable(dogfight_arena_fight_center, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function dogfight_arena_fight_center.__ctor(self)
    self.arenas = {}
    local function update_timer_handler()
        self:update()
    end
    self.update_timer = timer.create_timer(update_timer_handler,1000,const.INFINITY_CALL)
end

function dogfight_arena_fight_center.create_dogfight_arena(self,input)
    self.arenas[input.fight_id] = dogfight_arena_fight_room(input)
    if self.arenas[input.fight_id]:initialize() == false then
        fight_server_center:remove_fight(input.fight_id)
        self.arenas[input.fight_id]:destroy()
        return false
    end
    return true
end

function dogfight_arena_fight_center.check_player(self,actor_id,fight_id)
    flog("tmlDebug","dogfight_arena_fight_center.check_player ")
    if self.arenas[fight_id] == nil then
        return false
    end
    return self.arenas[fight_id]:check_members(actor_id)
end

function dogfight_arena_fight_center.get_aoi_scene_id(self,fight_id)
    if self.arenas[fight_id] == nil then
        return nil
    end
    return self.arenas[fight_id]:get_aoi_scene_id()
end

function dogfight_arena_fight_center.update(self)
    local current_time = get_now_time_second()
    for fight_id,arena in pairs(self.arenas) do
        if arena ~= nil then
            arena:update(current_time)
            if arena:is_over() then
                arena:dogfight_arena_fight_over()
            end
            if arena:is_all_player_leave() then
                fight_server_center:remove_fight(fight_id)
                arena:destroy()
                self.arenas[fight_id] = nil
            end
        end
    end
end

function dogfight_arena_fight_center.leave_dogfight_arena(self,fight_id,actor_id)
    flog("tmlDebug","dogfight_arena_fight_center.leave_dogfight_arena")
    if self.arenas[fight_id] == nil then
        return
    end
    self.arenas[fight_id]:leave_dogfight_arena_fight_room(actor_id)
end

function dogfight_arena_fight_center.get_start_fight_time(self,fight_id)
    if self.arenas[fight_id] == nil then
        return get_now_time_second()
    end
    return self.arenas[fight_id]:get_start_fight_time()
end

function dogfight_arena_fight_center.get_born_pos(self,fight_id)
    if self.arenas[fight_id] == nil then
        return nil
    end
    return self.arenas[fight_id]:get_born_pos()
end

function dogfight_arena_fight_center.get_room_id(self,fight_id)
    if self.arenas[fight_id] == nil then
        return nil
    end
    return self.arenas[fight_id]:get_room_id()
end

function dogfight_arena_fight_center.get_countdown(self,fight_id)
    if self.arenas[fight_id] == nil then
        return nil
    end
    return self.arenas[fight_id]:get_countdown()
end

function dogfight_arena_fight_center.player_enter_scene(self,fight_id,actor_id,arena_total_score,arena_address)
    if self.arenas[fight_id] == nil then
        return nil
    end
    return self.arenas[fight_id]:player_enter_scene(actor_id,arena_total_score,arena_address)
end

function dogfight_arena_fight_center.add_dogfight_occupy_score(self,fight_id,actor_id,score)
    flog("tmlDebug","dogfight_arena_fight_center.add_dogfight_occupy_score")
    if self.arenas[fight_id] == nil then
        flog("tmlDebug","dogfight_arena_fight_center:add_dogfight_occupy_score self.arenas[fight_id] == nil fight_id "..fight_id)
        return
    end
    self.arenas[fight_id]:add_dogfight_occupy_score(actor_id,score)
end

function dogfight_arena_fight_center.kill_entity(self,fight_id,killer_id,loser_type,loser_id)
    flog("tmlDebug","dogfight_arena_fight_center:kill_entity")
    if self.arenas[fight_id] == nil then
        flog("tmlDebug","dogfight_arena_fight_center:add_dogfight_occupy_score self.arenas[fight_id] == nil fight_id "..fight_id)
        return
    end
    self.arenas[fight_id]:kill_entity(killer_id,loser_type,loser_id)
end

function dogfight_arena_fight_center.get_score_data(self,fight_id)
    flog("tmlDebug","dogfight_arena_fight_center:send_score_to_client")
    if self.arenas[fight_id] == nil then
        flog("tmlDebug","dogfight_arena_fight_center:send_score_to_client self.arenas[fight_id] == nil fight_id "..fight_id)
        return nil
    end
    return self.arenas[fight_id]:get_score_data()
end

function dogfight_arena_fight_center.on_new_player_enter_dogfight_arena(self,input)
    flog("tmlDebug","dogfight_arena_fight_center:send_score_to_client")
    if self.arenas[input.fight_id] == nil then
        flog("tmlDebug","dogfight_arena_fight_center:send_score_to_client self.arenas[fight_id] == nil fight_id "..input.fight_id)
        return nil
    end
    for actor_id,actor in pairs(input.actors) do
        fight_server_center:add_member(input.fight_id,actor_id)
        self.arenas[input.fight_id]:on_new_player_enter_dogfight_arena(actor_id,actor.actor_name,actor.vocation)
    end
end

function dogfight_arena_fight_center.check_fight_over(self,fight_id)
    flog("tmlDebug","dogfight_arena_fight_center.check_fight_over")
    if self.arenas[fight_id] == nil then
        return false
    end
    return self.arenas[fight_id]:check_fight_over()
end

return dogfight_arena_fight_center()

