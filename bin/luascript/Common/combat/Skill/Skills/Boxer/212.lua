---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： 
--[[
右脚侧踹，攻击单体敌人，造成[Para1/100]%的物理伤害以及[math.floor(Para3/10000)]点额外伤害，
有[Para2/100]%几率降低目标移动速度[buff1:Para1/100]%，持续[buff1:time]秒，并使目标身上的印记增加2层(技能CD[CD/1000]秒)
]] 
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '212'

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

    local function MakeBuff(target)
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
        target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
    end

    local target = data.target
    if target then
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
        SkillAPI.RandEvent(self:GetPara(2) / 10000, MakeBuff, target)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(3) / 10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal