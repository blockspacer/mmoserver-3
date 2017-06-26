---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
【霸体】爆发全身气劲，强大的气劲会包裹在自身周围，使自己免疫所有控制，持续10s
]]
-- TODO 霸体没法 测试，因为现在还没有野怪 拥有 控制型技能
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '233'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)
    self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
end

SkillLib[skill_type] = SkillLocal

return SkillLocal