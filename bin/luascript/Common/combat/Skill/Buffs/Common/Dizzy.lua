---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 眩晕
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffDizzy = ExtendClass(Buff)

function BuffDizzy:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- buff被添加到单位上时
function BuffDizzy:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Dizzy', self)
end

-- buff被删除的时候
function BuffDizzy:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Dizzy', self)
end

return BuffDizzy

