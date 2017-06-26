---------------------------------------------------
-- auth： panyinglong
-- date： 2016/10/26
-- desc： Toy
---------------------------------------------------
local Vector3 = Vector3

local CreateEventManager = require "Common/combat/Entity/EventManager"

local BaseObject = require "Common/combat/Entity/BaseObject"
local Toy = ExtendClass(BaseObject)
-- 物体，移动不受navmesh约束
function Toy:__ctor(scene, data)
	self.eventManager = CreateEventManager(self)

	self.data = data
	-- self:GetBornPosition() = Vector3.New(data.PosX, data.PosY, data.PosZ)
	self.uid = data.entity_id
	self.behavior = nil

	self.approachTimer = nil
	self.create_proxy_flag = false
	self.data.property = {
		[14] = 200,
	}
end

function Toy:Born()
	if self.create_proxy_flag then
		if not GRunOnClient then
			self:CreateAOIProxy()
		end
	end
end
    
function Toy:GetBornPosition()
	return Vector3.New(self.data.posX, self.data.posY, self.data.posZ)
end

function Toy:GetPosition()
	return self.behavior:GetPosition()
end

function Toy:SetSpeed(speed)
	self.behavior:SetSpeed(speed)
end

function Toy:Moveto(pos)
	self.behavior:Moveto(pos)
end

function Toy:MoveToDirectly(pos)
	self.behavior:MoveToDirectly(pos)
end

function Toy:StopMove()
	self.behavior:StopMove()
end

-- function Toy:SetNavMesh(b)
-- 	self.behavior:SetNavMesh(b)
-- end

function Toy:AddEffect(resName, rootName, recyle, pos, angle, scale, detach, lossyScale)
	if rootName == '0' or rootName == '' then
		rootName = nil
	end
	if self.behavior then
		self.behavior:AddEffect(resName, rootName, recyle, pos, angle, scale, detach, lossyScale)
	end
end

function Toy:RemoveEffect(res)
	self.behavior:RemoveEffect(res)
end

function Toy:RemoveAllEffect()
	if self.behavior then
		self.behavior:RemoveAllEffect()
	end
end

function Toy:StartApproachTarget(target, distance, callback, ...)
	self.approachCallback = callback
	self.approachArgs = {...}
	self.approachDistance = distance
	local args = {...}
	self:StopApproachTarget()
	if target and not target:IsDied() and not target:IsDestroy() then
		self:MoveToDirectly(target:GetPosition())
	end
	self.approachTimer = self:GetTimer().Repeat(0.03, function()
		if not target or target:IsDied() or target:IsDestroy() then
			self:StopApproachTarget()
			return
		end
		if Vector3.InDistance(self:GetPosition(), target:GetPosition(), distance) then
			self:StopApproachTarget()
			if callback then
				callback(unpack(args))
			end
		else
			--print("move to" .. target:GetPosition().x ..",".. target:GetPosition().y ..",".. target:GetPosition().z)
			self:MoveToDirectly(target:GetPosition())
		end			
	end)
end

function Toy:StartApproachTarget2D(target, distance, callback, ...)
	self.approachCallback = callback
	self.approachArgs = {...}
	self.approachDistance = distance
	local destination = target:GetPosition()
	destination.y = self:GetBornPosition().y

	local args = {...}
	self:StopApproachTarget()
	if target and not target:IsDied() and not target:IsDestroy() then
		self:MoveToDirectly(destination)
	end

	self.approachTimer = self:GetTimer().Repeat(0.03, function()

		if not target or target:IsDied() or target:IsDestroy() then
		else
			destination = target:GetPosition()
			destination.y = self:GetBornPosition().y
		end

		if Vector3.InDistance(self:GetPosition(), destination, distance) then
			self:StopApproachTarget()
			if callback then
				callback(unpack(args))
			end
		else
			self:MoveToDirectly(destination)
		end			
	end)
end

function Toy:StartApproachPosition(target_pos, distance, callback, ...)
	self.approachCallback = callback
	self.approachArgs = {...}
	self.approachDistance = distance
	local args = {...}
	self:StopApproachTarget()
	if target_pos then
		self:MoveToDirectly(target_pos)
	end
	self.approachTimer = self:GetTimer().Repeat(0.03, function()
		local dis = Vector3.Distance2D(self:GetPosition(), target_pos)
		if dis < distance then
			self:StopApproachTarget()
			if callback then
				callback(unpack(args))
			end
		end			
	end)
end

function Toy:StartApproachTargetPartPosition(target, part_name, distance, callback, ...)
	self.approachCallback = callback
	self.approachArgs = {...}
	self.approachDistance = distance
	local args = {...}
	self:StopApproachTarget()
	if target and not target:IsDied() and not target:IsDestroy() then
		self:MoveToDirectly(target:GetPartPosition(part_name))
	end

	local destnation = target:GetPartPosition(part_name)

	self.approachTimer = self:GetTimer().Repeat(0.03, function()
		if not target or target:IsDied() or target:IsDestroy() then
		else
			destnation = target:GetPartPosition(part_name)
		end

		if Vector3.InDistance(self:GetPosition(), destnation, distance) then
			self:StopApproachTarget()
			if callback then
				callback(unpack(args))
			end
		else
			self:MoveToDirectly(destnation)
		end			
	end)
end

function Toy:StopApproachTarget()
	if self.approachTimer then
		self:GetTimer().Remove(self.approachTimer)
		self.approachTimer = nil
	end
end

function Toy:IsOnApproachTarget()
	return self.approachTimer ~= nil
end

local flog = require 'basic/log'
function Toy:Destroy()
	if not self.behavior then
		flog('info', '_?:' .. self.entityType)
		return
	end
	self:RemoveAllEffect()
	self:StopApproachTarget()
	self:StopMove()
	self.eventManager.Fire('OnDestroy')
end
	-- 注：请勿直接调用self.OnDestroy(), 想要销毁对象，请调用self:GetEntityManager().DestroyPuppet(self.uid)
function Toy:OnDestroy()
	BaseObject.OnDestroy(self)
	self.behavior:Destroy()
	self.behavior = nil
	self:Clear()
end

function Toy:Clear()
	-- self.eventManager = nil

	--self.data = nil
end
function Toy:OnBorn()
end

function Toy:IsEnemy(unit)
	return false
end

function Toy:IsAlly(unit)
	return false
end
function Toy:SetPosition(pos)
	self.behavior:SetPosition(pos)
end
function Toy:LookAt(pos)
	self.behavior:LookAt(pos)
end

return Toy
