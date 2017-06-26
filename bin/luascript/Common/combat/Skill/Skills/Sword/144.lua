---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
-- 对8米内单体目标造成伤害，造成[Para1/100]%物理伤害以及[math.floor(Para2/10000)]点额外伤害，
-- 并使目标身上的所有出血buff一次性爆发

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '144'

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
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)

        local buff, index = target.skillManager:FindBuffByIDUnderSource(self.skill_data.Buff1, self.owner)
        if buff then
            local function ExplodeBlood(M1, M2, M3, M4, target)
                local damage = buff:OnDamageCorrect(M1, M2, M3, M4, target)
                return damage * buff.remain_time;
            end
            SkillAPI.TakeDamage(target, self.owner, self, ExplodeBlood)
            
            target.skillManager:RemoveBuff(buff)
        end

    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent + self:GetPara(3) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal