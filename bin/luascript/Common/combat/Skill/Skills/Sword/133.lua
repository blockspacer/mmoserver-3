---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 133
-- 解除自身移动限制，并朝前方瞬移5米，并在瞬移结束时挥出一道剑气，
-- 攻击身前所有敌人，造成[Para1/100]%物理伤害以及[math.floor(Para2/10000)]点额外伤害(技能CD[CD/1000]秒)
                                        
                                                                            
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '133'

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

    self.owner.skillManager:DisperseBuff(BuffType.Control, 100)

end

function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)
    local enemys = SkillAPI.EnumUnitsRandom(
        self.owner, 
        self:GetRangeParams(), 
        nil, 10000, true)

    for _, unit in pairs(enemys) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent + self:GetPara(3) / 10000
end

SkillLib[skill_type] = SkillLocal 

return SkillLocal