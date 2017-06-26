---------------------------------------------------
-- auth： yanwei
-- date： 2017/2/9
-- desc： 英雄挂机AI
---------------------------------------------------

local AttackState = require "Common/combat/State/AttackState"
local HookAttackState = ExtendClass(AttackState)

function HookAttackState:__ctor(scene, name, stateType)
    self.timeIinterval = 1
end

local function IsSkillAvailable(owner, skill_id)
    local config = GetConfig("growing_skill")
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

function HookAttackState:getSkill(owner, enemy)
     if owner.skillManager.skills[self.curSlot] == nil then
        --print("CreateAttackState no skill here!!!!!!!!!!!!!!!!!!!!!!!")
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

function HookAttackState:Excute(owner, ...)
    if owner:IsDied() or owner:IsDestroy() then
        return
    end
	local enemy = SceneManager.GetEntityManager().hero.target
    if not enemy or enemy:IsDied() or enemy:IsDestroy() then
          enemy = TargetManager.GetHookMonster()
		  while not enemy and self.timeIinterval < 10 do 
		    enemy = nil
		    self.timeIinterval = self.timeIinterval +1
		    enemy = TargetManager.GetHookMonster()
		  end
    end
	self.timeIinterval = 1
    if not enemy then 
	   self:StopAttack(owner)
	   owner.stateManager:GotoState(StateType.eHookPatrol)
	   return
	 end
    local hasSkill = self:getSkill(owner, enemy)  
    if not hasSkill then -- 所有技能都不可用 
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
        if not owner:IsOnApproachTarget(enemy) then
            owner:StopApproachTarget()
            local skillDis = owner.skillManager.skills[self.curSlot].cast_distance
            owner:StartApproachTarget(enemy, skillDis)
        end
    end
end

return HookAttackState
