---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 降攻
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffLowerAttack = ExtendClass(Buff)

function BuffLowerAttack:__ctor(scene, buff_id, data)
    self.physic_attackPercent = 1 - self:GetPara(1) / 10000
    self.magic_attackPercent = 1 - self:GetPara(1) / 10000
    self.work_independent = true
end

function BuffLowerAttack:OnTick(interval)
    Buff.OnTick(self, interval)

end

-- buff被添加到单位上时
function BuffLowerAttack:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('LowerAttack', self)
end

-- buff被删除的时候
function BuffLowerAttack:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('LowerAttack', self)
end

return BuffLowerAttack

