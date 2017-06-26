---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/13
-- desc： 单位的事件delegate
---------------------------------------------------
local const = require "Common/constant"
local country_monster = require("boss/country_monster")
local get_entity_of_owner = require("helper/delegate_common").get_entity_of_owner
local get_config_name = require("basic/scheme").get_config_name

local MonsterDelegate = require "Logic/Entity/Delegate/MonsterDelegate"
local MonsterCampDelegate = ExtendClass(MonsterDelegate)

function MonsterCampDelegate:__ctor()
end

function MonsterCampDelegate:OnTakeDamage(damage, attacker, skill_id, event_type)
	MonsterDelegate.OnTakeDamage(self, damage, attacker, skill_id, event_type)

    local monster_scene_id = self.owner.data.ElementID
    local attacker_id = attacker.uid
    local attacker_entity = get_entity_of_owner(self, attacker.uid)
    local country = attacker.data.Camp
    if attacker_entity ~= nil then
        country_monster.on_country_monster_take_damage(monster_scene_id, attacker_entity.actor_id, damage, attacker_entity.actor_name, true, attacker_entity.level)
    elseif country == 1 or country == 2 then
        local attacker_name = get_config_name(attacker.data)
        country_monster.on_country_monster_take_damage(monster_scene_id, attacker_id, damage, attacker_name, false, attacker.data.level)
    end
end

function MonsterCampDelegate:OnCauseDamage(damage, victim, skill_id, event_type)

end

function MonsterCampDelegate:OnDied(killer)
	MonsterDelegate.OnDied(self, killer)
end

function MonsterCampDelegate:OnBorn()
	local monster_scene_id = self.owner.data.ElementID
	country_monster.on_country_monster_born(monster_scene_id, self.owner)
end

return MonsterCampDelegate
