---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/14
-- desc： 311 技能
-- 对目标单体敌人施加一枚毒蛊，使其在接下来的10s内不断受到毒蛊的折磨，
-- 每秒造成115%的魔法伤害（CD 12s）
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '311'

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
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end
end

SkillLib[skill_type] = SkillLocal

return SkillLocal