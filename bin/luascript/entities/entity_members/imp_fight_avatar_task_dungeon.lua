--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/22 0022
-- Time: 18:23
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local math = require "math"
local drop_manager = require("helper/drop_manager")
local task_dungeon_drop_manager = drop_manager("task_dungeon")
local online_user = require "fight_server/fight_server_online_user"
local fight_data_statistics = require "helper/fight_data_statistics"
--local team_follow = require "helper/team_follow"
local task_dungeon_center = require "fight_server/task_dungeon_center"

local imp_fight_avatar_task_dungeon = {}
imp_fight_avatar_task_dungeon.__index = imp_fight_avatar_task_dungeon

setmetatable(imp_fight_avatar_task_dungeon, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {

}
imp_fight_avatar_task_dungeon.__params = params

function imp_fight_avatar_task_dungeon.__ctor(self)

end

function imp_fight_avatar_task_dungeon.imp_fight_avatar_task_dungeon_init_from_dict(self, dict)
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

function imp_fight_avatar_task_dungeon.on_connect_task_dungeon_server(self)
    flog("tmlDebug","imp_fight_avatar_task_dungeon.on_connect_task_dungeon_server")
    local reply_data = {}
    reply_data.func_name = "ConnectTaskDungeonServerReply"
    local is_member = task_dungeon_center:check_player(self.actor_id,self.fight_id)
    if is_member == true then
        local aoi_scene_id = task_dungeon_center:get_aoi_scene_id(self.fight_id)
        if aoi_scene_id == nil then
            flog("tmlDebug","imp_fight_avatar_task_dungeon.on_connect_task_dungeon_server aoi_scene_id == nil")
            reply_data.result = const.error_scene_not_exist
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end

        local scene = task_dungeon_scene_manager.find_scene(aoi_scene_id)
        if scene == nil then
            flog("tmlDebug","imp_fight_avatar_task_dungeon.on_connect_task_dungeon_server scene == nil")
            reply_data.result = const.error_scene_not_exist
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end
        local born_pos = scene:get_random_born_pos()
        if born_pos == nil then
            flog("tmlDebug","imp_fight_avatar_task_dungeon.on_connect_task_dungeon_server born_pos == nil")
            reply_data.result = const.error_can_not_find_scene_born_pos
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end

        reply_data.result = 0
        self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
        self.posX = born_pos[1]
        self.posY = born_pos[2]
        self.posZ = born_pos[3]
        self.rotation = born_pos[4]
        self:load_aoi_scene(aoi_scene_id,scene:get_table_scene_id(),scene:get_scene_id(),scene:get_scene_type(),scene:get_scene_resource_id())
        --[[if self.team_state == "follow" then
            team_follow.add_team_follower(self:get_team_captain(), self)
        end]]
    else
        reply_data.result = const.error_task_dungeon_is_not_member
        self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
        return
    end
end

local function leave_task_dungeon(self)
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="PlayerLeaveTaskDungeonScene"})
    self:disconnet_fight_server()
    self:fight_send_to_game({func_name="on_fight_avatar_leave_task_dungeon"})
    self:leave_task_dungeon()
end

--客户端退出副本
function imp_fight_avatar_task_dungeon.on_leave_task_dungeon(self)
    flog("tmlDebug","imp_fight_avatar_task_dungeon.on_leave_task_dungeon actor "..self.actor_id)
    self:on_remove_task_dungeon_member()
    leave_task_dungeon(self)
end

function imp_fight_avatar_task_dungeon.leave_task_dungeon_team(self)
    flog("tmlDebug","imp_fight_avatar_team_dungeon.leave_task_dungeon_team actor_id "..self.actor_id)
    task_dungeon_center:leave_team(self.fight_id,self.actor_id)
end

function imp_fight_avatar_task_dungeon.start_task_dungeon(self)
    flog("tmlDebug","imp_fight_avatar_task_dungeon.start_task_dungeon")
    self:on_connect_task_dungeon_server()
    local dungeon_id = task_dungeon_center:get_dungeon_id(self.actor_id,self.fight_id)
    if dungeon_id ~= nil then
        self:fight_send_to_game({func_name="on_enter_task_dungeon_success",dungeon_id=dungeon_id})
    end
    self.dungeon_in_playing = dungeon_id
    self.drop_manager = task_dungeon_drop_manager
    fight_data_statistics.add_player_data(self.actor_id, self.actor_name, self.vocation)
end

--中途放弃
function imp_fight_avatar_task_dungeon.on_fight_avatar_quit_task_dungeon(self,input)
    flog("tmlDebug","imp_fight_avatar_team_dungeon.on_fight_avatar_quit_task_dungeon")
    self:on_remove_task_dungeon_member()
    leave_task_dungeon(self)
end

function imp_fight_avatar_task_dungeon.on_remove_task_dungeon_member(self)
    task_dungeon_center:on_remove_task_dungeon_member(self.fight_id,self.actor_id)
end

return imp_fight_avatar_task_dungeon

