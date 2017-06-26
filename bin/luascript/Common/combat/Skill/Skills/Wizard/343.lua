---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
--[[
向指定方向释放数道能量气波，对沿途敌人造成造成[Para1/100]%的法术伤害以及[math.floor(Para3/10000)]点额外伤害，
若敌人处于锁足或恐惧状态，则对敌人额外附加[Para3/100]%的法术伤害

]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '343'

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

    local enemys = SkillAPI.EnumUnitsRandom(
        self.owner, 
        self:GetRangeParams(), 
        nil, 10000, true)

    for _, unit in pairs(enemys) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000
    if target:HasStatus('Lock') or target:HasStatus('Fear') then
        percent = percent + self:GetPara(3) / 10000
    end

    return M4 * percent + self:GetPara(2) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal