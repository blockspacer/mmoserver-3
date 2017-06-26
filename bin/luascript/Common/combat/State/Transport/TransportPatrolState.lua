---------------------------------------------------
-- auth： panyinglong
-- date： 2016/10/31
-- desc： 巡逻状态
---------------------------------------------------
local Vector3 = Vector3

local PatrolState = require "Common/combat/State/PatrolState"
local TransportDefendPatrolState = ExtendClass(PatrolState)
-- 保卫任务中npc巡逻
function TransportDefendPatrolState:__ctor(scene, name, stateType)

end

function TransportDefendPatrolState:Excute(owner)
	if owner:IsDied() or owner:IsDestroy() then
		return
	end
	PatrolState.Excute(self, owner)
end


local TransportEscortPatrolState = ExtendClass(PatrolState)

function TransportEscortPatrolState:__ctor(scene, name, stateType)
	self.duration = 0
	self.timer = nil
end

function TransportEscortPatrolState:FindEnemy(owner)
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

	------------------

function TransportEscortPatrolState:clearWait()
	self.duration = 0   
end

function TransportEscortPatrolState:startTimer()		
	if not self.timer then
		self.timer = self:GetTimer().Repeat(0.2, function() 
			self.duration = self.duration + 0.2
		end)
	end
	self:GetTimer().Resume(self.timer)
end

function TransportEscortPatrolState:stopTimer()
	if self.timer then
		self:GetTimer().Stop(self.timer)
	end
end
	------------------

function TransportEscortPatrolState:Excute(owner)
	if owner:IsDied() or owner:IsDestroy() then
		return
	end
	
	local enemy = self:FindEnemy(owner)
	if enemy and owner:IsEnemy(enemy) and (enemy.entityType == EntityType.Dummy or enemy.entityType == EntityType.Hero or enemy.entityType == EntityType.Pet ) then
		--if owner.scene.scene_id == 3 then
			--self:clearWait()
			--self:stopTimer()

			--_info('NPCEscortPatrolState1')
			--_info('owner.scene = '..owner.scene.scene_id)
			--_info('enemy.uid = '..enemy.uid)
			--_info('enemy.entityType = '..enemy.entityType)
			--_info('owner.uid = ' ..owner.uid)
			owner:SetSpeed(0)
		--end
	else
		--if owner.scene.scene_id == 3 then
			PatrolState.Excute(self, owner)
			owner:SetSpeed(300)
			--_info('NPCEscortPatrolState2')
			--_info('owner.scene = '..owner.scene.scene_id)
			--_info('owner.uid = ' ..owner.uid)
		--end
	end
end

function TransportEscortPatrolState:OnActive(owner, ...)
	PatrolState.OnActive(self)
	--_info('TransportEscortPatrolStateOnActive')
	self:clearWait()
end

function TransportEscortPatrolState:OnDeactive( owner, ... )
    PatrolState.OnActive(self)
	self:clearWait() 
	self:stopTimer()           
end

return {
	CreateDefendPatrolState = TransportDefendPatrolState, 
	CreateEscortPatrolState = TransportEscortPatrolState
}
