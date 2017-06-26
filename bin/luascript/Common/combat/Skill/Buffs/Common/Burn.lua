---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 灼烧
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffBurn = ExtendClass(Buff)

function BuffBurn:__ctor(scene, buff_id, data)
    self.pulse_interval = 1
    self.work_independent = true
end

-- buff被添加到单位上时
function BuffBurn:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Burn', self)
end

-- buff被删除的时候
function BuffBurn:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Burn', self)
end

-- buff起作用
function BuffBurn:OnPulse()
    Buff.OnPulse(self)
    -- 每秒损失多少血量
    self.owner.hp = self.owner.hp - self:GetPara(1)/10000
end

return BuffBurn
