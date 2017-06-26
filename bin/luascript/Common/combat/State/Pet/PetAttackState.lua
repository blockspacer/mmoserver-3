---------------------------------------------------
-- auth： panyinglong
-- date： 2016/12/6
-- desc： 攻击
---------------------------------------------------
local Vector3 = Vector3

local AttackState = require "Common/combat/State/AttackState"


local PetAttackState = ExtendClass(AttackState)

local followDistance = GetConfig('common_fight_base').Parameter[25].Value
local forceDistance = GetConfig('common_fight_base').Parameter[63].Value

function PetAttackState:__ctor(scene, name, stateType)
    
end

function PetAttackState:IsOnAttackDistance(owner, target)
    local attackDistance = owner.skillManager:GetSkillDistance(0)
    return (Vector3.InDistance(owner.owner:GetPosition(), target:GetPosition(), (followDistance + attackDistance)))
end

function PetAttackState:GetPetTarget(owner)	--获取宠物攻击目标
	local target = owner:GetTarget()
	local petOwner = owner.owner
	--如果拥有者有目标，则把宠物的目标设为拥有者的目标
	if petOwner and petOwner:GetTarget() then
		target = petOwner:GetTarget()
	end
	
	if target and not self:IsOnAttackDistance(owner, target) then
		target = nil
	end
	
	if target and owner:IsAlly(target) then
		target = nil
	end
	
	if not target then  --没有目标
		-- 设置攻击玩家的目标
		if petOwner and petOwner:GetAttacker() then
			target = petOwner:GetAttacker() 
		-- 设置攻击自己的目标
		elseif owner:GetAttacker() then 
			target = owner:GetAttacker()
		end
		
		if target and not self:IsOnAttackDistance(owner, target) then
			target = nil
		end
	
		if target and owner:IsAlly(target) then
			target = nil
		end
	end
	return target
end

function PetAttackState:Excute( owner, enemy )
    if owner:IsDied() or owner:IsDestroy() then
        return
    end
	
	local toHeroDis = Vector3.Distance2D(owner:GetPosition(), owner.owner:GetPosition())
	if toHeroDis > forceDistance then  --超过强制瞬移距离
	    owner.target = nil
        owner.stateManager:GotoState(StateType.eFollow)
		return
	elseif toHeroDis > followDistance then		--离英雄的距离超过跟随距离，强制跟随
        owner.target = nil
        owner.stateManager:GotoState(StateType.eFollow)  
        return
    end
	
	owner.target = self:GetPetTarget(owner)
    if not owner.target or owner.target:IsDied() or owner.target:IsDestroy() then
        self:StopAttack(owner)
        owner.stateManager:GotoState(StateType.eFollow)
        return
    end
	
    if owner.owner:IsDied() then
        self:StopAttack(owner)
        owner.stateManager:GotoState(StateType.eFollow) 
        return
    end

	local slot = SlotIndex.Slot_Attack
	local is_ok, code = owner.skillManager:IsSkillAvailable(slot)
    if not is_ok then   --当前技能不可用
        return
    end

    if owner.skillManager:IsInCastRange(slot, owner.target) then
        owner:StopMove()
        owner:CastSkill(slot, owner.target)
    else
        if not owner:IsOnApproachTarget(owner.target) then
            owner:StopApproachTarget()
            owner:ApproachAndCastSkill(slot, owner.target)
        end
    end
end

return PetAttackState

