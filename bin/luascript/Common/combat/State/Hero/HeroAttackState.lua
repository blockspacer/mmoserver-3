---------------------------------------------------
-- auth： panyinglong
-- date： 2017/3/17
-- desc： 杀怪任务
---------------------------------------------------

local AttackState = require "Common/combat/State/AttackState"
local HeroAttackState = ExtendClass(AttackState)
local config = GetConfig("growing_skill")

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

function HeroAttackState:__ctor(scene, name, stateType)

end

function HeroAttackState:getSkill(owner, enemy)
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

-- 继承类必须要重写此函数
function HeroAttackState:FindEnemy(owner, ...)
    return nil
end

function HeroAttackState:Excute(owner, enemy)
    if owner:IsDied() or owner:IsDestroy() then
        return
    end
    if not enemy or enemy:IsDied() or enemy:IsDestroy() then
        self:StopAttack(owner)
        return
    end
    AttackState.Excute(self, owner, enemy)
end

return HeroAttackState
