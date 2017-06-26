--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/3 0003
-- Time: 19:55
-- To change this template use File | Settings | File Templates.
--

local timer = require "basic/timer"
local const = require "Common/constant"
local team_dungeon_room = require "team_dungeon/team_dungeon_room"
local flog = require "basic/log"
local _get_now_time_second = _get_now_time_second

local team_dungeon_center = {}
team_dungeon_center.__index = team_dungeon_center

setmetatable(team_dungeon_center, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function team_dungeon_center.__ctor(self)
    self.team_dungeons = {}
    local function update_timer_handler()
        self:update()
    end
    self.update_timer = timer.create_timer(update_timer_handler,1000,const.INFINITY_CALL)
end

function team_dungeon_center.create_team_dungeons(self,input)
    local team_info = input.team_info
    self.team_dungeons[input.fight_id] = team_dungeon_room(team_info,input)
    return true
end

function team_dungeon_center.check_player_team_dungeon(self,actor_id,fight_id)
    flog("tmlDebug","team_dungeon_center.check_player_team_dungeon ")
    if self.team_dungeons[fight_id] == nil then
        return false
    end
    return self.team_dungeons[fight_id]:check_members(actor_id)
end

function team_dungeon_center.get_player_team_dungeon_id(self,actor_id,fight_id)
    flog("tmlDebug","team_dungeon_center.check_player_team_dungeon ")
    if self.team_dungeons[fight_id] == nil then
        return nil
    end

    if self.team_dungeons[fight_id]:check_members(actor_id) == false then
        return false
    end

    return self.team_dungeons[fight_id]:get_dungeon_id()
end

function team_dungeon_center.get_team_dungeon_aoi_scene_id(self,fight_id)
    if self.team_dungeons[fight_id] == nil then
        return nil
    end
    return self.team_dungeons[fight_id]:get_aoi_scene_id()
end

function team_dungeon_center.update(self)
    local current_time = _get_now_time_second()
    for fight_id,dungeon in pairs(self.team_dungeons) do
        if dungeon ~= nil then
            dungeon:update(current_time)
            if dungeon:is_over() then
                dungeon:team_dungeon_over()
            end
            if dungeon:is_all_player_leave() then
                dungeon:destroy()
                self.team_dungeons[fight_id] = nil
            end
        end
    end
end

function team_dungeon_center.get_team_info(self, fight_id)
    flog("syzDebug","team_dungeon_center.get_team_info ")
    if self.team_dungeons[fight_id] == nil then
        return nil
    end
    return self.team_dungeons[fight_id].team_info
end

function team_dungeon_center.leave_team(self,fight_id,actor_id)
    flog("tmlDebug","team_dungeon_center.leave_team")
    if self.team_dungeons[fight_id] == nil then
        return
    end
    self.team_dungeons[fight_id]:leave_team(actor_id)
end

function team_dungeon_center.send_mark_to_client(self,fight_id,actor_id,enter_aoi)
    flog("tmlDebug","team_dungeon_center.send_mark_to_client")
    if self.team_dungeons[fight_id] == nil then
        return
    end
    self.team_dungeons[fight_id]:send_mark_to_client(actor_id,enter_aoi)
end

function team_dungeon_center.on_remove_team_dungeon_member(self,fight_id,actor_id)
    flog("tmlDebug","team_dungeon_center.on_remove_team_dungeon_member")
    if self.team_dungeons[fight_id] == nil then
        return
    end
    self.team_dungeons[fight_id]:on_remove_team_dungeon_member(actor_id,actor_id)
end

return team_dungeon_center()