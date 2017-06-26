---------------------------------------------------
-- auth： panyinglong
-- date： 2016/12/6
-- desc： 攻击
---------------------------------------------------

local AttackState = require "Common/combat/State/AttackState"
local DummyAttackState = ExtendClass(AttackState)
local config = GetConfig("growing_skill")

function DummyAttackState:__ctor(scene, name, stateType)
    self.nextDefault = stateType
end


local function IsSkillAvailable(owner, skill_id)
    local skill_data = config.IntelligentRelease[tonumber(skill_id)]
    if skill_data == nil then
        return true
    elseif skill_data.Type == 1 then
        if skill_data.Parameter == 0 then
            return true
        else
            return owner.skillManager:FindBuff(tostring(skill_data.Parameter)) == nil
        end
    elseif skill_data.Type == 2 then
        return false
    elseif skill_data.Type == 3 then
        return owner.hp < owner.hp_max() * skill_data.Parameter / 100
    end
    return true
end

function DummyAttackState:getSkill(owner, enemy)
     if owner.skillManager.skills[self.curSlot] == nil then
        return false
    end

    for slot_id = SlotIndex.Slot_Skill1, SlotIndex.Slot_Skill4 do
        local is_ok, code = owner.skillManager:IsSkillAvailable(slot_id)
        if is_ok and IsSkillAvailable(owner, owner.skillManager.skills[slot_id].skill_id) then
            self.curSlot = slot_id
            return true
        end
    end

    local is_ok, code = owner.skillManager:IsSkillAvailable(SlotIndex.Slot_Attack)
    if is_ok and IsSkillAvailable(owner, owner.skillManager.skills[SlotIndex.Slot_Attack].skill_id) then
        self.curSlot = SlotIndex.Slot_Attack
        return true
    end
    return false
end

function DummyAttackState:Excute(owner, ...)  
    if owner:IsDied() or owner:IsDestroy() then
        return
    end

    local FindEnemy = function(owner, enemy)
        return owner:AOIQueryPuppet(function(puppet)
            if puppet.entityType == EntityType.Dummy then
                if not puppet:IsDied() and not puppet:IsDestroy() and puppet.uid ~= owner.uid then
                    return true
                end
            end
            return false
        end)
    end
    local FindMonster = function(owner, enemy)
        return owner:AOIQueryPuppet(function(puppet)
            if puppet.entityType == EntityType.Monster then
                if not puppet:IsDied() and not puppet:IsDestroy() and puppet.uid ~= owner.uid then
                    return true
                end
            end
            return false
        end)
    end

    local enemy = FindEnemy(owner, enemy)
    if not enemy then
        enemy = FindMonster(owner, enemy)
    end

    AttackState.Excute(self, owner, enemy)
end

return DummyAttackState
