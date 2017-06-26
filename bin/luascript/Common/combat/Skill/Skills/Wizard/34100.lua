---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/17
-- desc： Skill Test
--[[
攻击目标及其周围2米范围内最多5个敌人，造成20%的魔法伤害，
并驱散每个敌人身上随机一个增益状态（CD 15s）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '34100'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    local target = data.target
    if target then
        local units = SkillAPI.EnumUnitsRandomInCircle(
                self.owner,
                target:GetPosition(), 
                {
                    area_type = EnumUnitsAreaType.Circle,
                    radius = self.area_radius,
                }, 
                nil, self:GetPara(1), true)

        for _, unit in pairs(units) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
            -- 驱散buff
            unit.skillManager:DisperseBuff(BuffType.Positive, 1)
        end
    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(2) / 10000 
    return M4 * percent + self:GetPara(3) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal