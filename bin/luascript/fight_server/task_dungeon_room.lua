--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/22 0022
-- Time: 15:25
-- To change this template use File | Settings | File Templates.
--

local system_task_config = require "configs/system_task_config"
local flog = require "basic/log"
local online_user = require "fight_server/fight_server_online_user"
local fight_server_center = require "fight_server/fight_server_center"
local dungeon_room = require "team_dungeon/dungeon_room"
local _get_now_time_second = _get_now_time_second
local table = table
local const = require "Common/constant"
local scheme = require "basic/scheme"
local net_work = require "basic/net"
local fight_send_to_game = net_work.fight_send_to_game

local task_dungeon_room = {}
task_dungeon_room.__index = task_dungeon_room

setmetatable(task_dungeon_room, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {
}
task_dungeon_room.__params = params


function task_dungeon_room.__ctor(self,input,game_id)
    self.team_game_id = game_id
    self.team_info = input.team_info
    self.dungeon_id = input.dungeon_id
    self.start_time = _get_now_time_second()
    self.dungeon_config = system_task_config.get_task_dungeon_config(self.dungeon_id)
    self.members = {}
    local fight_members = {}
    local levels = {}
    if self.team_info ~= nil then
        for i=1,#self.team_info.members,1 do
            table.insert(fight_members,self.team_info.members[i].actor_id)
            table.insert(self.members,self.team_info.members[i].actor_id)
            table.insert(levels,self.team_info.members[i].level)
        end
    else
        table.insert(self.members,input.actor_id)
        table.insert(fight_members,input.actor_id)
        table.insert(levels,input.level)
    end
    self.aoi_scene_id = task_dungeon_scene_manager.create_dungeon_scene(self.dungeon_id,scheme.get_monster_level_by_levels(levels))
    self.dungeon_room = dungeon_room(self.dungeon_config,self.aoi_scene_id)
    fight_server_center:add_fight(input.fight_id,input.token,input.fight_type,fight_members)
end

function task_dungeon_room.get_dungeon_id(self)
    return self.dungeon_id
end

function task_dungeon_room.update(self,current_time)
    self.dungeon_room:update(current_time)
    if self.dungeon_room:get_mark_change() then
        self.dungeon_room:set_mark_change(false)
        for i=1,#self.members,1 do
            self.dungeon_room:send_mark_to_client(self.members[i],false)
        end
    end
end

function task_dungeon_room.check_members(self,actor_id)
    for i=1,#self.members,1 do
        if self.members[i] == actor_id then
            return true
        end
    end
    return false
end

function task_dungeon_room.get_aoi_scene_id(self)
    return self.aoi_scene_id
end

function task_dungeon_room.is_over(self)
    return self.dungeon_room:is_over()
end

function task_dungeon_room.dungeon_over(self)
    if self.dungeon_room:is_done() then
        return
    end

    self.dungeon_room:set_state_done()
    local result_data = {}
    result_data.result = 0
    result_data.cost_time = _get_now_time_second() - self.dungeon_room:get_start_time()
    result_data.func_name = "on_end_task_dungeon"
    result_data.win = self.dungeon_room:get_isWin()
    result_data.dungeon_id = self.dungeon_id
    result_data.wave = self.dungeon_room:get_wave()
    result_data.mark = self.dungeon_room:get_mark()

    local player = nil
    for i=1,#self.members,1 do
        player = online_user.get_user(self.members[i])
        if player ~= nil then
            player:fight_send_to_game(result_data)
        end
    end
    if self.team_info ~= nil then
        for i=1,#self.members,1 do
            player = online_user.get_user(self.members[i])
            if player ~= nil then
                fight_send_to_game(self.team_game_id,const.GT_MESSAGE_LUA_GAME_RPC,{actor_id=self.members[i],team_id=self.team_info.team_id,func_name="on_team_task_dungeon_end"})
                break
            end
        end
    end
end

function task_dungeon_room.is_all_player_leave(self)
    if self.dungeon_room:is_done() then
        local scene = task_dungeon_scene_manager.find_scene(self.aoi_scene_id)
        if scene ~= nil then
            return scene:is_all_player_leave()
        end
    end
    return false
end

function task_dungeon_room.destroy(self)
    if self.aoi_scene_id ~= nil then
        local scene = task_dungeon_scene_manager.find_scene(self.aoi_scene_id)
        if scene ~= nil then
            scene:set_scene_state(const.SCENE_STATE.done)
        end
        self.aoi_scene_id = nil
    end
end

function task_dungeon_room.leave_team(self,actor_id)
    flog("tmlDebug","task_dungeon_room.leave_team")
    if self.team_info ~= nil then
        for i=#self.team_info.members,1,-1 do
            if self.team_info.members[i].actor_id == actor_id then
                table.remove(self.team_info.members,i)
                break
            end
        end
    end
end

function task_dungeon_room.get_team_info(self)
    return self.team_info
end

function task_dungeon_room.send_mark_to_client(self,actor_id,enter_aoi)
    self.dungeon_room:send_mark_to_client(actor_id,enter_aoi)
end

function task_dungeon_room.on_remove_task_dungeon_member(self,actor_id)
    for i=#self.members,1,-1 do
        if self.members[i] == actor_id then
            table.remove(self.members,i)
            break
        end
    end
    if #self.members == 0 then
        self.dungeon_room:set_state_done()
    end
end

return task_dungeon_room

