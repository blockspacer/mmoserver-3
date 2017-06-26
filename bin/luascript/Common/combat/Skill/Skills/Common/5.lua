---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 多次攻击（aoe）
--[[
攻击范围内最多【1】个敌人，攻击【2】次，每次造成【3】的伤害。                                        
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '5'

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
    local units = SkillAPI.EnumUnitsRandom(
            self.owner, 
            self:GetRangeParams(), 
            nil, self:GetPara(1), true)

    for i = 1, self:GetPara(2), 1 do
        for _, unit in pairs(units) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        end
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(3) / 10000

    return M4 * percent + self:GetPara(4) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal