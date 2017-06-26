---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/14
-- desc： 324 技能
--[[
召唤蛊虫围绕自身，靠近自身2米内的敌人每秒受到100%的魔法伤害，蛊虫持续存在8s（CD 17s）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '324'

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
    
    self:GetTimer().Numberal(1, self:GetPara(2), self.rangeAttack, self)  
end

function SkillLocal:rangeAttack()
    local units = SkillAPI.EnumUnitsRandom(
        self.owner, 
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self.area_radius,
        }, 
        nil, 1000, true)

    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(3) / 10000

end

SkillLib[skill_type] = SkillLocal

return SkillLocal