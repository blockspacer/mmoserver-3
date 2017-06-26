---------------------------------------------------
-- auth： zhangzeng
-- date： 2016/9/12
-- desc： 加载屏障
---------------------------------------------------
local CreateBarrierBehavior = require "Logic/Entity/Behavior/BarrierBehavior"
local BaseObject = require "Common/combat/Entity/BaseObject"
local Barrier = ExtendClass(BaseObject)
local flog = require "basic/log"

local CreateEventManager = require "Common/combat/Entity/EventManager"

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end

function Barrier:__ctor(scene, data)
	self.eventManager = CreateEventManager(self)
	self.entityType = EntityType.Barrier
	self.data = data
	self.uid = data.entity_id
	
	if not GRunOnClient then
		self.create_proxy_flag = true
		self.data.property = {[14] = 0}
	end
end

function Barrier:Born()
	BaseObject.Born(self)
	if not GRunOnClient and self.create_proxy_flag then
		self:CreateAOIProxy()
	end
	self.behavior = CreateBarrierBehavior(self)
end

function Barrier:GetClientNeedInfo()
	local data = {}
	data.entity_id = self.data.entity_id
	data.posX = math.floor((self.data.posX or 0) * 100)
	data.posY = math.floor((self.data.posY or 0) * 100)
	data.posZ = math.floor((self.data.posZ or 0) * 100)
	data.ForwardX = math.floor((self.data.ForwardX or 0) * 100)
	data.ForwardY = math.floor((self.data.ForwardY or 0) * 100)
	data.ForwardZ = math.floor((self.data.ForwardZ or 0) * 100)
	
	local scaletValues = string.split(self.data.Para1, "|")
	if scaletValues then
		data.scaleX = math.floor((scaletValues[1] or 1) * 100)
		data.scaleY = math.floor((scaletValues[2] or 1) * 100)
		data.scaleZ = math.floor((scaletValues[3] or 1) * 100)
	end
		
	data.ModelID = self.data.ModelID
	data.ElementID = self.data.ElementID
	data.sceneType = self.data.sceneType
    data.entity_type = self.entityType
	return msg_pack.pack(data)
end

function Barrier:GetBornPosition()
	return Vector3.New(self.data.posX, self.data.posY, self.data.posZ)
end

function Barrier:GetPosition()
	return self.behavior:GetPosition()
end

function Barrier:Destroy()
	self.eventManager.Fire('OnDestroy')
end
	-- 注：请勿直接调用self.OnDestroy(), 想要销毁对象，请调用self:GetEntityManager().DestroyPuppet(self.uid)
function Barrier:OnDestroy()
	BaseObject.OnDestroy(self)
	self.behavior:Destroy()
	self.behavior = nil
end

return Barrier