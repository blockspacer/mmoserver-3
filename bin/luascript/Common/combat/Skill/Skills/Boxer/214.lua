---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
点穴，攻击单体敌人，造成180%的物理伤害，本次攻击无视目标闪避，有30%几率使目标封脉，持续4s
]]
-- 测试成功
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '214'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
    -- 无视闪避
    self.ignore_miss = true
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    local function MakeBuff(target)
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end

    local target = data.target
    if target then
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
        SkillAPI.RandEvent(self:GetPara(2) / 10000, MakeBuff, target)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(3) / 10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal