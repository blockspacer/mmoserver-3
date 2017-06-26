--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/23 0023
-- Time: 14:34
-- To change this template use File | Settings | File Templates.
--

local challenge_main_dungeon_config = require "configs/challenge_main_dungeon_config"
local flog = require "basic/log"
local online_user = require "fight_server/fight_server_online_user"
local fight_server_center = require "fight_server/fight_server_center"
local dungeon_room = require "team_dungeon/dungeon_room"
local const = require "Common/constant"
local _get_now_time_second = _get_now_time_second

local main_dungeon_room = {}
main_dungeon_room.__index = main_dungeon_room

setmetatable(main_dungeon_room, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {
}
main_dungeon_room.__params = params


function main_dungeon_room.__ctor(self,dungeon_id,actor_id,aoi_scene_id,token,fight_id,fight_type)
    self.is_player_leave = false
    self.aoi_scene_id = aoi_scene_id
    self.dungeon_id = dungeon_id
    self.start_time = _get_now_time_second()
    self.dungeon_config = challenge_main_dungeon_config.get_main_dungeon_config(self.dungeon_id)
    self.actor_id = actor_id
    self.dungeon_room = dungeon_room(self.dungeon_config,aoi_scene_id)
    local fight_members = {}
    table.insert(fight_members,self.actor_id)
    fight_server_center:add_fight(fight_id,token,fight_type,fight_members)
end

function main_dungeon_room.get_dungeon_id(self)
    return self.dungeon_id
end

function main_dungeon_room.update(self,current_time)
    self.dungeon_room:update(current_time)
    if self.dungeon_room:get_mark_change() then
        self.dungeon_room:set_mark_change(false)
        self.dungeon_room:send_mark_to_client(self.actor_id,false)
    end
end

function main_dungeon_room.check_members(self,actor_id)
    flog("tmlDebug","222222222222222222222222222")
    flog("tmlDebug","self.actor_id "..self.actor_id )
    flog("tmlDebug","actor_id "..actor_id )
    return self.actor_id == actor_id
end

function main_dungeon_room.get_aoi_scene_id(self)
    return self.aoi_scene_id
end

function main_dungeon_room.is_over(self)
    return self.dungeon_room:is_over()
end

function main_dungeon_room.main_dungeon_over(self)
    if self.dungeon_room:is_done() then
        return
    end

    self.dungeon_room:set_state_done()
    if self.is_player_leave then
        return
    end

    local result_data = {}
    result_data.result = 0
    result_data.cost_time = _get_now_time_second() - self.dungeon_room:get_start_time()
    result_data.func_name = "end_main_dungeon"
    result_data.win = self.dungeon_room:get_isWin()
    result_data.dungeon_id = self.dungeon_id
    result_data.wave = self.dungeon_room:get_wave()
    result_data.mark = self.dungeon_room:get_mark()

    local player = online_user.get_user(self.actor_id)
    if player ~= nil then
        player:fight_send_to_game(result_data)
    end
end

function main_dungeon_room.is_all_player_leave(self)
    if self.dungeon_room:is_done() then
        local scene = main_dungeon_scene_manager.find_scene(self.aoi_scene_id)
        if scene ~= nil then
            return scene:is_all_player_leave()
        end
    end
    return false
end

function main_dungeon_room.destroy(self)
    if self.aoi_scene_id ~= nil then
        local scene = main_dungeon_scene_manager.find_scene(self.aoi_scene_id)
        if scene ~= nil then
            scene:set_scene_state(const.SCENE_STATE.done)
        end
        self.aoi_scene_id = nil
    end
end

function main_dungeon_room.leave_main_dungeon(self)
    flog("tmlDebug","main_dungeon_room.leave_main_dungeon")
    self.is_player_leave = true
    self.dungeon_room:set_state_done()
end

function main_dungeon_room.send_mark_to_client(self,actor_id,enter_aoi)
    flog("tmlDebug","main_dungeon_room.send_mark_to_client enter_aoi "..tostring(enter_aoi))
    self.dungeon_room:send_mark_to_client(actor_id,enter_aoi)
end

return main_dungeon_room



