--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/22 0022
-- Time: 15:25
-- To change this template use File | Settings | File Templates.
--

local timer = require "basic/timer"
local const = require "Common/constant"
local task_dungeon_room = require "fight_server/task_dungeon_room"
local flog = require "basic/log"
local fight_server_center = require "fight_server/fight_server_center"

local task_dungeon_center = {}
task_dungeon_center.__index = task_dungeon_center

setmetatable(task_dungeon_center, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function task_dungeon_center.__ctor(self)
    self.task_dungeons = {}
    local function update_timer_handler()
        self:update()
    end
    self.update_timer = timer.create_timer(update_timer_handler,1000,const.INFINITY_CALL)
end

function task_dungeon_center.create_task_dungeon(self,input,game_id)
    self.task_dungeons[input.fight_id] = task_dungeon_room(input,game_id)
    return true
end

function task_dungeon_center.check_player(self,actor_id,fight_id)
    flog("tmlDebug","task_dungeon_center.check_player ")
    if self.task_dungeons[fight_id] == nil then
        flog("tmlDebug","self.task_dungeons[fight_id] == nil fight_id "..fight_id)
        return false
    end
    return self.task_dungeons[fight_id]:check_members(actor_id)
end

function task_dungeon_center.get_dungeon_id(self,actor_id,fight_id)
    flog("tmlDebug","task_dungeon_center.get_player_dungeon_id ")
    if self.task_dungeons[fight_id] == nil then
        return nil
    end

    if self.task_dungeons[fight_id]:check_members(actor_id) == false then
        return nil
    end

    return self.task_dungeons[fight_id]:get_dungeon_id()
end

function task_dungeon_center.get_aoi_scene_id(self,fight_id)
    if self.task_dungeons[fight_id] == nil then
        return nil
    end
    return self.task_dungeons[fight_id]:get_aoi_scene_id()
end

function task_dungeon_center.update(self)
    local current_time = _get_now_time_second()
    for fight_id,dungeon in pairs(self.task_dungeons) do
        if dungeon ~= nil then
            dungeon:update(current_time)
            if dungeon:is_over() then
                dungeon:dungeon_over()
            end
            if dungeon:is_all_player_leave() then
                fight_server_center:remove_fight(fight_id)
                dungeon:destroy()
                self.task_dungeons[fight_id] = nil
            end
        end
    end
end

function task_dungeon_center.leave_team(self,fight_id,actor_id)
    flog("tmlDebug","task_dungeon_center.leave_team")
    if self.task_dungeons[fight_id] == nil then
        return
    end
    self.task_dungeons[fight_id]:leave_team(actor_id)
end

function task_dungeon_center.get_team_info(self,fight_id)
    flog("tmlDebug","task_dungeon_center.get_team_info")
    if self.task_dungeons[fight_id] == nil then
        return
    end
    return self.task_dungeons[fight_id]:get_team_info()
end

function task_dungeon_center.send_mark_to_client(self,fight_id,actor_id,enter_aoi)
    flog("tmlDebug","task_dungeon_center.send_mark_to_client")
    if self.task_dungeons[fight_id] == nil then
        return
    end
    self.task_dungeons[fight_id]:send_mark_to_client(actor_id,enter_aoi)
end

function task_dungeon_center.on_remove_task_dungeon_member(self,fight_id,actor_id)
    flog("tmlDebug","task_dungeon_center.on_remove_team_dungeon_member")
    if self.task_dungeons[fight_id] == nil then
        return
    end
    self.task_dungeons[fight_id]:on_remove_task_dungeon_member(actor_id)
end

return task_dungeon_center()
