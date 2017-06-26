---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
使用巫术提升自身及周围最多4个友军的魔法攻击力10%，持续15s，这个状态不可以被驱散（CD 30s）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '333'

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
            {
                area_type = EnumUnitsAreaType.Circle,
                radius = self.area_radius,
            }, 
            nil, self:GetPara(1), nil, true)

    self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    for _, unit in pairs(units) do
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end

end


SkillLib[skill_type] = SkillLocal

return SkillLocal