---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/31
-- desc： Skill Test
--[[
连续射出多支火焰箭，攻击目标敌人及其周围周围3米内最多5个敌人造成80%的物理伤害，
并在目标区域形成火海，对区域内敌人每秒造成200点伤害，持续5s          
]]

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '422'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT

    self.position = nil
end


function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    local target = data.target
    if target then
        -- 单体伤害
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
        self.position = target:GetPosition()

        -- 范围伤害
        local units = SkillAPI.EnumUnitsRandom(
            self.owner, 
            {
                area_type = EnumUnitsAreaType.Circle,
                radius = self.area_radius,
            }, 
            nil, self:GetPara(1), true)

        for _, unit in pairs(units) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        end

        -- 区域伤害
        self:GetTimer().Numberal(1, self:GetPara(4), self.rangeAttack, self)
    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(2) / 10000
    return M4 * percent;
end

function SkillLocal:rangeAttack()
    local units = SkillAPI.EnumUnitsInCircle(
        self.owner,
        self.position, 
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self.area_radius,
        }, 
        nil, true)

    for _, unit in pairs(units) do
        SkillAPI.MinusHp(unit, self:GetPara(3), self.owner)
    end
end

SkillLib[skill_type] = SkillLocal

return SkillLocal