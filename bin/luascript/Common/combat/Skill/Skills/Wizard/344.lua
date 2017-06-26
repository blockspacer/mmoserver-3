---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/17
-- desc： Skill Test
--[[
释放巫术，折磨自身周围4米范围内最多5个敌人，
使他们进入恐惧状态，持续4s（CD 14s）

群体恐惧（特效+动作重制，挥出无数禁制，禁锢自身周围的敌人，
并对他们造成100%的魔法伤害，锁足持续4s，若目标处于中毒状态，则锁足变成恐惧）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '344'

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
            nil, 10000, true)

    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        if target:HasStatus('Poison') then
            unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
        else
            unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        end
    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000 
    return M4 * percent + self:GetPara(2) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal