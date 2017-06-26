---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 
-- 【输出】对自身周围所有敌人造成伤害，同时附加1层印记，
-- 并使自身在5s内将50%的防御转化为攻击力（增加的攻击=【50%参数】防御/2）

                                                                            
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '242'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    local units = SkillAPI.EnumUnitsRandom(
        self.owner, 
        self:GetRangeParams(), 
        nil, 10000, true)

    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end

    self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(2) / 10000
end

SkillLib[skill_type] = SkillLocal 

return SkillLocal