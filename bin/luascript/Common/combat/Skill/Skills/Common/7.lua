---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： 己方buff
--[[
有【1】概率给自己附加【buff 1】和【buff 2】										
]]

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '7'

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

    local function MakeBuff(target)
        if self.skill_data.Buff1 ~= 0 then
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        end
        if self.skill_data.Buff2 ~= 0 then
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
        end
    end

    SkillAPI.RandEvent(self:GetPara(1)/10000, MakeBuff, self.owner)
end

SkillLib[skill_type] = SkillLocal

return SkillLocal