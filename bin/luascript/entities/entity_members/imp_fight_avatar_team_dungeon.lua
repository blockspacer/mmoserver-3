--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/3 0003
-- Time: 19:47
-- To change this template use File | Settings | File Templates.
--
local const = require "Common/constant"
local flog = require "basic/log"
local math = require "math"
local drop_manager = require("helper/drop_manager")
local team_dungeon_drop_manager = drop_manager("team_dungeon")
local online_user = require "fight_server/fight_server_online_user"
local fight_data_statistics = require "helper/fight_data_statistics"
--local team_follow = require "helper/team_follow"
local fight_server_message_center = require "fight_server/fight_server_message_center"
local team_dungeon_center = team_dungeon_center
local task_dungeon_center = task_dungeon_center

local imp_fight_avatar_team_dungeon = {}
imp_fight_avatar_team_dungeon.__index = imp_fight_avatar_team_dungeon

setmetatable(imp_fight_avatar_team_dungeon, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {
    team_state = {sync = true, default = "auto"},
    is_reward_enable = {sync = true, default = true},  --当前状态是否可获得奖励
}
imp_fight_avatar_team_dungeon.__params = params

function imp_fight_avatar_team_dungeon.__ctor(self)
    self.team_id = nil
end

function imp_fight_avatar_team_dungeon.imp_fight_avatar_team_dungeon_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
end

function imp_fight_avatar_team_dungeon.on_connect_team_dungeon_server(self)
    flog("tmlDebug","imp_fight_avatar_team_dungeon.on_connect_team_dungeon_server")
    local reply_data = {}
    reply_data.func_name = "ConnectTeamDungeonServerReply"
    local is_member = team_dungeon_center:check_player_team_dungeon(self.actor_id,self.fight_id)
    if is_member == true then
        local aoi_scene_id = team_dungeon_center:get_team_dungeon_aoi_scene_id(self.fight_id)
        if aoi_scene_id == nil then
            flog("tmlDebug","imp_fight_avatar_team_dungeon.on_connect_team_dungeon_server aoi_scene_id == nil")
            reply_data.result = const.error_team_dungeon_can_not_find_scene
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end
        local scene = team_dungeon_scene_manager.find_scene(aoi_scene_id)
        if scene == nil then
            flog("tmlDebug","imp_fight_avatar_team_dungeon.on_connect_team_dungeon_server scene == nil")
            reply_data.result = const.error_team_dungeon_can_not_find_scene
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end
        local born_pos = scene:get_random_born_pos()
        if born_pos == nil then
            flog("tmlDebug","imp_fight_avatar_team_dungeon.on_connect_team_dungeon_server born_pos == nil")
            reply_data.result = const.error_can_not_find_scene_born_pos
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end
        self.posX = born_pos[1]
        self.posY = born_pos[2]
        self.posZ = born_pos[3]
        self.rotation = born_pos[4]
        self.scene_id = scene:get_table_scene_id()
        reply_data.result = 0
        self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
        self:load_aoi_scene(aoi_scene_id,scene:get_table_scene_id(),scene:get_scene_id(),scene:get_scene_type(),scene:get_scene_resource_id())
        --[[if self.team_state == "follow" then
            team_follow.add_team_follower(self:get_team_captain(), self)
        end]]
    else
        reply_data.result = const.error_team_dungeon_is_not_member
        self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
        return
    end

end


function imp_fight_avatar_team_dungeon.get_team_members(self)
    local team_id = self.team_id
    local team_members = {}
    local team_info = self:get_team_info()
    if team_info == nil then
        return team_members
    end
    for _, member in pairs(team_info.members) do
        team_members[member.actor_id] = -1
    end
    return team_members
end


local function leave_team_dungeon(self)
    self.dungeon_in_playing = const.DUNGEON_NOT_EXIST
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="PlayerLeaveTeamDungeonScene"})
    self:disconnet_fight_server()
    self:fight_send_to_game({func_name="on_fight_avatar_leave_team_dungeon"})
end

--客户端退出副本
function imp_fight_avatar_team_dungeon.on_leave_team_dungeon(self)
    self:on_remove_team_dungeon_member()
    leave_team_dungeon(self)
end

function imp_fight_avatar_team_dungeon.leave_team_dungeon_team(self)
    flog("tmlDebug","imp_fight_avatar_team_dungeon.leave_team_dungeon_team")
    team_dungeon_center:leave_team(self.fight_id,self.actor_id)
end

--玩家中途退出组队
function imp_fight_avatar_team_dungeon.on_fight_avatar_leave_team(self)
    flog("tmlDebug","imp_fight_avatar_team_dungeon.on_fight_avatar_leave")
    if self.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
        self:leave_team_dungeon_team()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
        self:leave_task_dungeon_team()
    end
end

function imp_fight_avatar_team_dungeon.team_member_fight_data_statistics(self, data_type, value)
    fight_data_statistics.update_fight_data_statistics(self.actor_id, data_type, value)
end

function imp_fight_avatar_team_dungeon.on_get_fight_data_statistics(self)
    local captain = self:get_team_captain()
    if captain == nil then
        return
    end

    local statistics, start_time = fight_data_statistics.get_fight_data_statistics(self:get_team_members(), captain.actor_id)
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{func_name="GetFightDataStatisticsRet", statistics = statistics, start_time = start_time})
end

function imp_fight_avatar_team_dungeon.on_reset_fight_data_statistics(self)
    if not self:is_team_captain() then
        return
    end

    local statistics, start_time = fight_data_statistics.reset_fight_data_statistics(self:get_team_members())
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{func_name="GetFightDataStatisticsRet", statistics = statistics, start_time = start_time})
end

function imp_fight_avatar_team_dungeon.is_team_captain(self)
    local team_info = self:get_team_info()
    if team_info ~= nil then
        if team_info.captain_id == self.actor_id then
            return true
        end
    end
    return false
end

function imp_fight_avatar_team_dungeon.get_team_captain(self)
    local team_info = self:get_team_info()
    if team_info ~= nil then
        local player = online_user.get_user(team_info.captain_id)
        return player
    end
    return nil
end

function imp_fight_avatar_team_dungeon.get_team_info(self)
    local team_info = nil
    if self.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
        team_info = team_dungeon_center:get_team_info(self.fight_id)
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
        team_info = task_dungeon_center:get_team_info(self.fight_id)
    end
    return team_info
end

function imp_fight_avatar_team_dungeon.on_follow_captain(self, input)
    --team_follow.add_team_follower(self:get_team_captain(), self)
end

function imp_fight_avatar_team_dungeon.on_cancel_follow(self, input)
    --team_follow.remove_team_follower(self:get_team_captain(), self)
end

function imp_fight_avatar_team_dungeon.start_team_dungeon(self)
    flog("tmlDebug","imp_fight_avatar_team_dungeon.start_team_dungeon")
    if self.team_id ~= nil then
        self:on_connect_team_dungeon_server()
        local dungeon_id = team_dungeon_center:get_player_team_dungeon_id(self.combat_info.actor_id,self.fight_id)
        if dungeon_id ~= nil then
            self:fight_send_to_game({func_name="on_enter_team_dungeon_success",dungeon_id=dungeon_id})
        end
        self.dungeon_in_playing = dungeon_id
        self.drop_manager = team_dungeon_drop_manager
    end
    fight_data_statistics.add_player_data(self.actor_id, self.actor_name, self.vocation)
end

--中途放弃
function imp_fight_avatar_team_dungeon.on_fight_avatar_quit_team_dungeon(self,input)
    flog("tmlDebug","imp_fight_avatar_team_dungeon.on_fight_avatar_quit_team_dungeon")
    self:on_remove_team_dungeon_member()
    leave_team_dungeon(self)
end

function imp_fight_avatar_team_dungeon.on_remove_team_dungeon_member(self)
    team_dungeon_center:on_remove_team_dungeon_member(self.fight_id,self.actor_id)
end

return imp_fight_avatar_team_dungeon