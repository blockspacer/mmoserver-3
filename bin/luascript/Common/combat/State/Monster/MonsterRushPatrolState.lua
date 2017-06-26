---------------------------------------------------
-- auth： panyinglong
-- date： 2016/9/11
-- desc： 对冲状态
---------------------------------------------------
local Vector3 = Vector3

local MonsterPatrolState = require "Common/combat/State/Monster/MonsterPatrolState"
local MonsterRushPatrolState = ExtendClass(MonsterPatrolState)

function MonsterRushPatrolState:__ctor(scene, name, stateType)
	
end

function MonsterRushPatrolState:FindEnemy(owner)
	local selectNPC = function(puppet)
		if puppet.entityType == EntityType.NPC and 
			Vector3.InDistance(owner:GetPosition(), puppet:GetPosition(), owner.AttackRadius) and 
			not puppet:IsDied() then
			return true
		end
		return false
	end

	local enemy = owner:AOIQueryPuppet(selectNPC) --优先选择npc
	if enemy then
		return enemy
	end
	enemy = owner:GetCurrentHatredEntity() -- 选择仇恨值高的
	if enemy then
		return enemy
	end
	return nil
end

return MonsterRushPatrolState
