---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/13
-- desc： 单位的事件delegate
---------------------------------------------------



local wild_elite_boss_class = require("boss/wild_elite_boss")
local flog = require "basic/log"
local const = require "Common/constant"
local timer = require "basic/timer"
local common_fight_base_config = require "configs/common_fight_base_config"
local get_entity_of_owner = require("helper/delegate_common").get_entity_of_owner
local country_monster = require("boss/country_monster")
local get_config_name = require("basic/scheme").get_config_name
local fix_string = require "basic/fix_string"


local function data_statistics_on_cause_damage(owner, target_entity, damage)
    if target_entity ~= nil and target_entity.on_be_attacked ~= nil then
        target_entity:on_be_attacked(owner.uid, damage)
    end
end

local function wild_elit_boss_on_tabe_damage(owner, attacker_entity, pet_entity, damage)
    local wild_elite_boss = owner.wild_elite_boss
    if wild_elite_boss ~= nil then
        local anger_value_changed = false
        if attacker_entity ~= nil then
            if wild_elite_boss:is_finish_condition_once_damage(damage, attacker_entity.actor_id) then
                anger_value_changed = true
            end
        end
        if pet_entity ~= nil then
            if wild_elite_boss:is_finish_condition_pet_skill(pet_entity.skill_info ,pet_entity.entity_id) then
                anger_value_changed = true
            end
        end
        if anger_value_changed then
            owner:SetAngerValue(wild_elite_boss:get_anger_value())
        end
    end
end

local function wild_elit_boss_on_died(owner, killer_entity, monster_data)
    local wild_elite_boss = owner.wild_elite_boss
    if wild_elite_boss ~= nil then
        local anger_value_changed = false
        if killer_entity.get_team_members_number ~= nil then
            local team_members_number = killer_entity:get_team_members_number()
            if wild_elite_boss:is_finish_condition_team_member(team_members_number) then
                anger_value_changed = true
            end
        end
        if wild_elite_boss:is_finish_condition_damage_count(killer_entity.actor_id) then
            anger_value_changed = true
        end
        monster_data.anger_value = wild_elite_boss:get_anger_value()
        if anger_value_changed then
            owner:SetAngerValue(wild_elite_boss:get_anger_value())
        end
    end
end

local function wild_elit_boss_on_born(owner, monster_id)
    if owner:GetMonsterSetting(monster_id).Type == const.MONSTER_TYPE.WILD_ELITE_BOSS then
        local level = wild_elite_boss_class.get_boss_level(monster_id)
        owner:SetLevel(level)
    end
end

local function wild_elit_boss_on_hatred_changed(owner, monster_id, hatred_list)
    local wild_elite_boss = owner.wild_elite_boss
    if owner:GetMonsterSetting(monster_id).Type == const.MONSTER_TYPE.WILD_ELITE_BOSS and wild_elite_boss ~= nil then
        local scene_id = owner:GetSceneID()
        local scene = scene_manager.find_scene(scene_id)
        if scene == nil then
            flog("syzDebug","self.OnHatredChanged scene == nil")
            return
        end
        local player_entity_list = {}
        for _, entity_id in pairs(hatred_list) do
            local entity = scene:get_entity(entity_id)
            if entity.type == const.ENTITY_TYPE_PLAYER then
                table.insert(player_entity_list, entity)
            end
        end
        local anger_value_changed = false

        if wild_elite_boss:is_finish_condition_hatred_country(player_entity_list) then
            anger_value_changed = true
        end
        if wild_elite_boss:is_finish_condition_hatred_number(#player_entity_list) then
            anger_value_changed = true
        end
        if anger_value_changed then
            owner:SetAngerValue(wild_elite_boss:get_anger_value())
        end
    end
end

local function wild_elit_boss_on_off_fight(owner)
    if owner.anger_timer ~= nil then
        timer.destroy_timer(owner.anger_timer)
        owner.anger_timer = nil
    end

    if not owner:IsDied() and owner.wild_elite_boss ~= nil then
        flog("syzDebug", "elite boss cancel fight")
        owner.wild_elite_boss = nil
        owner:SetAngerValue(0)
    end
end

local function wild_elit_boss_on_enter_fight(owner, monster_id)
    if owner:GetMonsterSetting(monster_id).Type == const.MONSTER_TYPE.WILD_ELITE_BOSS then
        flog("syzDebug", "elite boss enter fight")
        local wild_elite_boss = wild_elite_boss_class()
        wild_elite_boss.puppet = owner
        owner.wild_elite_boss = wild_elite_boss
        wild_elite_boss:on_born(monster_id)

        local function anger_timer_callback()
            local pos = owner:GetPosition()
            local anger_value_changed = false
            if wild_elite_boss:is_finish_condition_time() then
                anger_value_changed = true
            end
            if wild_elite_boss:is_finish_condition_position(pos) then
                anger_value_changed = true
            end
            if anger_value_changed then
                owner:SetAngerValue(wild_elite_boss:get_anger_value())
            end
        end

        owner.anger_timer = timer.create_timer(anger_timer_callback, 1000, const.INFINITY_CALL)
        owner:SetAngerValue(wild_elite_boss:get_anger_value())
    end
end

local function dungeon_boss_on_born(owner)
    local scene = scene_manager.find_scene(owner:GetSceneID())
    if scene ~= nil then
        --组队副本根据玩家等级设置怪物等级
        if scene:get_scene_type() == const.SCENE_TYPE.TEAM_DUNGEON or scene:get_scene_type() == const.SCENE_TYPE.TASK_DUNGEON then
            local monster_level = scene:get_scene_monster_level()
            if monster_level ~= nil then
                owner:SetLevel(monster_level)
            end
        end
    end

    --Boss出场
    local bossShowTime = false
    if scene ~= nil then
        if scene:get_scene_type() == const.SCENE_TYPE.TEAM_DUNGEON or scene:get_scene_type() == const.SCENE_TYPE.TASK_DUNGEON or scene:get_scene_type() == const.SCENE_TYPE.DUNGEON then
            if owner.data.Para1 ~= nil and owner.data.Para1 ~= "" then
                local dungeon_config = common_fight_base_config.get_boss_animation_config(tonumber(owner.data.Para1))
                if dungeon_config ~= nil then
                    scene:suspend_dungeon()
                    bossShowTime = true
                    owner:GetTimer().Delay(dungeon_config.Time/1000,
                        function()
                            scene:recover_dungeon()
                        end)
                end
            end
            if scene:get_susppend() then
                owner.canAttack = false
            end
        end
    end
    if not bossShowTime then
        -- 出生时不能被攻击
        owner.canBeattack = false
        owner.canBeselect = false
        owner.canAttack = false
        owner.eventManager.Fire('OnCurrentAttributeChanged')
        owner:GetTimer().Delay(1,
            function()
                owner.canBeattack = true
                owner.canBeselect = true
                if scene == nil or not scene:get_susppend() then
                    owner.canAttack = true
                end
                owner.eventManager.Fire('OnCurrentAttributeChanged')
            end)
    end
end

local function monster_transport_on_die(owner)
    if owner.data.sceneType == const.ENTITY_TYPE_MONSTER_TRANSPORT_GATE then
        local msg = string.format(fix_string.monster_transport_broke, owner.name)
        owner:BroadcastToAoi(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "SystemDirectMessage", msg = msg})
    end
end

local Delegate = require "Logic/Entity/Delegate/Delegate"
local MonsterDelegate = ExtendClass(Delegate)

function MonsterDelegate:__ctor()

end

function MonsterDelegate:OnTakeDamage(damage, attacker, skill_id, event_type)
    Delegate.OnTakeDamage(self, damage, attacker, skill_id, event_type)

    if attacker == nil then
        return 
    end

    -- 精英boss
    local attacker_entity, pet_entity = get_entity_of_owner(self, attacker.uid)
    local owner = self.owner
    wild_elit_boss_on_tabe_damage(owner, attacker_entity, pet_entity, damage)
    if attacker_entity and attacker_entity.on_attack_monster ~= nil then
        attacker_entity:on_attack_monster(owner)
    end
end

function MonsterDelegate:OnCauseDamage(damage, victim, skill_id, event_type)
    local target_entity = get_entity_of_owner(self, victim.uid)
    local owner = self.owner
    data_statistics_on_cause_damage(owner, target_entity, damage)
end

function MonsterDelegate:OnDied(killer)
    Delegate.OnDied(self, killer)

    if self.owner.anger_timer ~= nil then
        timer.destroy_timer(self.owner.anger_timer)
        self.owner.anger_timer = nil
    end

    if killer == nil then
        return
    end

    local killer_entity = get_entity_of_owner(self, killer.uid)
    local owner = self.owner
    if killer_entity~=nil and killer_entity.on_kill_monster ~= nil then
        local monster_level = owner.level
        local monster_data = {}
        monster_data.monster_scene_id = owner.data.ElementID
        monster_data.monster_pos = owner:GetPosition()
        monster_data.monster_level = monster_level
        monster_data.monster_type = owner.data.Type
        monster_data.monster_id = owner.data.MonsterID
        wild_elit_boss_on_died(owner, killer_entity, monster_data)
        killer_entity:on_kill_monster(monster_data)
    end

    -- 运输车
    local country = killer.data.Camp
    local name = get_config_name(owner.data)
    local hatred_list = owner:GetHatredListUids()
    if killer_entity ~= nil then
        country_monster.on_transport_fleet_be_killed(self.owner, name, killer.uid, killer_entity.actor_name, hatred_list, true, killer_entity.level)
    elseif country == 1 or country == 2 then
        local attacker_name = get_config_name(killer.data)
        country_monster.on_transport_fleet_be_killed(self.owner, name, killer.uid, attacker_name, hatred_list, false, killer.data.level)
    end

    -- 传送门
    monster_transport_on_die(owner)
end

function MonsterDelegate:OnBorn()
    local owner = self.owner
    local monster_id = owner.data.MonsterID
    wild_elit_boss_on_born(owner, monster_id)
    dungeon_boss_on_born(owner)
    local name = get_config_name(owner.data)
    country_monster.on_transport_fleet_born(owner, name)
end

-- 当仇恨列表发生变化
function MonsterDelegate:OnHatredChanged()
    local owner = self.owner
    local monster_id = owner.data.MonsterID
    local hatred_list = owner:GetHatredListUids()

    wild_elit_boss_on_hatred_changed(owner, monster_id, hatred_list)
end

function MonsterDelegate:OnFightStateChanged()
    local owner = self.owner
    local monster_id = owner.data.MonsterID

    if owner.fightState == FightState.Normal then
        wild_elit_boss_on_off_fight(owner)
        --country_monster.on_transport_fleet_out_of_danger(owner)
    elseif owner.fightState == FightState.Fight then
        wild_elit_boss_on_enter_fight(owner, monster_id)
        country_monster.on_transport_fleet_be_attack(owner)
    else
        flog("warn", "self.OnFightStateChanged wrong fight_state "..tostring(self.fightState))
    end
end

return MonsterDelegate
