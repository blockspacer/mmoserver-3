---------------------------------------------------
-- auth： zhangzeng
-- date： 2017/5/15
-- desc： Transport,逻辑层
---------------------------------------------------
local TransportPatrolState = require "Common/combat/State/Transport/TransportPatrolState"
local Monster = require "Common/combat/Entity/Monster"
local CreateTransportIdleState = require "Common/combat/State/Transport/TransportIdleState"
local Transport = ExtendClass(Monster)
local TransportFleetManager = require "Common/combat/Entity/TransportFleetManager"

function Transport:__ctor(scene, data)
	self.entityType = EntityType.Transport
	self.TransporterID = data.TransporterID
end

function Transport:Born()
	Monster.Born(self)
	self.stateManager:RemoveState(StateType.ePatrol)
	self.stateManager:AddState(StateType.eIdle, CreateTransportIdleState(scene, 'idle', StateType.eIdle))
	self.stateManager:AddState(StateType.ePatrol, TransportPatrolState.CreateEscortPatrolState(scene, 'patrol', StateType.ePatrol))
	self.stateManager:GotoState(StateType.ePatrol)
end

function Transport:SetParent(parent)
	self.parent = parent
end

function Transport:OnDied(killer)
	Monster.OnDied(self, killer)
	
	if self.parent then
		self.parent:OnTransporterIsKilled()  --通知管理者，我已被杀
	end
end

return Transport