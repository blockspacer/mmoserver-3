---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 解控+buff
-- 解除自身移动限制，并附加【buff ID1】和【buff ID2】                                        
                                                                            
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '15'

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

    self.owner.skillManager:DisperseBuff(BuffType.Control, 100)

    if self.skill_data.Buff1 ~= 0 then
        self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end
    if self.skill_data.Buff2 ~= 0 then
        self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
    end
   
end

SkillLib[skill_type] = SkillLocal 

return SkillLocal