---------------------------------------------------
-- auth： zhangzeng
-- date： 2016/9/12
-- desc： 加载屏障
---------------------------------------------------
local Behavior = require "Logic/Entity/Behavior/Behavior"
local BarrierBehavior = ExtendClass(Behavior)

function BarrierBehavior:__ctor(owner)
	self.modelId = nil
	self:OnCreate()
end

function BarrierBehavior:OnCreate()
    self.modelId = self.owner.data.ModelID
end

return BarrierBehavior