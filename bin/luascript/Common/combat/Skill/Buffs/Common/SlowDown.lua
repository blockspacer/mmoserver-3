---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 减速
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffSlowDown = ExtendClass(Buff)

function BuffSlowDown:__ctor(scene, buff_id, data)
	self.move_speedPercent = 1 - self:GetPara(1)/10000
	self.work_independent = true
end

function BuffSlowDown:OnTick(interval)
    Buff.OnTick(self, interval)
    
end

-- buff被添加到单位上时
function BuffSlowDown:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('SlowDown', self)
end

-- buff被删除的时候
function BuffSlowDown:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('SlowDown', self)
end

return BuffSlowDown

