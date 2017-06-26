---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 
-- 【通用】群体buff，防御提高10%，持续60s，同时提高自身眩晕抗性10点，持续10s
                                                                            
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '231'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    local units = SkillAPI.EnumUnitsRandom(
        self.owner, 
        self:GetRangeParams(), 
        nil, 10000, nil, true)

    for _, unit in pairs(units) do
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end

    self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
end

SkillLib[skill_type] = SkillLocal 

return SkillLocal