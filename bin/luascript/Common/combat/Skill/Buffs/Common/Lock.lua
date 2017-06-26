---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 锁足
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffLock = ExtendClass(Buff)

function BuffLock:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- buff被添加到单位上时
function BuffLock:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Lock', self)
end

-- buff被删除的时候
function BuffLock:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Lock', self)
end

return BuffLock

