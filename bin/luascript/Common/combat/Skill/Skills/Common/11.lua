---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/06
-- desc： aoe+驱散

--[[
对范围内敌人，最多【1】个目标.造成【2】的伤害。并驱散每个敌人身上【3】个随机增益buff。                                     
                                       
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '11'

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
        unit.skillManager:DisperseBuff(BuffType.Positive, self:GetPara(3))
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(2) / 10000

    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal