---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
旋风腿，攻击自身周围5米范围内最多4个敌人3次，
每次造成80%的物理伤害，击退敌人1米，并有20%几率使他们瘫痪2s
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '243'

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

    local function MakeBuff(target)
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end

    for _, unit in pairs(units) do
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
        SkillAPI.RandEvent(self:GetPara(3) / 10000, MakeBuff, unit)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(2) / 10000
    return M4 * percent + self:GetPara(4) / 10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal