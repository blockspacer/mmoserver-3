---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 中毒
-- 每秒损失【参数1】比例的血量
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffPoison2 = ExtendClass(Buff)

function BuffPoison2:__ctor(scene, buff_id, data)
    self.pulse_interval = 1
end

-- buff起作用
function BuffPoison2:OnPulse()
    Buff.OnPulse(self)
    -- 每秒损失多少血量
    if not GRunOnClient then
        SkillAPI.MinusHp(
            self.owner, 
            self.owner.hp * self:GetPara(1) / 10000, 
            self.data.source,
            self.data.skill.skill_id)
    end
end

function BuffPoison2:OnTick(interval)
    Buff.OnTick(self, interval)

end


-- buff被添加到单位上时
function BuffPoison2:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Poison', self)
end

-- buff被删除的时候
function BuffPoison2:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Poison', self)
end

return BuffPoison2
