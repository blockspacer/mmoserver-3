---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/3
-- desc： 普通攻击
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '1'

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
    -- 如果 没有弹道，就直接造成伤害
    if self.Bullet == 0 then
        local target = data.target
        if target then
            SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
        end
    end
end

function SkillLocal:OnBulletHit(target)
    Skill.OnBulletHit(self, target)
    if self.Bullet ~= 0 then
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(3)/10000
end

SkillLib[skill_type] = SkillLocal 

return SkillLocal