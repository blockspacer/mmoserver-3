---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 
-- 【防御】免伤20%，并且血量无法被降低——半个无敌，持续10s，同时进入霸体4s

                                                                            
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '232'

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
    
    self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
    self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff3), self)
end

SkillLib[skill_type] = SkillLocal 

return SkillLocal