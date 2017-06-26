---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/31
-- desc： Skill Test
--[[
身体幻化出4道分身，本体+分身同时向目标区域射出箭矢，
攻击目标敌人及其周围4米范围内最多5个敌人3次，每次造成110%的物理伤害（分身全是特效，不是真实单位）         
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '442'

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

    for i = 1, 3, 1 do
        for _, unit in pairs(units) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        end
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(2) / 10000

    return M4 * percent + self:GetPara(3) / 10000;
end

SkillLib[skill_type] = Skilllocal

return SkillLocal