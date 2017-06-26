---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 陷阱-自身

--[[
前方【1】米，释放一个陷阱，持续【2】s。使区域内敌方附加【buff 1】。己方附加【buff 2】                                      
                                                    
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10'

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

    local position = MathHelper.GetForward(self.owner, self:GetPara(1))

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

        local friends = SkillAPI.EnumUnitsRandomInCircle(
            self.owner, 
            position,
            self:GetRangeParams(), 
            nil, 1000, nil, true)

        for _, unit in pairs(friends) do
            if self.skill_data.Buff2 ~= 0 then
                unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
            end
        end

    end

    self:GetTimer().Numberal(1, self:GetPara(2) / 1000, rangeAttack)        
end

SkillLib[skill_type] = SkillLocal

return SkillLocal