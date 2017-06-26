---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/07
-- desc： Skill Test

-- 对流血单位造成的伤害增加【参数1百分比】。释放技能后，对目标造成【参数2百分比】的物理伤害。

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10041'

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

    local percent = self:GetPara(2) / 10000
    if target:HasStatus('Bleeding') then
        percent = percent + self:GetPara(1) / 10000
    end
    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal