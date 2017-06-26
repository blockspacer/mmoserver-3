---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/3
-- desc： 远程物理攻击
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '10011'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    if self:GetPara(1) == 1 then
        self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
    else
        self.cast_target_type = CastTargetType.CAST_TARGET_NONE
    end

    self.position = nil
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    if self:GetPara(1) == 1 then
        if data.target == nil then
            return 
        end
        self.position = data.target:GetPosition()
    else
        self.position = self.owner:GetPosition()
    end

    self:GetTimer().Numberal(1, self:GetPara(3), self.rangeAttack, self)

end

function SkillLocal:rangeAttack()

    local is_enemy = nil
    local is_ally = nil
    if self:GetPara(2) == 1 then
        is_enemy = true
    else
        is_ally = true
    end

    local units = SkillAPI.EnumUnitsInCircle(
        self.owner,
        self.position, 
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self.area_radius,
        }, 
        nil, is_enemy, is_ally)

    for _, unit in pairs(units) do
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end
end

SkillLib[skill_type] = SkillLocal

return SkillLocal