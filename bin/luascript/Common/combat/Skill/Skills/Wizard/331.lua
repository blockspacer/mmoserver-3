---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/14
-- desc： 331技能
-- 【治疗】对周围友军回复最大生命值*【1，万分比】 + 法术攻击力*【2，万分比】 + 额外【3，万分制】治疗量

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME

local skill_type = '331'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    local units = SkillAPI.EnumUnitsRandom(
        self.owner, 
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self.area_radius,
        }, 
        nil, 1000, nil, true)

    for _, unit in pairs(units) do
        SkillAPI.AddHp(unit, 
            unit.hp_max() * self:GetPara(1) / 10000 + self.owner.magic_attack() * self:GetPara(2) / 10000 + self:GetPara(3) / 10000,
            self.owner, self.skill_id)
    end
    
end

SkillLib[skill_type] = SkillLocal

return SkillLocal