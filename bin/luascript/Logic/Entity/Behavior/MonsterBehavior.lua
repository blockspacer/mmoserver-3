---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/1
-- desc： 单位表现
---------------------------------------------------


local Behavior = require "Logic/Entity/Behavior/Behavior"
local MonsterBehavior = ExtendClass(Behavior)

function MonsterBehavior:__ctor(owner)
	self.modelId = nil
	self:OnCreate()
end

function MonsterBehavior:GetCurrentBehaviorLength()
	return 5
end


function MonsterBehavior:OnCreate()   
    self.modelId = self.owner.data.ModelID
end

return MonsterBehavior