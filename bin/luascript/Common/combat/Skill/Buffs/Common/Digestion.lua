---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 消化
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffDigestion = ExtendClass(Buff)

function BuffDigestion:__ctor(scene, buff_id, data)
    self.pulse_interval = 1
    self.work_independent = true
end

-- buff被添加到单位上时
function BuffDigestion:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Digestion', self)
end

-- buff被删除的时候
function BuffDigestion:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Digestion', self)
end

-- buff起作用
function BuffDigestion:OnPulse()
    Buff.OnPulse(self)
    -- 每秒回血
    if not GRunOnClient then
        local skill_id 
        if self.data.skill then
            skill_id = self.data.skill.skill_id
        end
        SkillAPI.AddHp(
            self.owner, 
            self.owner.hp_max() * self:GetPara(1) / 10000, 
            self.data.source, 
            skill_id)
    end
end

return BuffDigestion
