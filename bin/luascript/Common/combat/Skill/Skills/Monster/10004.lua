---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 10004 技能
--[[
炎锤怒击    控制技能                        
a   蚩尤举起巨锤蓄力，然后怒击身前地面。蓄力动作持续3秒。                     
b   以炎锤击中点为中心，对周围50米的敌人造成伤害，每人受到200%的物理伤害。                      
c   受到伤害的玩家同时附加眩晕效果，持续3秒。                       
d   技能冷却时间为15s。                     
f   技能释放条件:无                        
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10004'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

-- skill施法中
function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)
    local units = SkillAPI.EnumUnitsInCircle(
        self.owner,
        MathHelper.GetForward(self.owner, self:GetPara(2)), 
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self.area_radius,
        }, 
        nil, true)

    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal