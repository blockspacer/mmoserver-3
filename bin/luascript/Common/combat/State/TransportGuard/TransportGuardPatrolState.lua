---------------------------------------------------
-- auth： zhangzeng
-- date： 2017/5/31
-- desc： 跟随
---------------------------------------------------
local Vector3 = Vector3
local State = require "Common/combat/State/State"
local TransportGuardPatrolState = ExtendClass(State)

function TransportGuardPatrolState:__ctor(scene, name, stateType)
    self.lastPos = nil
end

function TransportGuardPatrolState:Moveto(owner, dest)
    if self.lastPos and Vector3.InDistance(dest, self.lastPos, 0.1) then
        return
    end
	
    owner:Moveto(dest)
    self.lastPos = dest
end
--[[
function TransportGuardPatrolState:FindEnemy(owner)
	local selectNPC = function(puppet)
		if puppet.entityType == EntityType.NPC and 
			Vector3.InDistance(owner:GetPosition(), puppet:GetPosition(), owner.AttackRadius) and 
			Vector3.InDistance(owner:GetBornPosition(), puppet:GetPosition(), owner.LeaveRadius) and not puppet:IsDied() then
			return true
		end
		return false
	end

	local enemy
	if owner.data.AttackType == 1 then
		enemy = owner:AOIQueryPuppet(selectNPC) --优先选择npc
		if enemy then
			return enemy
		end
	end
	enemy = owner:GetCurrentHatredEntity() -- 选择仇恨值高的
	if enemy then
		return enemy
	end
	return nil
end
]]

function TransportGuardPatrolState:FindEnemy(owner)
	return owner:AOIQueryPuppet(function(puppet)
		if owner:IsEnemy(puppet) and Vector3.InDistance(owner:GetPosition(), puppet:GetPosition(), owner.LeaveRadius) then
			return true
		end
		--if (puppet.entityType == EntityType.Hero or puppet.entityType == EntityType.Hero) and
			--not puppet:IsDied() and not puppet:IsDestroy() and 	owner:IsEnemy(puppet) and			
			--Vector3.InDistance(owner:GetPosition(), puppet:GetPosition(), owner.LeaveRadius) then
			--return true
		--end
		return false
	end)
end

function TransportGuardPatrolState:Excute(owner)
    if owner:IsDied() or owner:IsDestroy() or (owner.owner and (owner.owner:IsDied() or owner.owner:IsDestroy())) then
        return
    end
	
	local enemy = self:FindEnemy(owner)
	if enemy and owner:IsEnemy(enemy) and (enemy.entityType == EntityType.Dummy or enemy.entityType == EntityType.Hero or enemy.entityType == EntityType.Pet ) then
		--_info('owner.stateManager:GotoState(StateType.eAttack, enemy) ')
		owner.stateManager:GotoState(StateType.eAttack, enemy)  
		return
	end
	
    local dest = owner:CalculatePosition()
    self:Moveto(owner, dest)
end

return TransportGuardPatrolState
