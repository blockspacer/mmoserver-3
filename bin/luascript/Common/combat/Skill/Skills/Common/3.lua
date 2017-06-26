---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 单体输出 + 吸血
-- 对单体敌人造成【1】的伤害，额外附加【2】伤害。并恢复造成伤害的【3】的血量。                                      
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '3'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
end

function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    local target = data.target
    if target then
        local damage = SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
        SkillAPI.AddHp(self.owner, damage * self:GetPara(3) / 10000, self.owner, self.skill_id)
    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(2) / 10000
end

SkillLib[skill_type] = SkillLocal 

return SkillLocal