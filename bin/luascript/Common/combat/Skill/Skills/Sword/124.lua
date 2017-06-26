---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 剑气护体
-- 施加一道剑阵围绕自身，对自身周围的敌人每秒造成[buff1:Para1/100]%的物理伤害以及[math.floor(buff1:Para2/10000)]的额外伤害，
-- 持续10s，敌人每被剑阵伤害3次，便会附加一层出血buff(技能CD[CD/1000]秒)
                                                                            
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '124'

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

    local count = {}

    local function rangeAttack()
        local enemys = SkillAPI.EnumUnitsRandom(
            self.owner, 
            self:GetRangeParams(), 
            nil, 10000, true)

        for _, unit in pairs(enemys) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
            if count[unit.uid] then
                count[unit.uid] = count[unit.uid] + 1
            else
                count[unit.uid] = 1
            end
            if count[unit.uid] % 3 == 0 then
                unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
            end
        end

    end

    self:GetTimer().Numberal(1, 10, rangeAttack)   
   
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(2) / 10000
end

SkillLib[skill_type] = SkillLocal 

return SkillLocal