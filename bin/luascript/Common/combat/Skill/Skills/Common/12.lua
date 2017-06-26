---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： aoe+陷阱


--[[
对范围内敌人，最多【1】个目标.造成【2】的伤害。并在范围形成陷阱，给敌人附加【buff 1】，持续【3】s。                                     
                                      
                                                    
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '12'

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

    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
    end

    local position = self.owner:GetPosition()

    local function rangeAttack()
        local enemys = SkillAPI.EnumUnitsRandomInCircle(
            self.owner, 
            position,
            self:GetRangeParams(), 
            nil, 1000, true)

        for _, unit in pairs(enemys) do
            if self.skill_data.Buff1 ~= 0 then
                unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
            end
        end

    end

    self:GetTimer().Numberal(1, self:GetPara(3) / 1000, rangeAttack)        
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(2) / 10000

    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal