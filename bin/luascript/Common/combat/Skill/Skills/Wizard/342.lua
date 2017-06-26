---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
--[[
【输出】对自身周围造成【1万分比】法术伤害以及【2万分制】额外伤害，持续施法【3】秒


]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '342'

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

    local count = 0

    local enemys = SkillAPI.EnumUnitsRandom(
        self.owner, 
        self:GetRangeParams(), 
        nil, 10000, true)

    local function rangeAttack()
        count = count + 1

        for _, unit in pairs(enemys) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)

            if count == self:GetPara(3) then
                unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
            end
        end

    end

    self:GetTimer().Numberal(1, self:GetPara(3), rangeAttack)   
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent + self:GetPara(2) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal