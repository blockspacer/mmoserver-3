---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 中毒
-- 每秒固定损失【参数1】的血量

---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffPoison3 = ExtendClass(Buff)

function BuffPoison3:__ctor(scene, buff_id, data)
    self.pulse_interval = 1

end

-- buff起作用
function BuffPoison3:OnPulse()
    Buff.OnPulse(self)
    -- 每秒损失多少血量
    if not GRunOnClient then
        SkillAPI.MinusHp(
            self.owner, 
            self:GetPara(1) / 10000, 
            self.data.source,
            self.data.skill.skill_id)
    end
end

function BuffPoison3:OnTick(interval)
    Buff.OnTick(self, interval)

end

-- buff被添加到单位上时
function BuffPoison3:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Poison', self)
end

-- buff被删除的时候
function BuffPoison3:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Poison', self)
end

return BuffPoison3
