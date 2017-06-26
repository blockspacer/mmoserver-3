---------------------------------------------------
-- auth： panyinglong
-- date： 2017/4/10
-- desc： 竞技场挂机AI
---------------------------------------------------

local AttackState = require "Common/combat/State/AttackState"
local ArenaHookState = ExtendClass(AttackState)
local hookCombat
if GRunOnClient then
    hookCombat = require "Logic/OnHookCombat"
end
local config = GetConfig("growing_skill")

function ArenaHookState:__ctor(scene, name, stateType)
	
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

function ArenaHookState:getSkill(owner, enemy)
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

function ArenaHookState:Excute(owner, ...)
	 local selectNearbyEnemy = function(puppet)
		if puppet.entityType == EntityType.Dummy and not puppet:IsDied() and hookCombat then
			puppet.ApproachDistance = Vector3.Distance2D(hookCombat.pos, puppet:GetPosition()) 
			if puppet.ApproachDistance < GlobalManager.HookRadius  then         
			  return true 
			end        
		end
		return false
    end
	
	local GetCloestDummy = function()
        local dummys = SceneManager.GetEntityManager().QueryPuppets(selectNearbyEnemy)
		local function DistanceSort(p1,p2)
           return dummys[p1].ApproachDistance < dummys[p2].ApproachDistance
        end
        local key_table = {} 
		for key,_ in pairs(dummys) do  
          table.insert(key_table,key)  
        end 
		table.sort(key_table,DistanceSort)

		return dummys[key_table[1]]
    end

    if owner:IsDied() or owner:IsDestroy() or not hookCombat then
        return
    end
	
	local enemy = TargetManager.GetCurrentTarget() 
	if not enemy or enemy:IsDied() or enemy:IsDestroy() or not TargetManager.CanAttack(enemy) then
		enemy = GetCloestDummy()
		if enemy then
		   TargetManager.SetTarget(enemy)
		elseif not Vector3.InDistance(hookCombat.pos, SceneManager.GetEntityManager().hero:GetPosition(), 0.4) then
		   owner:Moveto(hookCombat.pos)
		   return
		   --self.IsMoving = true
		 elseif Vector3.InDistance(hookCombat.pos, SceneManager.GetEntityManager().hero:GetPosition(), 0.4) then
		   return
		end
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

return ArenaHookState
