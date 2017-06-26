---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 增加闪避
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffDodgeUp = ExtendClass(Buff)

function BuffDodgeUp:__ctor(scene, buff_id, data)
	self.missPercent = 1 + self:GetPara(1)/10000
	self.work_independent = true
end

function BuffDodgeUp:OnTick(interval)
    Buff.OnTick(self, interval)
    
end

-- buff被添加到单位上时
function BuffDodgeUp:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('DodgeUp', self)
end

-- buff被删除的时候
function BuffDodgeUp:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('DodgeUp', self)
end

return BuffDodgeUp

