---------------------------------------------------
-- auth： zhangzeng
-- date： 2016/9/12
-- desc： 加载屏障
---------------------------------------------------
local Behavior = require "Logic/Entity/Behavior/Behavior"
local ConveyToolBehavior = ExtendClass(Behavior)

function ConveyToolBehavior:__ctor(owner)
	self.modelId = nil
	self:OnCreate()
end

function ConveyToolBehavior:OnCreate()
    self.modelId = self.owner.data.ModelID
end

return ConveyToolBehavior