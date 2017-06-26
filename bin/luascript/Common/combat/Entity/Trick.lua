---------------------------------------------------
-- auth： pangyinglong
-- date： 2017/3/18
-- desc： 机关
---------------------------------------------------

local Toy = require "Common/combat/Entity/Toy"
local CreateTrickBehavior = require "Logic/Entity/Behavior/TrickBehavior"
local Trick = ExtendClass(Toy)

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end

function Trick:__ctor(scene, data, event_delegate)
	self.entityType = EntityType.Trick
	if not GRunOnClient then
		self.create_proxy_flag = true
		self.data.property = {[14] = 0}
	end
	
	self.data = data
	self.uid = data.entity_id
	self.behavior = nil
end

function Trick:Born()
	Toy.Born(self)
	self.behavior = CreateTrickBehavior(self)
end

function Trick:EnterScene()
end

function Trick:OnTrigger()
	self.behavior:BehaviorTrigger()
end

function Trick:GetClientNeedInfo()
	local data = {}
    data.entity_id = self.data.entity_id
	data.ModelID  = self.data.ModelID
	data.ElementID = self.data.ElementID
	data.Scale = self.data.Scale
	data.ID = self.data.ID
    data.entity_type = self.entityType
	return msg_pack.pack(data)
end
	
function Trick:Destroy()
	self:OnDestroy()
end

function Trick:OnDestroy()
	Toy.OnDestroy(self)
end

return Trick