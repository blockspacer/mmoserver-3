---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
--[[
【剑气】对自身周围4米范围内最多7个敌人造成5次伤害，每次造成85%物理伤害（16s）（一次性伤害，冒血数字出5次）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '132'

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

    for i = 1, self:GetPara(2), 1 do
        for _, unit in pairs(units) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        end
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(3) / 10000

    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal