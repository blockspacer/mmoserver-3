---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/14
-- desc： 322 技能
--[[
向一块半径为4米的区域施加蛊毒，当敌人进入区域内，
则每秒受到100%魔法伤害，蛊毒持续存在8s（CD 18s）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '322'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT

    self.position = nil

    self.bullet_hit_location = true
end

function SkillLocal:OnBulletHitLocation(location)
    Skill.OnBulletHitLocation(self, location)
    if location then
        self.position = location
        self:rangeAttack()
        if self:GetPara(2) > 1 then
            self:GetTimer().Numberal(1, self:GetPara(2) - 1, self.rangeAttack, self)
        end
    end
end

function SkillLocal:rangeAttack()
    local units = SkillAPI.EnumUnitsInCircle(
        self.owner,
        self.position, 
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self.area_radius,
        }, 
        nil, true)

    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent  + self:GetPara(3) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal