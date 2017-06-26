---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 物理攻击力提升

---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffPhysicAttackUp = ExtendClass(Buff)

function BuffPhysicAttackUp:__ctor(scene, buff_id, data)
	self.physic_attack = self:GetPara(1) / 10000
	self.work_independent = true
end

function BuffPhysicAttackUp:OnTick(interval)
    Buff.OnTick(self, interval)
    
end

-- buff被添加到单位上时
function BuffPhysicAttackUp:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('PhysicAttackUp', self)
end

-- buff被删除的时候
function BuffPhysicAttackUp:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('PhysicAttackUp', self)
end

return BuffPhysicAttackUp

