---------------------------------------------------
-- auth： yanwei
-- date： 2017/2/21
-- desc： 野外挂机AI
---------------------------------------------------

local AttackState = require "Common/combat/State/AttackState"
local WildHookState = ExtendClass(AttackState)
local hookCombat
if GRunOnClient then
    hookCombat = require "Logic/OnHookCombat"
end

function WildHookState:__ctor(scene, name, stateType)
	
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

function WildHookState:getSkill(owner, enemy)
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

function WildHookState:Excute(owner, ...)
	 local selectNearbyMonster = function(puppet)
		if (puppet.entityType == EntityType.Monster or puppet.entityType == EntityType.MonsterCamp) and 
            not puppet:IsDied() and puppet ~= currentTarget and hookCombat and SceneManager.GetEntityManager().hero:IsEnemy(puppet) then
			puppet.ApproachDistance = Vector3.Distance2D(hookCombat.pos, puppet:GetPosition()) 
			if puppet.ApproachDistance < GlobalManager.HookRadius  then         
			  return true 
			end        
		end
		return false
    end
	
	local GetCloestMonster = function()
        local monsters = SceneManager.GetEntityManager().QueryPuppets(selectNearbyMonster)
		local function DistanceSort(p1,p2)
           return monsters[p1].ApproachDistance < monsters[p2].ApproachDistance
        end
        local key_table = {} 
		for key,_ in pairs(monsters) do  
          table.insert(key_table,key)  
        end 
		table.sort(key_table,DistanceSort)

		return monsters[key_table[1]]
    end

    if owner:IsDied() or owner:IsDestroy() or not hookCombat then
        return
    end
	
	local enemy = TargetManager.GetCurrentTarget() 
	if not enemy or enemy:IsDied() or enemy:IsDestroy() or enemy.entityType ~= EntityType.Monster or not TargetManager.CanAttack(enemy) then
		enemy = GetCloestMonster()
		if enemy then
		   TargetManager.SetTarget(enemy)
		elseif not Vector3.InDistance(hookCombat.pos, SceneManager.GetEntityManager().hero:GetPosition(), 0.4) then
		   owner:Moveto(hookCombat.pos)
		   return
		   --self.IsMoving = true
		 elseif Vector3.InDistance(hookCombat.pos, SceneManager.GetEntityManager().hero:GetPosition(), 0.4)  then
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

return WildHookState
