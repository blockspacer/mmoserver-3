---------------------------------------------------
-- auth： panyinglong
-- date： 2017/2/13
-- desc： 
---------------------------------------------------

local CreateEmptyGOBehavior = require "Logic/Entity/Behavior/EmptyGOBehavior"

local Toy = require "Common/combat/Entity/Toy"
local EmptyGO = ExtendClass(Toy)

-- 子弹
function EmptyGO:__ctor(scene, data)
	self.entityType = EntityType.EmptyGO
end

function EmptyGO:Born()
	Toy.Born(self)
	self.behavior = CreateEmptyGOBehavior(self)
end

return EmptyGO