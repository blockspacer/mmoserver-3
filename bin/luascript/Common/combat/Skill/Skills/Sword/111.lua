---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test

-- 攻击单体敌人，对其造成120%的物理伤害，若敌人处于出血状态，则额外附加50%的物理伤害（CD6s）

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '111'

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
        local damage = SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000
    if target:HasStatus('Bleeding') then
        percent = percent + self:GetPara(2) / 10000
    end
    return M4 * percent + self:GetPara(3) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal