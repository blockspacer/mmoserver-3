---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/14
-- desc： 134技能
-- 【辅助】为指定友军目标施加一个护盾，可以吸收XX伤害，护盾存在时目标友军不受控制效果影响

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME

local skill_type = '134'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_ALLY
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    local target = data.target

    if target then
        self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
    end
    
end

SkillLib[skill_type] = SkillLocal

return SkillLocal