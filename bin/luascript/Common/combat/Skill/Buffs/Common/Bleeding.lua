---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 出血
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffBleeding = ExtendClass(Buff)

function BuffBleeding:__ctor(scene, buff_id, data)
    self.pulse_interval = 1
end

-- buff被添加到单位上时
function BuffBleeding:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Bleeding', self)
end

-- buff被删除的时候
function BuffBleeding:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Bleeding', self)
end

function BuffBleeding:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1)/10000

    return M4 * percent;
end

-- buff起作用
function BuffBleeding:OnPulse()
    Buff.OnPulse(self)
    SkillAPI.TakeDamage(self.owner, self.data.source, self.data.skill, self.OnDamageCorrect, self)
end

return BuffBleeding
