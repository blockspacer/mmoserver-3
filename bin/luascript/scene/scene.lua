--------------------------------------------------------------------
-- 文件名:	scene.lua
-- 版  权:	(C) 华风软件
-- 创建人:	hou(houontherun@gmail.com)
-- 日  期:	2016/08/08
-- 描  述:	场景文件，最小的游戏世界
--------------------------------------------------------------------

local common_scene_config = require "configs/common_scene_config"
local entity_factory = require "entity_factory"
local const = require "Common/constant"
local trigers_manager = require "Common/combat/Trigger/TriggersManager"
local CreateScene = require "Common/CombatScene"
local flog = require "basic/log"
local timer = require "basic/timer"
local math = require "math"
local challenge_main_dungeon_config = require "configs/challenge_main_dungeon_config"
local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"
local challenge_arena_config = require "configs/challenge_arena_config"
local system_task_config = require "configs/system_task_config"
local table = table
local system_faction_config = require "configs/system_faction_config"

local scene = {}
scene.__index = scene

setmetatable(scene, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

function scene.__ctor(self)
    --aoi场景id
    self.scene_id = 0
    --场景在表中的id，竞技场与scene_id不一样
    self.table_scene_id = 0
    self.entitys = {}
    self.actorlist = {}
    self.petlist = {}
    self.npclist = {}
    self.arenadummylist = {}
    self.scene_setting = nil
    self.rebirth_pos = {}
    self.scene_config = nil
    self.is_destroy = false

    -- 战斗逻辑的scene里保存了场景的 TriggerManager，EntityManager，Timer
    self.combat_scene = nil
    self.scene_type = 1
    self.scene_timer = nil
    self.rpc_code = const.SC_MESSAGE_LUA_GAME_RPC
    self.scene_state = const.SCENE_STATE.start
    self.susppend = false
end

function scene.destroy_scene_timer(self)
    if self.scene_timer ~= nil then
        timer.destroy_timer(self.scene_timer)
        self.scene_timer = nil
    end
end

function scene.get_scene_id(self)
    return self.scene_id
end

-- 初始化，添加NPC等位置信息
function scene.init(self,scene_id,scene_config,table_scene_id,scene_setting)
    _info("init scene,id:"..scene_id)
    self.scene_id = scene_id
    self.scene_type = scene_config.SceneType
    self.scene_config = scene_config
    self.table_scene_id = table_scene_id
    self.scene_setting = scene_setting
    self.country = 0

    --初始化复活点
    self.rebirth_pos = {}
    --初始化出生点
    self.born_pos = {}
    for _,v in pairs(self.scene_setting) do
        if v.Type == const.ENTITY_TYPE_POSITION and tonumber(v.Para1) == 1 then
            local pos_info = {v.PosX,v.PosY,v.PosZ }
            pos_info.country = v.Camp
            pos_info.switcher = tonumber(v.Para2)
            table.insert(self.rebirth_pos, pos_info)
        end
        if v.Type == const.ENTITY_TYPE_BIRTHDAY_POS then
            flog("tmlDebug","init scene born pos!!!")
            table.insert(self.born_pos,{v.PosX,v.PosY,v.PosZ,v.ForwardY})
        end
    end

    self.combat_scene = CreateScene(self.scene_id)
end

function scene.add_player(self,entity)
    local err = 0
    local scene_cfg = common_scene_config.get_scene_config(self.table_scene_id)
    if scene_cfg ~= nil then
        if entity:get("level") < scene_cfg.EnterLevel then
        err = const.error_level_not_enough
        return err
        end
    end

    self.entitys[entity.entity_id] = entity
    self.actorlist[entity.entity_id] = entity
    self.combat_scene:GetEntityManager().CreateDummy(entity:get_info_to_scene())

    return err
end

function scene.remove_player(self,entity_id)
    if self.entitys[entity_id] ~= nil then
        self.entitys[entity_id] = nil
    end
    if self.actorlist[entity_id] ~= nil then
        self.actorlist[entity_id] = nil
    end
    self.combat_scene:GetEntityManager().DestroyPuppet(entity_id)
end

function scene.add_arena_dummy(self,entity)
    self.entitys[entity.entity_id] = entity
    self.arenadummylist[entity.entity_id] = entity
    local arena_dummy = self.combat_scene:GetEntityManager().CreateDummy(entity:get_info_to_scene())
    arena_dummy:StartHangup()
end

function scene.remove_arena_dummy(self,entity_id)
    if self.entitys[entity_id] ~= nil then
        self.entitys[entity_id] = nil
    end
    if self.arenadummylist[entity_id] ~= nil then
        self.arenadummylist[entity_id] = nil
    end
    self.combat_scene:GetEntityManager().DestroyPuppet(entity_id)
end

function scene.add_pet(self,entity)
    self.entitys[entity.entity_id] = entity
    self.petlist[entity.entity_id] = entity
    self.combat_scene:GetEntityManager().CreatePet(entity:get_info_to_scene())
end

function scene.remove_pet(self,entity_id)
    if self.entitys[entity_id] ~= nil then
        self.entitys[entity_id] = nil
    end
    if self.petlist[entity_id] ~= nil then
        self.petlist[entity_id] = nil
    end
    self.combat_scene:GetEntityManager().DestroyPuppet(entity_id)
end

function scene.enter_scene(self,entity)
    self.entitys[entity.entity_id] = entity
    if entity.type == const.ENTITY_TYPE_PLAYER then
        self.actorlist[entity.entity_id] = entity
    elseif entity.type == const.ENTITY_TYPE_NPC then
        self.npclist[entity.entity_id] = entity
    elseif entity.type == const.ENTITY_TYPE_PET then
        self.petlist[entity.entity_id] = entity
    elseif entity.type == const.ENTITY_TYPE_ARENA_DUMMY then
        self.arenadummylist[entity.entity_id] = entity
    end
end

function scene.leave_scene(self,entity_id,entity_type)
    local entity = self.entitys[entity_id]
    if entity == nil then
        return
    end

    if self.entitys[entity_id] ~= nil then
        self.entitys[entity_id] = nil
    end
    if entity_type == const.ENTITY_TYPE_PLAYER then
        entity:leave_aoi_scene()
        self.actorlist[entity_id] = nil
    elseif entity_type == const.ENTITY_TYPE_NPC then
        entity:leave_aoi_scene()
        self.npclist[entity_id] = nil
    elseif entity_type == const.ENTITY_TYPE_PET then
        entity:leave_aoi_scene()
        self.petlist[entity.entity_id] = nil
    elseif entity_type == const.ENTITY_TYPE_ARENA_DUMMY then
        entity:leave_aoi_scene()
        self.arenadummylist[entity.entity_id] = nil
    else
        entity:leave_aoi_scene()
        self.combat_scene:GetEntityManager().DestroyPuppet(entity_id)
    end
end

--除了副本，一般不建议踢玩家出地图
function scene.kickout_actor(self)
    if table.isEmptyOrNil(self.actorlist) then
        return
    end
    for _,actor in pairs(self.actorlist) do
        actor:leave_aoi_scene()
    end
end

--全部玩家退出
--清除npc、怪物
function scene.destroy(self)
    --如果玩家没有全部退出本场景，不建议不能摧毁场景
--    if not table.isEmptyOrNil(self.actorlist) then
--        return false
--    end
    --清除npc、怪物等
    for entity_id,entity in pairs(self.entitys) do
        self:leave_scene(entity_id,entity.type)
    end
    self.combat_scene:Clear()
    self:destroy_scene_timer()
    self.is_destroy = true
    return true
end

function scene.get_entity_manager(self)
    return self.combat_scene:GetEntityManager()
end

function scene.get_entity(self,entity_id)
    return self.entitys[entity_id]
end

function scene.destroy_arena_dummy(self,entity_id)
    self:leave_scene(entity_id,const.ENTITY_TYPE_ARENA_DUMMY)
    self.combat_scene:GetEntityManager().DestroyPuppet(entity_id)
end

function scene.destroy_entity(self,entity_id)
    local entity = self.entitys[entity_id]
    if entity == nil then
        return
    end
    if entity.type == const.ENTITY_TYPE_ARENA_DUMMY then
        self:destroy_arena_dummy(entity_id)
    else
        self:leave_scene(entity_id,entity.type)
    end
    --self.leave_scene(entity_id)
    --self.entity_manager.DestroyPuppet(entity_id)
end

function scene.create_trriger_manager(self,schemes,scene_setting_name)
    self.combat_scene:SetScheme(schemes, scene_setting_name)
    self.combat_scene:GetTriggersManager():OnGameBegin(schemes[scene_setting_name])
end

function scene.SetAllEntityEnabled(self,enabled)
    if self.combat_scene:GetEntityManager() == nil then
        return
    end
    self.combat_scene:GetEntityManager().SetAllEntityEnabled(enabled)
    --for _,entity in pairs(self.entitys) do
    --    self.combat_scene:GetEntityManager().SetEntityEnabled(entity.entity_id,enabled)
    --end
end

function scene.SetAllEntityAttackStatus(self,status)
    if self.combat_scene:GetEntityManager() == nil then
        return
    end
    self.combat_scene:GetEntityManager().SetAllEntityAttackStatus(status)
end

function scene.get_scene_type(self)
    return self.scene_type
end

function scene.get_nearest_rebirth_pos(self,current_pos, country)
    if table.isEmptyOrNil(self.rebirth_pos) then
        return nil
    end

    local best = nil
    local best_index = nil
    for i = 1,#self.rebirth_pos,1 do
        local pos_info = self.rebirth_pos[i]
        if pos_info.country == 0 or pos_info.country == country then
            local distance = (pos_info[1] - current_pos[1])*(pos_info[1] - current_pos[1]) + (pos_info[3] - current_pos[3])*(pos_info[3] - current_pos[3])
            if best == nil or distance < best then
                best = distance
                best_index = i
            end
        end
    end
    if best_index ~= nil then
        return self.rebirth_pos[best_index]
    end
    return nil
end

function scene.get_scene_party(self)
    if self.scene_config ~= nil then
        return self.scene_config.Party
    end
    return 0
end

function scene.get_scene_resource_id(self)
    return self.scene_config.SceneID
end

function scene.get_table_scene_id(self)
    return self.table_scene_id
end

function scene.get_random_born_pos(self)
    local born_count = #self.born_pos
    if born_count == 0 then
        return nil
    end
    if born_count == 1 then
        return self.born_pos[born_count]
    end

    local random_index = math.random(born_count)
    return self.born_pos[random_index]
end

function scene.get_rpc_code(self)
    return self.rpc_code
end

function scene.set_scene_state(self,state)
    self.scene_state = state
end

function scene.create_dungeon_npc(self,npc_data)
    if self:get_scene_type() == const.SCENE_TYPE.WILD or self:get_scene_type() == const.SCENE_TYPE.CITY or self:get_scene_type() == const.SCENE_TYPE.FACTION then
        return nil
    end

    return self.combat_scene:GetEntityManager().CreateDungeonNPC(npc_data)
end

function scene.get_unit_number(self,type)
    return self:get_entity_manager().GetNums(type)
end

function scene.is_all_player_leave(self)
    return table.isEmptyOrNil(self.actorlist)
end

function scene.get_scene_setting(self)
    return self.scene_setting
end

function scene.get_total_scene_config(self)
    if self.scene_type == const.SCENE_TYPE.WILD or self.scene_type == const.SCENE_TYPE.CITY then
        return common_scene_config.get_main_scene_table(),common_scene_config.get_scene_scheme_table()
    elseif self.scene_type == const.SCENE_TYPE.DUNGEON then
        local total_scene = challenge_main_dungeon_config.get_challenge_main_dungeon_table()
        return total_scene.NormalTranscript,total_scene
    elseif self.scene_type == const.SCENE_TYPE.TEAM_DUNGEON then
        local total_scene = challenge_team_dungeon_config.get_challenge_team_dungeon_table()
        return total_scene.TeamDungeons,total_scene
    elseif self.scene_type == const.SCENE_TYPE.TASK_DUNGEON then
        local total_scene = system_task_config.get_task_dungeon_table()
        return total_scene.MainTaskTranscript,total_scene
    elseif self.scene_type == const.SCENE_TYPE.ARENA then
        local total_scene = challenge_arena_config.get_total_arena_scene_setting()
        return total_scene.ArenaScene, total_scene
    elseif self.scene_type == const.SCENE_TYPE.FACTION then
        local total_scene = system_faction_config.get_faction_table()
        return total_scene.GangMap, total_scene
    end
    return nil,nil
end

function scene.get_scene_monster_level(self)
    return self.scene_monster_level
end

function scene.set_scene_monster_level(self,value)
    self.scene_monster_level = value
end

function scene.suspend_dungeon(self)
    flog("tmlDebug","scene.suspend_dungeon")
    if self.scene_type == const.SCENE_TYPE.DUNGEON or self.scene_type == const.SCENE_TYPE.TEAM_DUNGEON or self.scene_type == const.SCENE_TYPE.TASK_DUNGEON then
        self.susppend = true
        _suspend_dungeon(self.scene_id)
        self:SetAllEntityAttackStatus(false)
    end
end

function scene.recover_dungeon(self)
    if self.scene_type == const.SCENE_TYPE.DUNGEON or self.scene_type == const.SCENE_TYPE.TEAM_DUNGEON or self.scene_type == const.SCENE_TYPE.TASK_DUNGEON then
        self.susppend = false
        _recover_dungeon(self.scene_id)
        self:SetAllEntityAttackStatus(true)
    end
end

function scene.get_element_config(self,id)
    return self.scene_setting[id]
end

function scene.get_susppend(self)
    return self.susppend
end

function scene.get_nearby_avatars(self,distance,x,y,z)
    local avatars = {}
    for i,v in pairs(self.actorlist) do
        local x1,y1,z1 = v:get_pos()
        if math.pow(x - x1,2) + math.pow(y - y1,2) + math.pow(z-z1,2) < math.pow(distance,2) then
            table.insert(avatars,v)
        end
    end
    return avatars
end

function scene.get_player_count(self)
    local count = 1
    for _,_ in pairs(self.actorlist) do
        count = count + 1
    end
    return count
end

function scene.switch_birth_pos_country(self, monster_scene_id, country)
    for i, pos_info in pairs(self.rebirth_pos) do
        if pos_info.switcher == monster_scene_id then
            pos_info.country = country
        end
    end
end

return scene