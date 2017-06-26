---------------------------------------------------
-- auth： zhangzeng
-- date： 2017/5/15
-- desc： TransportFleet,逻辑层
---------------------------------------------------
local BaseObject = require "Common/combat/Entity/BaseObject"
local TransportFleet = ExtendClass(BaseObject)
local CreateEventManager = require "Common/combat/Entity/EventManager"

local flog
local IDManager 
if not GRunOnClient then
	IDManager =  require "idmanager"
	flog = require "basic/log"
end

function TransportFleet:__ctor(scene, data)
	self.eventManager = CreateEventManager(self)
	self.entityType = EntityType.TransportFleet
	self.uid = data.entity_id
	self.itemsDic = {}
	self.transportObject = nil --运输车,唯一的
	self.index = 0
	self.behavior = {}
	self.danger = false
	self.transportGuard = 0
	--self.stopMoveTimer = self:GetTimer().Repeat(0.1, function() self:StopTransportMove() end ,0)
end

function TransportFleet:StopTransportMove()
	self.danger = false
	for _, v in pairs(self.itemsDic) do
		local ret = v:IsHatredListEmpty()
		if not ret then
			self.danger = true
			break
		end
	end
	
	local enabled = self.transportObject.enabled
	if self.transportObject then
		if self.danger then
			if enabled == true then
				self.transportObject.enabled = false
				self.transportObject:StopMove()
			end
		else
			self.transportObject.enabled = true
		end
	end
end

function TransportFleet:AddItem(data)
	local para1 = tonumber(data.Para1)
	if para1 == 1 then		--运输车
		local transport = self:GetEntityManager().CreateScenePuppet(data, EntityType.Transport)
		self.itemsDic[transport.uid] = transport
		transport:SetParent(self)
		transport.TransporterID = data.TransporterID
		self.transportObject = transport
	elseif para1 == 2 then  --守卫npc
		local npc = self:GetEntityManager().CreateScenePuppet(data, EntityType.TransportGuard)
		npc.TransporterID = data.TransporterID
		npc:SetOwner(self.transportObject)
		self.itemsDic[npc.uid] = npc
		self.transportGuard = self.transportGuard + 1
		npc:SetFace(self.transportGuard)
	end
	self.index = self.index + 1
end

function TransportFleet:SetParent(parent)
	self.parent = parent
end

function TransportFleet:DestroyTransportGuard()  --运输车被杀死，所以不在战斗中的守卫npc自动死亡
	local num = 0
	local i = 0
	for _, v in pairs(self.itemsDic) do
		if tonumber(v.data.Para1) == 2 and v.fightState ~= FightState.Fight then
			self:GetEntityManager().DestroyPuppet(v.uid)
			i = i + 1
		end
		num = num + 1
	end
	
	if num == i then
		self:GetEntityManager().DestroyPuppet(self.uid)
	end
end

function TransportFleet:OnTransporterIsKilled()  --运输车被杀死
	self.updataTimer = self:GetTimer().Repeat(0.2, function() self:DestroyTransportGuard() end ,0)
end

function TransportFleet:GetDefendMonsterNum()
	local i = 0
	local num = 0
	for _, v in pairs(self.itemsDic) do
		if tonumber(v.data.Para1) == 2 then
			num = num + 1
		end
		i = i + 1
	end
	return num
end

function TransportFleet:RemoveItem(data)
	local uid = data.entity_id
	local transportObject = self.transportObject
	if self.itemsDic[uid] then
		self.itemsDic[uid] = nil
	end
end

function TransportFleet:Born() 	
	BaseObject.Born(self)
end

function TransportFleet:Destroy()
	self.eventManager.Fire('OnDestroy')
	for _, v in pairs(self.itemsDic) do
		self:GetEntityManager().DestroyPuppet(v.uid)
	end
	self.itemsDic = {}
	self.transportObject = nil
	self.parent = nil
	if self.updataTimer then
		self:GetTimer().Remove(self.updataTimer)
		self.updataTimer = nil
	end
	self.transportGuard = 0
	self.index = 0
end

function TransportFleet:OnDestroy()
	BaseObject.OnDestroy(self)
end

function TransportFleet:OnDanger(flag)
	self.danger = flag
end

return TransportFleet