---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 中毒 
-- 每秒损失【参数1】*M1血量,(M1是伤害逻辑里面的基础伤害计算)	
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffPoison = ExtendClass(Buff)

function BuffPoison:__ctor(scene, buff_id, data)
    self.pulse_interval = 1
end

function BuffPoison:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1)/10000

    return M1 * percent;
end

-- buff起作用
function BuffPoison:OnPulse()
    Buff.OnPulse(self)
    SkillAPI.TakeDamage(self.owner, self.data.source, self.data.skill, self.OnDamageCorrect, self)
end

-- buff被添加到单位上时
function BuffPoison:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Poison', self)
end

-- buff被删除的时候
function BuffPoison:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Poison', self)
end
return BuffPoison
