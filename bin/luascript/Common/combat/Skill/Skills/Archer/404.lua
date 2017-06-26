---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
---------------------------------------------------

require "Common/combat/Skill/Skills/Common/StageMiddleSkill"

local skill_type = '404'

local StageMiddleSkill = require "Common/combat/Skill/Skills/Common/StageMiddleSkill"
local SkillLocal = ExtendClass(StageMiddleSkill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    self.first_skill_id = '401'
    self.next_skill_id = '401'
    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
end

function SkillLocal:OnCastStart(data)
    StageMiddleSkill.OnCastStart(self, data)
    local target = data.target
    if target then
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    --print('Wuli Gongji', self.owner.attribute.physic_attack)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(2)/10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal