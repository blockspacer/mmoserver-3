--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/23 0023
-- Time: 13:45
-- To change this template use File | Settings | File Templates.
--

local timer = require "basic/timer"
local const = require "Common/constant"
local main_dungeon_room = require "fight_server/main_dungeon_room"
local flog = require "basic/log"
local fight_server_center = require "fight_server/fight_server_center"

local main_dungeon_center = {}
main_dungeon_center.__index = main_dungeon_center

setmetatable(main_dungeon_center, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function main_dungeon_center.__ctor(self)
    self.main_dungeons = {}
    local function update_timer_handler()
        self:update()
    end
    self.update_timer = timer.create_timer(update_timer_handler,1000,const.INFINITY_CALL)
end

function main_dungeon_center.create_main_dungeon(self,input)
    local aoi_scene_id = main_dungeon_scene_manager.create_main_dungeon_scene(input.dungeon_id)
    if aoi_scene_id ~= nil or aoi_scene_id ~= 0 then
        self.main_dungeons[input.fight_id] = main_dungeon_room(input.dungeon_id,input.actor_id,aoi_scene_id,input.token,input.fight_id,input.fight_type)
    end
end

function main_dungeon_center.check_player(self,actor_id,fight_id)
    flog("tmlDebug","main_dungeon_center.check_player ")
    if self.main_dungeons[fight_id] == nil then
        flog("tmlDebug","self.main_dungeons[fight_id] == nil fingt_id "..fight_id)
        return false
    end
    flog("tmlDebug","111111111111111111111111111111")
    return self.main_dungeons[fight_id]:check_members(actor_id)
end

function main_dungeon_center.get_player_dungeon_id(self,actor_id,fight_id)
    flog("tmlDebug","main_dungeon_center.get_player_dungeon_id ")
    if self.main_dungeons[fight_id] == nil then
        return nil
    end

    if self.main_dungeons[fight_id]:check_members(actor_id) == false then
        return nil
    end

    return self.main_dungeons[fight_id]:get_dungeon_id()
end

function main_dungeon_center.get_main_dungeon_aoi_scene_id(self,fight_id)
    if self.main_dungeons[fight_id] == nil then
        return nil
    end
    return self.main_dungeons[fight_id]:get_aoi_scene_id()
end

function main_dungeon_center.update(self)
    local current_time = _get_now_time_second()
    for fight_id,dungeon in pairs(self.main_dungeons) do
        if dungeon ~= nil then
            dungeon:update(current_time)
            if dungeon:is_over() then
                dungeon:main_dungeon_over()
            end
            if dungeon:is_all_player_leave() then
                fight_server_center:remove_fight(fight_id)
                dungeon:destroy()
                self.main_dungeons[fight_id] = nil
            end
        end
    end
end

function main_dungeon_center.leave_main_dungeon(self,fight_id)
    flog("tmlDebug","main_dungeon_center.leave_main_dungeon")
    if self.main_dungeons[fight_id] == nil then
        return
    end
    self.main_dungeons[fight_id]:leave_main_dungeon()
end

function main_dungeon_center.send_mark_to_client(self,fight_id,actor_id,enter_aoi)
    flog("tmlDebug","main_dungeon_center.send_mark_to_client enter_aoi "..tostring(enter_aoi))
    if self.main_dungeons[fight_id] == nil then
        return
    end
    self.main_dungeons[fight_id]:send_mark_to_client(actor_id,enter_aoi)
end

return main_dungeon_center()

