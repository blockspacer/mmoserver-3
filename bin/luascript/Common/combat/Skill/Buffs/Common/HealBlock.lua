---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/07
-- desc： 不能加血
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffHealBlock = ExtendClass(Buff)

function BuffHealBlock:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- buff被添加到单位上时
function BuffHealBlock:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('HealBlock', self)
end

-- buff被删除的时候
function BuffHealBlock:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('HealBlock', self)
end

return BuffHealBlock
