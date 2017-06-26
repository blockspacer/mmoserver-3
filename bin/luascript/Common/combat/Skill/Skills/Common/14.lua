---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： aoe（索敌）+buff
-- 对[目标]范围内敌人，最多【4】个目标.造成【1】的伤害，额外附加【2】伤害。有【3】概率给目标附加【buff ID1】和【buff ID2】                                                                            
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '14'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
end

function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    local function MakeBuff(target)
        if self.skill_data.Buff1 ~= 0 then
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        end
        if self.skill_data.Buff2 ~= 0 then
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
        end
    end

    local target = data.target
    if target then
        local units = SkillAPI.EnumUnitsRandom(
            target, 
            self:GetRangeParams(), 
            nil, self:GetPara(4), true)

        for _, unit in pairs(units) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
            SkillAPI.RandEvent(self:GetPara(3)/10000, MakeBuff, unit)
        end
    end

   
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(2) / 10000
end

SkillLib[skill_type] = SkillLocal 

return SkillLocal