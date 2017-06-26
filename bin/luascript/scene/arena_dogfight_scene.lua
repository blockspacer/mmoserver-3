--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/19 0019
-- Time: 15:08
-- To change this template use File | Settings | File Templates.
--

local challenge_arena_table = require "data/challenge_arena"
local const = require "Common/constant"
local timer = require "basic/timer"
local create_add_up_table = require("basic/scheme").create_add_up_table
local get_random_index_with_weight_by_count = require("basic/scheme").get_random_index_with_weight_by_count
local common_fight_base = require "data/common_fight_base"
local MonsterAttribute = common_fight_base.Attribute
local flog = require "basic/log"
local math = require "math"
local get_random_index_with_weight_by_count = require("basic/scheme").get_random_index_with_weight_by_count
local common_parameter_formula = require "data/common_parameter_formula"
require "Common/combat/Entity/EntityManager"
local EntityType = EntityType
local _get_now_time_second = _get_now_time_second
local net_work = require "basic/net"
local fight_send_to_game = net_work.fight_send_to_game
local challenge_arena_config = require "configs/challenge_arena_config"
local scheme = require "basic/scheme"
local dogfight_arena_fight_center = require "fight_server/dogfight_arena_fight_center"
local objectid = objectid
local table = table


local ARENA_TYPE = const.ARENA_TYPE
local arena_parameter = challenge_arena_table.Parameter


local dogfight_refresh_configs = {}
for _,v in pairs(challenge_arena_table.Refresh) do
    dogfight_refresh_configs[v.Type] = v
end

local dogfight_monster_configs = {}
for _,v in pairs(challenge_arena_table.AggressionMonster) do
    dogfight_monster_configs[v.ID] = v
end

local arena_monster_configs = {}
for _,v in pairs(challenge_arena_table.MonsterSetting) do
    arena_monster_configs[v.ID] = v
end

--混战赛斗兽刷新位置
local dogfight_monster_buff_pos = {}
local scene_setting = challenge_arena_table[challenge_arena_table.ArenaScene[const.ARENA_DOGFIGHT_SCENE_ID].SceneSetting]
if scene_setting ~= nil then
    for _,setting in pairs(scene_setting) do
        if setting.Type == const.ENTITY_TYPE_POSITION and tonumber(setting.Para1) == 2 then
            table.insert(dogfight_monster_buff_pos,{setting.PosX,setting.PosY,setting.PosZ,setting.ForwardY})
        end
    end
end
local dogfight_monster_buff_pos_count = #dogfight_monster_buff_pos
if dogfight_monster_buff_pos_count == 0 then
    flog("error","can not init arena qualifying born pos!")
end

--buff刷新
local dogfight_buffs = {}
local dogfight_buffs_weight = {}
for _,v in pairs(challenge_arena_table.BUFF) do
    table.insert(dogfight_buffs,v.ID)
    table.insert(dogfight_buffs_weight,v.Probability)
end
dogfight_buffs_weight = create_add_up_table(dogfight_buffs_weight)
local function generate_buff()
    local index = get_random_index_with_weight_by_count(dogfight_buffs_weight)
    return dogfight_buffs[index]
end

local buff_distance = common_parameter_formula.Parameter[28].Parameter/100

local dogfight_refresh_type=
{
    monster = 1,
    buff = 2,
}

local arena_dogfight_scene = {}
arena_dogfight_scene.__index = arena_dogfight_scene

setmetatable(arena_dogfight_scene, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

function arena_dogfight_scene.__ctor(self)
    self.room_id = 0
    self.dogfight = false
    self.grade_id = 0
    self.first_refresh_monster = true
    self.monster_refresh_time = 0
    self.first_refresh_buff = true
    self.buff_refresh_time = 0
    self.bufflist = {}
    self.score_area_start_time = 0
    self.score_area = nil
    self.notice_client_score_area = false
    --积分刷新数据
    --有人占领
    self.occupy = false
    --已占领的玩家
    self.occupy_actor = nil
    --已占领积分进度
    self.occupy_score_progress = 0
    --有人抢夺
    self.plunder = false
    --正在抢夺的玩家
    self.plunder_actor = nil
    --正在抢夺的进度
    self.plunder_progress = 0
    --抢夺状态
    self.plunder_state = 0
    --开战计时器
    self.start_fight_timer = nil
    --开战时间
    self.start_fight_time = nil

    local module_name = "scene/scene"
    local module = require(module_name)()

    for i, v in pairs(module) do
        self[i] = v
    end
    local moudule_metatable = getmetatable(module)
    for i, v in pairs(moudule_metatable) do
        if string.sub(i,1,2) ~= "__" then
            arena_dogfight_scene[i] = v
        end
    end
end

local function arena_scene_timer_handler(self)
    local current_time = _get_now_time_second()
    --混战赛
    if self.dogfight == true then
        if self.grade_id > 0 then
            --斗兽
            self:refresh_monster(current_time)
            --buff
            self:refresh_buff(current_time)
            --积分点
            self:score_area_refresh(current_time)
            --检测是否触碰buff
            self:check_arena_buff()
            --检查是否已完成
            self:check_state()
        end
    end
    if self.scene_state == const.SCENE_STATE.start and self.start_fight_time ~= nil and current_time >= self.start_fight_time then
        flog("tmlDebug","qualifying arena fight start!")
        self.scene_state = const.SCENE_STATE.doing
        self:SetAllEntityEnabled(true)
        self:SetAllEntityAttackStatus(true)
        if self.dogfight == true and self.game_id ~= nil and self.room_id ~= nil then
            fight_send_to_game(self.game_id,const.GCA_MESSAGE_LUA_GAME_RPC,{func_name="on_dogfight_arena_start_fight",room_id=self.room_id})
        end
    end
end

function arena_dogfight_scene.refresh_monster(self,current_time)
    if dogfight_refresh_configs[dogfight_refresh_type.monster] ~= nil then
        if self.monster_refresh_time == 0 then
            if self:get_unit_number(EntityType.Monster) <= 0 then
                --场景开始
                if self.first_refresh_monster == true then
                    self.monster_refresh_time = current_time + dogfight_refresh_configs[dogfight_refresh_type.monster].AppearingTime/1000
                else
                    self.monster_refresh_time = current_time + dogfight_refresh_configs[dogfight_refresh_type.monster].Interval
                end
            end
        elseif self.monster_refresh_time > 0 then
            if current_time > self.monster_refresh_time then
                if self:get_unit_number(EntityType.Monster) <= 0 then
                    self.monster_refresh_time = 0
                    --刷新斗兽
                    local select_monsters = {}
                    local select_monsters_weight = {}
                    for _,v in pairs(dogfight_monster_configs) do
                        if self.grade_id <= v.Iduplimit and self.grade_id >= v.Idlowlimit then
                            table.insert(select_monsters,v.ID)
                            table.insert(select_monsters_weight,v.Weight)
                        end
                    end
                    select_monsters_weight = create_add_up_table(select_monsters_weight)
                    local random_pos = {}
                    if dogfight_monster_buff_pos_count > dogfight_refresh_configs[dogfight_refresh_type.monster].Number then
                        local pos_count = 0
                        for i = 1,100000,1 do
                            local pos_index = math.random(dogfight_monster_buff_pos_count)
                            local b = false
                            for j = 1,#random_pos,1 do
                                if pos_index == random_pos[j] then
                                    b = true
                                    break
                                end
                            end
                            if b == false then
                                table.insert(random_pos,pos_index)
                                pos_count = pos_count + 1
                            end
                            if pos_count >= dogfight_refresh_configs[dogfight_refresh_type.monster].Number then
                                break
                            end
                        end
                    else
                        for i = 1,dogfight_monster_buff_pos_count,1 do
                            table.insert(random_pos,i)
                        end
                    end

                    local level = 0
                    for i=1,dogfight_refresh_configs[dogfight_refresh_type.monster].Number,1 do
                        local aggression_config = dogfight_monster_configs[select_monsters[get_random_index_with_weight_by_count(select_monsters_weight)]]
                        if aggression_config ~= nil then
                            if level == 0 then
                                local levels = {}
                                for _,actor in pairs(self.actorlist) do
                                    table.insert(levels,actor.level)
                                end
                                level = scheme.get_monster_level_by_levels(levels)
                            end
                            local pos = nil
                            if i > #random_pos then
                                pos = dogfight_monster_buff_pos[random_pos[#random_pos]]
                            else
                                pos = dogfight_monster_buff_pos[random_pos[i]]
                            end
                            aggression_config.PosX = pos[1]
                            aggression_config.PosY = pos[2]
                            aggression_config.PosZ = pos[3]
                            local monster = self:get_entity_manager().CreateScenePuppet(aggression_config,EntityType.Monster)
                            local rotation = {}
                            rotation.eulerAngles = {}
                            rotation.eulerAngles.y = pos[4]
                            monster:SetRotation(rotation)
                            monster:SetLevel(level)
                        end
                    end
                end
            end
        end
    else
        flog("tmlDebug","arena_scene_timer_handler.arena_dogfight_scene can not find monster refresh config")
    end
end

function arena_dogfight_scene.refresh_buff(self,current_time)
    if dogfight_refresh_configs[dogfight_refresh_type.buff] ~= nil then
        if self.buff_refresh_time == 0 then
            if table.isEmptyOrNil(self.bufflist) == true then
                --场景开始
                if self.first_refresh_buff == true then
                    self.buff_refresh_time = current_time + dogfight_refresh_configs[dogfight_refresh_type.buff].AppearingTime/1000
                else
                    self.buff_refresh_time = current_time + dogfight_refresh_configs[dogfight_refresh_type.buff].Interval
                end
            end
        elseif self.buff_refresh_time > 0 then
            if current_time > self.buff_refresh_time then
                if table.isEmptyOrNil(self.bufflist) == true then
                    self.buff_refresh_time = 0
                    local random_pos = {}
                    if dogfight_monster_buff_pos_count > dogfight_refresh_configs[dogfight_refresh_type.buff].Number then
                        local pos_count = 0
                        local pos_indexs = {}
                        for i=1,dogfight_monster_buff_pos_count,1 do
                            table.insert(pos_indexs,i)
                        end

                        for i = 1,dogfight_refresh_configs[dogfight_refresh_type.buff].Number,1 do
                            local pos_index = math.random(#pos_indexs)
                            table.insert(random_pos,pos_indexs[pos_index])
                            table.remove(pos_indexs,pos_index)
                        end
                    else
                        for i = 1,dogfight_monster_buff_pos_count,1 do
                            table.insert(random_pos,i)
                        end
                    end
                    self.bufflist = {}
                    for i = 1,#random_pos,1 do
                        self.bufflist[objectid()] = {buff=generate_buff(),pos=dogfight_monster_buff_pos[random_pos[i]]}
                    end
                    --flog("tmlDebug","generate buff info:"..table.serialize(self.bufflist))
                    self:broadcast_buff_list()
                end
            end
        end
    else
        flog("tmlDebug","arena_scene_timer_handler.arena_dogfight_scene can not find monster refresh config")
    end
end

function arena_dogfight_scene.score_area_refresh(self,current_time)
    if self.scene_state == const.SCENE_STATE.start then
        return
    end

    if self.score_area_start_time > 0 and current_time > self.score_area_start_time then
        if self.notice_client_score_area == false then
            for _,entity in pairs(self.actorlist) do
                entity:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_SCORE_AREA,{})
            end
            self.notice_client_score_area = true
        end
        local area_actors = {}
        local current_actor = nil
        local current_count = 0
        for _,entity in pairs(self.actorlist) do
            local posx,posy,posz = entity:get_pos()
            if posx ~= nil and posy ~= nil and posz ~= nil then
                if (posx - self.score_area.x)*(posx - self.score_area.x) + (posz - self.score_area.z)*(posz - self.score_area.z) <= self.radius*self.radius then
                    current_count = current_count + 1
                    current_actor = entity.entity_id
                end
            end
        end

        --积分进度，只要没有新的占领者，积分就一直给
        if self.occupy == true and challenge_arena_config.get_occupy_score_interval() ~= nil then
            if self.occupy_actor ~= nil then
                self.occupy_progress = self.occupy_progress + 1
                if self.occupy_progress >= challenge_arena_config.get_occupy_score_interval() then
                    self.occupy_progress = 0
                    --加积分
                    dogfight_arena_fight_center:add_dogfight_occupy_score(self.fight_id,self.occupy_actor,challenge_arena_config.get_occupy_score(self.grade_id))
                end
            end
        end

        --抢夺进度
        --多人和无人时抢夺进度都不会增加
        --抢夺状态是否变动
        local state_dif = false
        if current_count > 1 or current_count == 0 then
            if self.plunder == true and self.plunder_state == 1 then
                self.plunder_state = 0
                state_dif = true
            end
        elseif current_count == 1 then
            --只有一个玩家
            if self.plunder == true then
                --已有人在争夺中
                if self.plunder_actor ~= nil and current_actor == self.plunder_actor then
                    if self.plunder_state == 0 then
                        self.plunder_state = 1
                        state_dif = true
                    else
                        self.plunder_progress = self.plunder_progress + 1
                        if self.plunder_progress >= arena_parameter[28].Value[1] then
                            --占领
                            if self.occupy_actor == nil or current_actor ~= self.occupy_actor then
                                self.occupy_actor = current_actor
                                self.occupy_progress = 0
                                self.occupy = true
                                state_dif = true
                                self.plunder = false
                                self.plunder_progress = 0
                                self.plunder_actor = nil
                                self.plunder_state = 0
                            end
                        end
                    end
                else
                    --新的争夺者
                    self.plunder_actor = current_actor
                    self.plunder_progress = 0
                    self.plunder_state = 1
                    state_dif = true
                end
            elseif self.occupy_actor == nil or current_actor ~= self.occupy_actor then
                --没有人在抢夺，如果不是占领者,则开始抢夺
                self.plunder = true
                self.plunder_actor = current_actor
                self.plunder_progress = 0
                self.plunder_state = 1
                state_dif = true
            end
        end
        --如果抢夺状态改变
        if state_dif == true then
            local occupy_actor_name = ""
            if self.occupy_actor ~= nil then
                local entity = self.actorlist[self.occupy_actor]
                if entity ~= nil then
                    occupy_actor_name = entity:get("actor_name")
                end
            end
            local plunder_actor_name = ""
            if self.plunder_actor ~= nil then
                local entity = self.actorlist[self.plunder_actor]
                if entity ~= nil then
                    plunder_actor_name = entity:get("actor_name")
                end
            end

            for _,entity in pairs(self.actorlist) do
                entity:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_OCCUPY_INFO,{occupy=self.occupy,occupy_actor_id=self.occupy_actor,occupy_actor_name=occupy_actor_name,plunder=self.plunder,plunder_actor_id=self.plunder_actor,plunder_progress=self.plunder_progress,plunder_actor_name=plunder_actor_name,plunder_state=self.plunder_state})
            end
        end
    end
end

function arena_dogfight_scene.check_arena_buff(self)
    if self.combat_scene == nil then
        return
    end
    local entity_manager = self.combat_scene:GetEntityManager()
    if entity_manager == nil then
        return
    end
    if table.isEmptyOrNil(self.bufflist) then
        return
    end

    local buff_dif = false

    for _,entity in pairs(self.actorlist) do
        local puppet = entity_manager.GetPuppet(entity.entity_id)
        if puppet ~= nil and not puppet:IsDied() then
            local posx,posy,posz = entity:get_pos()
            if posx ~= nil and posy ~= nil and posz ~= nil then
                for bid,buff in pairs(self.bufflist) do
                    local distance = (posx - buff.pos[1])*(posx - buff.pos[1]) + (posz - buff.pos[3])*(posz - buff.pos[3])
                    if distance < buff_distance*buff_distance then
                        local skill_manager = puppet.skillManager
                        if skill_manager ~= nil then
                            skill_manager:AddBuff(buff.buff)
                            self.bufflist[bid] = nil
                            buff_dif = true
                        end
                        break
                    end
                end
            end
        end
    end
    if buff_dif then
        self:broadcast_buff_list()
    end
end

function arena_dogfight_scene.broadcast_buff_list(self)
    local data = {}
    data.result = 0
    data.buffs = {}
    for bid,buff in pairs(self.bufflist) do
        data.buffs[bid] = {buff=buff.buff,pos={math.floor(buff.pos[1]*100),math.floor(buff.pos[2]*100),math.floor(buff.pos[3]*100)}}
    end

    for _,entity in pairs(self.actorlist) do
        entity:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_BUFF_LIST,data)
    end
end

function arena_dogfight_scene.check_state(self)
    if self.scene_state == const.SCENE_STATE.done then
        if table.isEmptyOrNil(self.actorlist) then
            arena_scene_manager.destroy_scene(self.scene_id)
        end
    end
end

function arena_dogfight_scene.initialize(self,scene_id,scene_config,table_scene_id,scene_scheme)
    flog("tmlDebug","arena_dogfight_scene.initialize,table_scene_id:"..table_scene_id)
    local arena_scene_table = challenge_arena_table.ArenaScene
    if arena_scene_table ~= nil then
        if arena_scene_table[table_scene_id] ~= nil then
            if arena_scene_table[table_scene_id].JJCType == ARENA_TYPE.dogfight then
                self.dogfight = true
                self:destroy_scene_timer()
                self.score_area_start_time = _get_now_time_second() + arena_parameter[29].Value[1]
                local setting = challenge_arena_table[arena_scene_table[table_scene_id].SceneSetting]
                if setting ~= nil and arena_parameter[41].Value[1] ~= nil and arena_parameter[41].Value[2] ~= nil then
                    local pos_config = setting[arena_parameter[41].Value[1]]
                    if pos_config ~= nil then
                        self.score_area = {}
                        self.score_area.x = pos_config.PosX
                        self.score_area.y = pos_config.PosY
                        self.score_area.z = pos_config.PosZ
                        self.radius = arena_parameter[41].Value[2]/100
                    end
                end
            else
                self.dogfight = false
            end
            local function scene_timer_handler()
                arena_scene_timer_handler(self)
            end
            self.scene_timer = timer.create_timer(scene_timer_handler,1000,const.INFINITY_CALL)
        else
            flog("tmlDebug","arena_dogfight_scene.initialize,can not find scene config!")
        end
    end
    self:init(scene_id,scene_config,table_scene_id,scene_scheme)
    self.rpc_code = const.DC_MESSAGE_LUA_GAME_RPC
end

function arena_dogfight_scene.destroy_start_fight_timer(self)
    if self.start_fight_timer ~= nil then
        timer.destroy_timer(self.start_fight_timer)
        self.start_fight_timer = nil
    end
end

function arena_dogfight_scene.set_room_id(self,room_id)
    self.room_id = room_id
end

function arena_dogfight_scene.get_room_id(self)
    return self.room_id
end

function arena_dogfight_scene.set_grade_id(self,grade_id)
    self.grade_id = grade_id
end

function arena_dogfight_scene.get_grade_id(self)
    return self.grade_id
end

function arena_dogfight_scene.is_dogfight(self)
    return self.dogfight
end

function arena_dogfight_scene.set_start_fight_time(self,value)
    flog("tmlDebug","arena_dogfight_scene.set_start_fight_time "..value)
    self.start_fight_time = value
end

function arena_dogfight_scene.get_start_fight_time(self)
    return self.start_fight_time
end

function arena_dogfight_scene.set_game_id(self,game_id)
    self.game_id = game_id
end

function arena_dogfight_scene.set_fight_id(self,fight_id)
    self.fight_id = fight_id
end

function arena_dogfight_scene.player_enter_scene_after_start(self,entity)
    --如果积分点已经出现
    if self.notice_client_score_area then
        entity:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_SCORE_AREA,{})
    end
    --buff点
    if not table.isEmptyOrNil(self.bufflist) then
        local data = {}
        data.result = 0
        data.buffs = {}
        for bid,buff in pairs(self.bufflist) do
            data.buffs[bid] = {buff=buff.buff,pos={math.floor(buff.pos[1]*100),math.floor(buff.pos[2]*100),math.floor(buff.pos[3]*100)}}
        end
        entity:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_BUFF_LIST,data)
    end
    if self.occupy or self.plunder then
        local occupy_actor_name = ""
        if self.occupy_actor ~= nil then
            local entity = self.actorlist[self.occupy_actor]
            if entity ~= nil then
                occupy_actor_name = entity:get("actor_name")
            end
        end
        local plunder_actor_name = ""
        if self.plunder_actor ~= nil then
            local entity = self.actorlist[self.plunder_actor]
            if entity ~= nil then
                plunder_actor_name = entity:get("actor_name")
            end
        end
        entity:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_OCCUPY_INFO,{occupy=self.occupy,occupy_actor_id=self.occupy_actor,occupy_actor_name=occupy_actor_name,plunder=self.plunder,plunder_actor_id=self.plunder_actor,plunder_progress=self.plunder_progress,plunder_actor_name=plunder_actor_name,plunder_state=self.plunder_state})
    end
end

return arena_dogfight_scene

