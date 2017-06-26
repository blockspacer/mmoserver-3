---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 消化
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffAddHpMp = ExtendClass(Buff)

function BuffAddHpMp:__ctor(scene, buff_id, data)
    self.pulse_interval = 1
end

-- buff起作用
function BuffAddHpMp:OnPulse()
    Buff.OnPulse(self)
    -- 每秒回血
    if not GRunOnClient then
        local skill_id 
        if self.data.skill then
            skill_id = self.data.skill.skill_id
        end


        for k,value in pairs(self.buff_data.FixedPara) do
            if value == 1 then
                SkillAPI.AddHp(
                    self.owner, 
                    self.owner.hp_max() * self:GetParaInTable(1, k) / 10000 + self:GetParaInTable(2, k) / 10000, 
                    self.data.source, 
                    skill_id)
            elseif value == 2 then
                SkillAPI.AddMp(
                    self.owner, 
                    self.owner.mp_max() * self:GetParaInTable(1, k) / 10000 + self:GetParaInTable(2, k) / 10000, 
                    self.data.source, 
                    skill_id)
            end

        end

    end
end

return BuffAddHpMp
