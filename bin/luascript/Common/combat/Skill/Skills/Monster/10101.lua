---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/3
-- desc： 
--[[
对目标造成【参数1百分比】的【参数2，伤害类型（1：物理；2：法术）】，
并给自己和主人附加【buffID1】和【buffID2】的buff。
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '10101'

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
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
        if self.skill_data.Buff1 ~= 0 then
            self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
            if self.owner.owner then
                self.owner.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
            end
        end
        if self.skill_data.Buff2 ~= 0 then
            self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
            if self.owner.owner then
                self.owner.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
            end
        end
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent
end

SkillLib[skill_type] = SkillLocal

return SkillLocal