--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/3 0003
-- Time: 20:12
-- To change this template use File | Settings | File Templates.
--

local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"
local flog = require "basic/log"
local online_user = require "fight_server/fight_server_online_user"
local fight_data_statistics = require "helper/fight_data_statistics"
local fight_server_center = require "fight_server/fight_server_center"
local dungeon_room = require "team_dungeon/dungeon_room"
local const = require "Common/constant"
local _get_now_time_second = _get_now_time_second
local table = table
local scheme = require "basic/scheme"

local team_dungeon_room = {}
team_dungeon_room.__index = team_dungeon_room

setmetatable(team_dungeon_room, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {
}
team_dungeon_room.__params = params

--team_info
--captain_id 队长id
--target 副本id
--team_id 队伍id
--members 成员列表

function team_dungeon_room.__ctor(self,team_info,input)

    self.team_info = team_info
    self.start_time = _get_now_time_second()
    self.dungeon_config = challenge_team_dungeon_config.get_team_dungeon_config(self.team_info.target)
    self.members = {}
    local fight_members = {}
    local levels = {}
    for i=1,#self.team_info.members,1 do
        table.insert(self.members,self.team_info.members[i].actor_id)
        table.insert(fight_members,self.team_info.members[i].actor_id)
        table.insert(levels,self.team_info.members[i].level)
    end
    flog("info","team_dungeon_room team_dungeon_scene_manager.create_team_dungeon_scene")
    self.aoi_scene_id = team_dungeon_scene_manager.create_team_dungeon_scene(team_info.target,scheme.get_monster_level_by_levels(levels))
    if self.dungeon_config == nil then
        flog("warn","team_dungeon_room dungeon_config == nil,target == "..self.team_info.target)
    end
    self.dungeon_room = dungeon_room(self.dungeon_config,self.aoi_scene_id)
    fight_server_center:add_fight(input.fight_id,input.token,input.fight_type,fight_members)
end

function team_dungeon_room.get_team_id(self)
    return self.team_info.team_id
end

function team_dungeon_room.get_dungeon_id(self)
    return self.team_info.target
end

function team_dungeon_room.update(self,current_time)
    self.dungeon_room:update(current_time)
    if self.dungeon_room:get_mark_change() then
        self.dungeon_room:set_mark_change(false)
        for i=1,#self.members,1 do
            self.dungeon_room:send_mark_to_client(self.members[i],false)
        end
    end
end

function team_dungeon_room.check_members(self,actor_id)
    for i=1,#self.members,1 do
        if self.members[i] == actor_id then
            return true
        end
    end
    return false
end

function team_dungeon_room.get_aoi_scene_id(self)
    return self.aoi_scene_id
end

function team_dungeon_room.is_over(self)
    return self.dungeon_room:is_over()
end

local function _sync_fight_data_statistics(members, captain_id, player)
    local team_members = {}
    for index, member in pairs(members) do
        team_members[member.actor_id] = index
    end

    local fight_data, start_time = fight_data_statistics.get_fight_data_statistics(team_members, captain_id)
    player:fight_send_to_game( {func_name = "on_init_fight_data_statistics", init_data = fight_data, start_time})
end

function team_dungeon_room.team_dungeon_over(self)
    if self.dungeon_room:is_done() then
        return
    end
    flog("info","team_dungeon_room.team_dungeon_over")
    self.dungeon_room:set_state_done()
    --副本霸主榜
    local cost_time = _get_now_time_second() - self.dungeon_room:get_start_time()
    local hegemon_data = {}
    hegemon_data.team_id = self:get_team_id()
    hegemon_data.cost_time = cost_time
    hegemon_data.service_type = const.SERVICE_TYPE.team_service
    hegemon_data.func_name = "end_team_dungeon"
    local player = online_user.get_user(self.team_info.captain_id)
    if player ~= nil then
        player:fight_send_to_game(hegemon_data)
        _sync_fight_data_statistics(self.team_info.members, self.team_info.captain_id, player)
    end

    local result_data = {}
    result_data.result = 0
    result_data.cost_time = cost_time
    result_data.func_name = "on_team_dungeon_end"
    result_data.dungeon_id = self.team_info.target
    result_data.win = self.dungeon_room:get_isWin()
    result_data.wave = self.dungeon_room:get_wave()
    result_data.mark = self.dungeon_room:get_mark()
    for i=1,#self.members,1 do
        player = online_user.get_user(self.members[i])
        if player ~= nil then
            player:fight_send_to_game(result_data)
        end
    end
end

function team_dungeon_room.is_all_player_leave(self)
    if self.dungeon_room:is_done() then
        local scene = team_dungeon_scene_manager.find_scene(self.aoi_scene_id)
        if scene ~= nil then
            return scene:is_all_player_leave()
        end
    end
    return false
end

function team_dungeon_room.destroy(self)
    if self.aoi_scene_id ~= nil then
        team_dungeon_scene_manager.destroy_scene(self.aoi_scene_id)
        self.aoi_scene_id = nil
    end
end

function team_dungeon_room.leave_team(self,actor_id)
    flog("tmlDebug","team_dungeon_room.leave_team")
    for i=#self.team_info.members,1,-1 do
        if self.team_info.members[i].actor_id == actor_id then
            table.remove(self.team_info.members[i],i)
            flog("tmlDebug","team_dungeon_room.leave_team actor_id:"..actor_id)
            break
        end
    end
end

function team_dungeon_room.send_mark_to_client(self,actor_id,enter_aoi)
    self.dungeon_room:send_mark_to_client(actor_id,enter_aoi)
end

function team_dungeon_room.on_remove_team_dungeon_member(self,actor_id)
    for i=#self.members,1,-1 do
        if self.members[i] == actor_id then
            table.remove(self.members,i)
        end
    end
end

return team_dungeon_room

