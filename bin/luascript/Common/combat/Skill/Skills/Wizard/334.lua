---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/14
-- desc： Skill Test
--[[
解除自身友方单位的所有移动限制类效果，并使他们免疫控制效果[buff1:time]秒

]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '334'

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

    local units = SkillAPI.EnumUnitsRandom(
        self.owner, 
        self:GetRangeParams(), 
        nil, 10000, nil, true)

    for _, unit in pairs(units) do
        unit.skillManager:DisperseBuff(BuffType.Control, 100)
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end
end

SkillLib[skill_type] = SkillLocal

return SkillLocal