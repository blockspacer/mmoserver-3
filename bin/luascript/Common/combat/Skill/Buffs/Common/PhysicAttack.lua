---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 物理攻击力

---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffPhysicAttack = ExtendClass(Buff)

function BuffPhysicAttack:__ctor(scene, buff_id, data)
	self.physic_attack = self:GetPara(1) / 10000
	self.work_independent = true
end

function BuffPhysicAttack:OnTick(interval)
    Buff.OnTick(self, interval)
    
end

return BuffPhysicAttack

