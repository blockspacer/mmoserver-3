---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 霸体
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffSuperArmor = ExtendClass(Buff)

function BuffSuperArmor:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- buff被添加到单位上时
function BuffSuperArmor:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('SuperArmor', self)
end

-- buff被删除的时候
function BuffSuperArmor:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('SuperArmor', self)
end

return BuffSuperArmor

