---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
攻击单体敌人，对其造成[Para1/100]%的物理伤害以及[math.floor(Para2/10000)]的额外伤害，
并打断其持续施法，同时降低目标攻击[buff1:Para1/100]%，持续[buff1:time]秒

]]
-- 测试成功
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '211'

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

    local function MakeBuff(target)
        
    end

    local target = data.target
    if target then
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
        target.skillManager:BreakSkill()
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(2) / 10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal