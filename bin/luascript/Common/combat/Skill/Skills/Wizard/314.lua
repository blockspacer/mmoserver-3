---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/14
-- desc： 314 技能
--[[
释放巫术锁链攻击目标、以及目标附近的敌人，锁链每穿过一个敌人伤害降低10%，
最多攻击5个敌人，对第一个敌人造成110%的魔法伤害（CD 18s）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '314'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE

    self.decay = 1
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    self.decay = 1
    for i = 1, 5 do
        local units = SkillAPI.EnumUnitsRandom(
            self.owner, 
            {
                area_type = EnumUnitsAreaType.Circle,
                radius = 5,
            }, 
            nil, 1, true)

        for _, unit in pairs(units) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        end
        self.decay = self.decay * 0.9
    end
    
    --print("SkillTest:OnCastStart")
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = 1.1 * self.decay

    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal