---------------------------------------------------
-- auth： panyinglong
-- date： 2016/10/26
-- desc： 技能召唤物
---------------------------------------------------

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end

local CreateSummonBehavior = require "Logic/Entity/Behavior/SummonBehavior"

local Toy = require "Common/combat/Entity/Toy"
local Summon = ExtendClass(Toy)

-- 召唤物
function Summon:__ctor(scene, data)
	self.entityType = EntityType.Summon

	self.create_proxy_flag = true
end

function Summon:Born()
	Toy.Born(self)
	self.behavior = CreateSummonBehavior(self)

	self:SetSpeed(self.data.speed or 500)
	self:AddEffect(self.data.effect)
end

function Summon:GetClientNeedInfo()
	local data = {}
    data.entity_id = self.data.entity_id
    data.entity_type = self.entityType
    data.res = self.data.res
    data.scale = self.data.scale
    data.effect = self.data.effect
    data.speed = self.data.speed

	return msg_pack.pack(data)
end

return Summon
