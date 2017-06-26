---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
--[[
快速向前方挥出[Para3]剑，攻击前方矩形范围内的敌人，
每次造成[Para1/100]%物理伤害以及[math.floor(Para2/10000)]点额外伤害，
最后一剑会将敌人击退[Para4]米(技能CD[CD/1000]秒)

]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '142'

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

    self:GetTimer().Numberal(0.2, self:GetPara(3), rangeAttack)   
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent + self:GetPara(2) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal