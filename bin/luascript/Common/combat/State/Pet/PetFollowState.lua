---------------------------------------------------
-- auth： panyinglong
-- date： 2016/12/6
-- desc： 跟随
---------------------------------------------------
local Vector3 = Vector3

local State = require "Common/combat/State/State"
local PetFollowState = ExtendClass(State)
local forceDistance = GetConfig('common_fight_base').Parameter[63].Value
local followDistance = GetConfig('common_fight_base').Parameter[25].Value
local adjustPara = GetConfig('common_fight_base').Parameter[61].Value

function PetFollowState:__ctor(scene, name, stateType)
    self.lastPos = nil
end

function PetFollowState:Blinkto(owner, dest)
    owner:StopMove()
    owner:StopApproachTarget()
    owner:SetPosition(dest)
    owner:LookAt(dest)
    self.lastPos = dest
    -- self.isSetRotation = false
end

function PetFollowState:Moveto(owner, dest)
    if self.lastPos and Vector3.InDistance(dest, self.lastPos, 0.1) then
        -- if not self.isSetRotation then
        --     owner.behavior:SetRotation(owner.owner:GetRotation())
        --     self.isSetRotation = true
        -- end
        return
    end
    owner:Moveto(dest)
    -- self.isSetRotation = false
    self.lastPos = dest
end

function PetFollowState:IsOnAttackDistance(owner, target)
    local attackDistance = owner.skillManager:GetSkillDistance(0)
    return (Vector3.InDistance(owner.owner:GetPosition(), target:GetPosition(), (followDistance + attackDistance)))
end

function PetFollowState:GetPetTarget(owner)	--获取宠物攻击目标
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
	-- 不能是自己和 主人、兄弟
   -- if target and (not (target.entityType == EntityType.Dummy)) and
		--(not (target.entityType == EntityType.Monster)) then
       -- target = nil
    --end
	
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

function PetFollowState:Excute(owner)
    if owner:IsDied() or owner:IsDestroy() or owner.owner:IsDied() or owner.owner:IsDestroy() then
        return
    end
	
	local toHeroDis = Vector3.Distance2D(owner:GetPosition(), owner.owner:GetPosition())
    if toHeroDis > forceDistance then       --大于强制距离
		if GRunOnClient then
			if owner.owner.lowFlyManager.IsShowLocus() then -- 飞行的时候不跟踪
				return
			end
		end
		
		local blinkDest = owner:CalculatePosition(owner.owner:GetPosition())
		self:Blinkto(owner, blinkDest)
		return
	elseif toHeroDis > followDistance then		--离英雄的距离大于跟随距离
		if GRunOnClient then
			if owner.owner.lowFlyManager.IsShowLocus() then -- 飞行的时候不跟踪
				return
			end
		end
	else
		owner.target = self:GetPetTarget(owner)
		if owner.target and not owner.target:IsDied() and not owner.target:IsDestroy() then  	--战斗状态下		--战斗状态下
			owner.stateManager:GotoState(StateType.eAttack, owner.target)
			return
		else																						--非战斗状态下
			if adjustPara > Vector3.Distance2D(owner:GetPosition(), owner.owner:GetPosition()) then --非战斗状态下，宠物跟英雄距离小于adjustPara，宠物不跟随
				return
			end
		end
		if GRunOnClient then
			if owner.owner.lowFlyManager.IsShowLocus() then -- 飞行的时候不跟踪
				return
			end
		end
	end
	
   -- if toHeroDis > maxDistance then
        --Blinkto(owner, dest)
        --return
    --end
    local dest = owner:CalculatePosition()
    self:Moveto(owner, dest)
end

return PetFollowState
