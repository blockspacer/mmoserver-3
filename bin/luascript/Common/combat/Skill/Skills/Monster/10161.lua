---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： 10161 技能
--[[
对目标造成【1 万分比】的法术伤害，【2 万分比】概率将目标牵引到身前，并附加【buff ID1】。
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '10161'

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

    local function Happen()
        SkillAPI.MoveToward(target, self.owner, 0.3)
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end

    if target then
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
        SkillAPI.RandEvent(self:GetPara(2) / 10000, Happen)

    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent
end

SkillLib[skill_type] = SkillLocal

return SkillLocal