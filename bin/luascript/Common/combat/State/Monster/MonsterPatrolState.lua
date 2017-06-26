---------------------------------------------------
-- auth： panyinglong
-- date： 2016/9/11
-- desc： 巡逻状态
---------------------------------------------------
local Vector3 = Vector3

local PatrolState = require "Common/combat/State/PatrolState"
local MonsterPatrolState = ExtendClass(PatrolState)

function MonsterPatrolState:__ctor(scene, name, stateType)
	self.owner = nil
end

function MonsterPatrolState:FindEnemy(owner)
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

function MonsterPatrolState:Excute(owner, ...)
	if owner:IsDied() or owner:IsDestroy() then
		return
	end
	local enemy = self:FindEnemy(owner)
	if enemy then
		owner.stateManager:GotoState(StateType.eAttack, enemy)  
		return
	end
	local args = {...}
	PatrolState.Excute(self, owner, unpack(args))
end

return MonsterPatrolState
