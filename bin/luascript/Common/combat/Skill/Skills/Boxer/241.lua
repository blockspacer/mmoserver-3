---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
利用气劲，将目标单体敌人吸到身边，并刷新214的技能CD，同时使敌人定身2s
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '241'

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
end


function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    local target = data.target

    local function Happen()
        self.owner.skillManager:RefreshBySkillID(tostring(self:GetPara(2)))
    end

    if target then
        --local target_pos = MathHelper.GetForward(self.owner, 2)
        --SkillAPI.MoveToPostion(target, target_pos, 0.3)
        SkillAPI.RandEvent(self:GetPara(1) / 10000, Happen)
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
    end
end

SkillLib[skill_type] = SkillLocal

return SkillLocal