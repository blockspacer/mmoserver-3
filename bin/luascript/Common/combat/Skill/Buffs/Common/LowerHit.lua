---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 降命中
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffLowerHit = ExtendClass(Buff)

function BuffLowerHit:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- buff被添加到单位上时
function BuffLowerHit:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('LowerHit', self)
end

-- buff被删除的时候
function BuffLowerHit:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('LowerHit', self)
end

return BuffLowerHit
