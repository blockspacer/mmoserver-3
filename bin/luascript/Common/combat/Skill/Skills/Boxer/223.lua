---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
【气劲】右脚用力踩踏地面，强大的气劲使地面龟裂，
并且对自身周围4米范围内最多5个敌人造成110%的物理伤害，并有20%几率使他们瘫痪，持续4s
]]

-- TODO 基本测试完成, 还差 眩晕效果的测试
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '223'

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

    local function MakeBuff(target)
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end

    local units = SkillAPI.EnumUnitsRandom(
            self.owner, 
            {
                area_type = EnumUnitsAreaType.Circle,
                radius = self.area_radius,
            }, 
            nil, self:GetPara(1), true)

    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        SkillAPI.RandEvent(self:GetPara(3) / 10000, MakeBuff, unit)
    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(2) / 10000
    return M4 * percent + self:GetPara(4) / 10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal