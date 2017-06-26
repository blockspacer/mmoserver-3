---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
【输出】攻击单体敌人，若目标身上存在印记，则每层印记会额外降低目标血量上限5%，该效果持续10s（PVE效果降低一半）

]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '244'

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

    if target then
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)


        local buff = target.skillManager:IfExistBuff(self.skill_data.Buff1, self.owner)
        for i = 1, buff.count do
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
        end
        target.skillManager:RemoveBuff(buff)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(2) / 10000
    return M4 * percent + self:GetPara(4) / 10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal