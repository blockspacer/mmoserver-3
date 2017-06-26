---------------------------------------------------
-- auth： panyinglong
-- date： 2016/9/11
-- desc： 攻击状态
---------------------------------------------------
local Vector3 = Vector3

local State = require "Common/combat/State/State"
local AttackState = ExtendClass(State)

function AttackState:__ctor(scene, name, stateType)
    self.nextDefault = nextDefault or StateType.ePatrol

    local movePos = Vector3.zero
    self.curSlot = 0
end

function AttackState:getSkill(owner, enemy)
    --[[if owner.skillManager.skills[self.curSlot] == nil then
        --print("CreateAttackState no skill here!!!!!!!!!!!!!!!!!!!!!!!")
        return false
    end]]

    --[[local is_ok, code = owner.skillManager:IsSkillAvailable(self.curSlot)
    if is_ok then
        return true
    end

    for k, v in pairs(owner.skillManager.skills) do
        local is_ok, code = owner.skillManager:IsSkillAvailable(k)
        if is_ok and owner.skillManager:IsFillCondition(k) then
            self.curSlot = k
            return true
        end
    end]]

    for slot_id = SlotIndex.Slot_Skill1, SlotIndex.Slot_Skill4 do
        local is_ok, code = owner.skillManager:IsSkillAvailable(slot_id)
        if is_ok then
            self.curSlot = slot_id
            return true
        end
    end

    local is_ok, code = owner.skillManager:IsSkillAvailable(SlotIndex.Slot_Attack)
    if is_ok then
        self.curSlot = SlotIndex.Slot_Attack
        return true
    end
    return false
end

function AttackState:StopAttack(owner)
    owner:StopApproachTarget()
    owner:StopMove()      
end
local flog = require "basic/log"
function AttackState:Excute( owner, enemy )
    if owner:IsDied() or owner:IsDestroy() then
        return
    end
    if not enemy or enemy:IsDied() or enemy:IsDestroy() then
        self:StopAttack(owner)
        owner.stateManager:GotoState(self.nextDefault)  
        return
    end

    local hasSkill = self:getSkill(owner, enemy)  
    if not hasSkill then -- 所有技能都不可用 
        --print('not skill ok')        
        return
    end

    if owner.skillManager:IsOnCommonCD() then
        return
    end

    if owner.skillManager:IsInCastRange(self.curSlot, enemy) then
        owner:StopMove()
        owner:StopApproachTarget()
        owner:CastSkill(self.curSlot, enemy)
    else
        if owner:CanMove() then
            if not owner:IsOnApproachTarget(enemy) then
                owner:StopApproachTarget()
                local skillDis = owner.skillManager.skills[self.curSlot].cast_distance
                owner:StartApproachTarget(enemy, skillDis)
            end
        end
    end
end

return AttackState