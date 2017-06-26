---------------------------------------------------
-- auth： zhangzeng
-- date： 2017/5/26
-- desc： TransportGuard,逻辑层
---------------------------------------------------
local TransportGuardPatrolState = require "Common/combat/State/TransportGuard/TransportGuardPatrolState"
local TransportGuardAttackState =  require "Common/combat/State/TransportGuard/TransportGuardAttackState"
local Monster = require "Common/combat/Entity/Monster"
local TransportGuard = ExtendClass(Monster)
local TransportFleetManager = require "Common/combat/Entity/TransportFleetManager"

function TransportGuard:__ctor(scene, data)
	self.entityType = EntityType.TransportGuard
	self.TransporterID = data.TransporterID
end

function TransportGuard:SetOwner(owner)
	self.owner = owner
end

function TransportGuard:SetFace(face)
	self.face = face
end

function TransportGuard:CalculatePosition()	
	if self.owner == nil then
		local transportFleet = TransportFleetManager:GetTransportFleet(self.TransporterID)
		if transportFleet then
			self.owner = transportFleet.transportObject
		end
	end

	if self.owner == nil then
		return
	end

	local ownerPos = self.owner:GetPosition()
    local dirFlag = -1
    if self.face == 1 then    --dir left    
        dirFlag = -1
    else  --dir right   
        dirFlag = 1
    end        
    local nVect3 = Vector3.New(dirFlag * (0.666667) * ownerPos.z, 0, 0)
    local lVector3 = nVect3 + Vector3.New(0, 0, ownerPos.z)
    local rVector3 = Vector3.New(dirFlag, 0, 0) + Vector3.New(0, 0, 1.5)
    local distanceVect3 = lVector3 - rVector3

    local toPos = distanceVect3 + Vector3.New(ownerPos.x + (0 - dirFlag) * (0.666667) * ownerPos.z, 0, 0)
    toPos = self.owner:GetRotation() * (toPos - ownerPos)
    toPos = toPos + ownerPos 
    toPos.y = ownerPos.y --之前计算不考虑y坐标，现在把y修正为英雄的y值
    return toPos
end

function TransportGuard:Born()
	Monster.Born(self)
	self.stateManager:RemoveState(StateType.eAttack)
	self.stateManager:AddState(StateType.eAttack, TransportGuardAttackState(scene, 'attack', StateType.eAttack))
	self.stateManager:RemoveState(StateType.ePatrol)
	self.stateManager:AddState(StateType.ePatrol, TransportGuardPatrolState(scene, 'patrol', StateType.ePatrol))
	self.stateManager:GotoState(StateType.ePatrol)
end

return TransportGuard