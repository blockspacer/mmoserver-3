---------------------------------------------------
-- auth： panyinglong
-- date： 2016/10/31
-- desc： 巡逻状态
---------------------------------------------------
local Vector3 = Vector3
local flog = require "basic/log"

local PatrolState = require "Common/combat/State/PatrolState"
local NPCDefendPatrolState = ExtendClass(PatrolState)
-- 保卫任务中npc巡逻
function NPCDefendPatrolState:__ctor(scene, name, stateType)

end

function NPCDefendPatrolState:Excute(owner)
	if owner:IsDied() or owner:IsDestroy() then
		return
	end
	PatrolState.Excute(self, owner)
end
---------------------------------------------

local NPCEscortPatrolState = ExtendClass(PatrolState)

function NPCEscortPatrolState:__ctor(scene, name, stateType)
	self.duration = 0
	self.timer = nil
	self.bosses = nil
end

function NPCEscortPatrolState:FindEnemy(owner)
	local center = owner.taskData.positions[owner.taskData.current]
	if not center then
		return
	end
	return owner:AOIQueryPuppet(function(puppet)
		if puppet.entityType == EntityType.Monster and not puppet:IsDied() and not puppet:IsDestroy() and 				
			Vector3.InDistance(center, puppet:GetPosition(), owner.taskData.radius) then
			return true
		end
		return false
	end)
end

function NPCEscortPatrolState:HasNewBoss(owner)
	local bossDic = owner:AOIQueryPuppets(function(puppet)
		if puppet.entityType == EntityType.Monster and not puppet:IsDied() and not puppet:IsDestroy() and puppet:GetMonsterType() >= 3 then
			return true
		end
		return false
	end)
	local existNew = false
	for k, v in pairs(bossDic) do
		if not self.bosses[k] then
			self.bosses[k] = true
			existNew = true
		end
	end
	return existNew
end

function NPCEscortPatrolState:clearWait()
	self.duration = 0   
end

function NPCEscortPatrolState:startTimer()		
	if not self.timer then
		self.timer = self:GetTimer().Repeat(0.2, function() 
			self.duration = self.duration + 0.2
		end)
	end
	self:GetTimer().Resume(self.timer)
end

function NPCEscortPatrolState:stopTimer()
	if self.timer then
		self:GetTimer().Stop(self.timer)
	end
end

function NPCEscortPatrolState:Excute(owner)
	if owner:IsDied() or owner:IsDestroy() then
		return
	end
	local enemy = self:FindEnemy(owner)
	if enemy then
		if self:HasNewBoss(owner) then
			owner:BroadcastUnitMsg('NewBoss', {}) 
		end

		self:clearWait()
		self:stopTimer()
		owner:SetBornPosition(owner:GetPosition())
		enemy = owner:GetCurrentHatredEntity() -- 选择仇恨值高的
		if enemy then
			owner:BroadcastUnitMsg('Fight', {}) 
			owner.stateManager:GotoState(StateType.eAttack, enemy)
		else  
			PatrolState.Excute(self, owner)
		end
	else
		self:startTimer()
		if self.duration > owner.taskData.waitTime then
			self:clearWait()
			owner:BroadcastUnitMsg('Goto', {}) 
			owner.stateManager:GotoState(StateType.eGoto) 
		end
	end
end

function NPCEscortPatrolState:OnActive(owner, ...)
	PatrolState.OnActive(self)
	self:clearWait()
	self.bosses = {}
end

function NPCEscortPatrolState:OnDeactive( owner, ... )
    PatrolState.OnActive(self)
	self:clearWait() 
	self:stopTimer()  
	self.bosses = nil         
end

return {
	CreateDefendPatrolState = NPCDefendPatrolState, 
	CreateEscortPatrolState = NPCEscortPatrolState
}
