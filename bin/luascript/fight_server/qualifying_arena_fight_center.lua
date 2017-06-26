--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/9 0009
-- Time: 17:25
-- To change this template use File | Settings | File Templates.
--

local timer = require "basic/timer"
local const = require "Common/constant"
local qualifying_arena_fight_room = require "fight_server/qualifying_arena_fight_room"
local flog = require "basic/log"
local get_now_time_second = _get_now_time_second
local fight_server_center = require "fight_server/fight_server_center"

local qualifying_arena_fight_center = {}
qualifying_arena_fight_center.__index = qualifying_arena_fight_center

setmetatable(qualifying_arena_fight_center, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function qualifying_arena_fight_center.__ctor(self)
    self.arenas = {}
    local function update_timer_handler()
        self:update()
    end
    self.update_timer = timer.create_timer(update_timer_handler,1000,const.INFINITY_CALL)
end

function qualifying_arena_fight_center.create_qualifying_arena(self,input)
    self.arenas[input.fight_id] = qualifying_arena_fight_room(input)
    if self.arenas[input.fight_id]:initialize() == false then
        fight_server_center:remove_fight(input.fight_id)
        self.arenas[input.fight_id]:destroy()
        return false
    end
    return true
end

function qualifying_arena_fight_center.check_player(self,actor_id,fight_id)
    flog("tmlDebug","qualifying_arena_fight_center.check_player ")
    if self.arenas[fight_id] == nil then
        return false
    end
    return self.arenas[fight_id]:check_members(actor_id)
end

function qualifying_arena_fight_center.get_aoi_scene_id(self,fight_id)
    if self.arenas[fight_id] == nil then
        return nil
    end
    return self.arenas[fight_id]:get_aoi_scene_id()
end

function qualifying_arena_fight_center.update(self)
    local current_time = get_now_time_second()
    for fight_id,arena in pairs(self.arenas) do
        if arena ~= nil then
            arena:update(current_time)
            if arena:is_over() then
                arena:qualifying_arena_fight_over()
            end
            if arena:is_all_player_leave() then
                fight_server_center:remove_fight(fight_id)
                arena:destroy()
                self.arenas[fight_id] = nil
            end
        end
    end
end

function qualifying_arena_fight_center.leave_qualifying_arena(self,fight_id,actor_id)
    flog("tmlDebug","qualifying_arena_fight_center.leave_qualifying_arena")
    if self.arenas[fight_id] == nil then
        return
    end
    self.arenas[fight_id]:leave_qualifying_arena_fight_room(actor_id)
end

function qualifying_arena_fight_center.set_qualifying_arena_done(self,fight_id)
    flog("tmlDebug","qualifying_arena_fight_center.set_qualifying_arena_done")
    if self.arenas[fight_id] == nil then
        return
    end
    self.arenas[fight_id]:set_qualifying_arena_done()
end

function qualifying_arena_fight_center.check_fight_over(self,fight_id)
    flog("tmlDebug","qualifying_arena_fight_center.check_fight_over")
    if self.arenas[fight_id] == nil then
        return false
    end
    return self.arenas[fight_id]:check_fight_over()
end

return qualifying_arena_fight_center()



