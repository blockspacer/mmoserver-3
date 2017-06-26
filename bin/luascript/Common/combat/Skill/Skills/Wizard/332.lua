---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
释放巫术，攻击自身及周围4米范围内最多6个敌人，
造成115%的魔法伤害，并击退他们2米（CD 23s）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '332'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE

end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)
    local units = SkillAPI.EnumUnitsRandom(
            self.owner, 
            {
                area_type = EnumUnitsAreaType.Circle,
                radius = self.area_radius,
            }, 
            nil, self:GetPara(1), true)


    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        if self.skill_data.Buff1 ~= 0 then
            unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        end
    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(2) / 10000
    return M4 * percent + self:GetPara(4) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal