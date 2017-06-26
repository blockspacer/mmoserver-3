--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/3 0003
-- Time: 17:52
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local fight_server_message_center = require "fight_server/fight_server_message_center"
local math = require "math"
local team_dungeon_center = require "team_dungeon/team_dungeon_center"
local task_dungeon_center = require "fight_server/task_dungeon_center"
local main_dungeon_center = require "fight_server/main_dungeon_center"
local fight_avatar_connect_state = require "fight_server/fight_avatar_connect_state"

local imp_fight_avatar_aoi = {}
imp_fight_avatar_aoi.__index = imp_fight_avatar_aoi

setmetatable(imp_fight_avatar_aoi, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {
}
imp_fight_avatar_aoi.__params = params

function imp_fight_avatar_aoi.__ctor(self)
    self.aoi_proxy = nil
    self.scene = nil
    self.entity_info = {}
end

function imp_fight_avatar_aoi.can_enter_scene(self,scene_id)
    return 0
end

function imp_fight_avatar_aoi.load_aoi_scene(self,aoi_scene_id,scene_id,aoi_scene_id,scene_type,scene_resource_id)
    flog("tmlDebug","imp_fight_avatar_aoi.load_aoi_scene")
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="FightServerLoadSceneRet",aoi_scene_id=aoi_scene_id,scene_id=scene_id,aoi_scene_id=aoi_scene_id,scene_type=scene_type,scene_resource_id=scene_resource_id,fight_type=self.fight_type,posX=math.floor(self.posX*100),posY=math.floor(self.posY*100),posZ=math.floor(self.posZ*100)})
end

--重新连接时
function imp_fight_avatar_aoi.enter_aoi_scene(self)
    flog("tmlDebug","imp_fight_avatar_aoi.enter_aoi_scene fight_type "..self.fight_type)
    if self.scene ~= nil then
        self:leave_aoi_scene()
    end
    local scene = scene_manager.find_scene(self.scene_id)
    if scene ~= nil then
        scene:add_player(self)
        self:pet_enter_scene()
        self.scene = scene
    else
        flog("tmlDebug","can not find scene:"..self.scene_id)
    end
end

function imp_fight_avatar_aoi.on_enter_aoi_scene(self,input)
    flog("tmlDebug","imp_fight_avatar_aoi.on_enter_aoi_scene fight_type "..self.fight_type)
    local reply_data = {}
    reply_data.result = 0
    reply_data.func_name = "EnterAoiSceneReply"
    --顶号？
    self:reconnect(false)
--    if self.scene ~= nil then
--        self:leave_aoi_scene()
--    end
    if self.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
        self.scene = team_dungeon_scene_manager.find_scene(input.aoi_scene_id)
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.MAIN_DUNGEON then
        self.scene = main_dungeon_scene_manager.find_scene(input.aoi_scene_id)
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA or self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
        self.scene = arena_scene_manager.find_scene(input.aoi_scene_id)
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
        self.scene = task_dungeon_scene_manager.find_scene(input.aoi_scene_id)
    end
    if self.scene ~= nil then
        self.scene_id = input.aoi_scene_id
        self.scene:add_player(self)
        self:pet_enter_scene()
    else
        flog("tmlDebug","can not find scene:"..input.aoi_scene_id)
        reply_data.result = const.error_scene_not_exist
        reply_data.aoi_scene_id = input.aoi_scene_id
    end
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
    if reply_data.result == 0 then
        self:fight_send_to_game({func_name="on_fight_avatar_enter_aoi_scene"})
        if self.replace == nil or self.replace == false then
            self.replace = false
            if self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
                self:qualifying_arena_start()
            elseif self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
                self:dogfight_arena_start()
            end
        else
            if self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
                self:qualifying_arena_replace()
            elseif self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
                self:dogfight_arena_replace()
            end
        end
        if self.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
            task_dungeon_center:send_mark_to_client(self.fight_id,self.actor_id,true)
        elseif self.fight_type == const.FIGHT_SERVER_TYPE.MAIN_DUNGEON then
            main_dungeon_center:send_mark_to_client(self.fight_id,self.actor_id,true)
        elseif self.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
            team_dungeon_center:send_mark_to_client(self.fight_id,self.actor_id,true)
        end
    end
    return
end

function imp_fight_avatar_aoi.leave_aoi_scene(self)
    self:pet_leave_scene()
    if self.scene ~= nil then
        self.scene:remove_player(self.entity_id)
        self.scene = nil
    end
    return 0
end

function imp_fight_avatar_aoi.get_info_to_scene(self)
    local data = {}
    data.entity_id = self.entity_id
    data.actor_name = self.actor_name
    data.actor_id = self.actor_id
    data.posX = self.posX
    data.posY = self.posY
    data.posZ = self.posZ
    data.level = self.level
    data.vocation = self.vocation
    data.country = self.country
    data.sex = self.sex
    data.current_hp = self.current_hp
    data.scene_id = self.scene_id
    data.property = self.combat_info.property
    --技能
    data.cur_plan = self.combat_info.cur_plan
    data.skill_level = self.combat_info.skill_level
    data.skill_plan = self.combat_info.skill_plan
    for index, value in pairs(self.combat_info.appearance) do
        local aoi_index = self.get_appearance_aoi_index(index)
        data['appearance_'..aoi_index] = value
    end
    table.update(data, self.combat_info.immortal_data)

    data.server_object = self
    return data
end

function imp_fight_avatar_aoi.on_client_disconnet_fight_server(self,input)
    self:fight_send_to_game({func_name="on_fight_avatar_leave_scene"})
    fight_server_message_center:on_game_message(self.src_game_id,const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_logout",actor_id=self.actor_id})
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="ClientDisconnetFightServerRet"})
    self.connect_state = fight_avatar_connect_state.done
end

function imp_fight_avatar_aoi.get_appearance_aoi_index(part_id)
    return part_id - 900
end

return imp_fight_avatar_aoi



