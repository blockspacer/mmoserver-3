---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/3
-- desc： 
--[[
大口撕咬目标，对目标造成【参数1百分比】的物理伤害。
释放后，会陷入消化状态【buffID1】（消化状态中每秒回复5%的最大血量。持续3s。）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '10061'

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
        self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(2) / 10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal