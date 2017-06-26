--
-- Created by IntelliJ IDEA.
-- User: 吴培峰
-- Date: 2016/12/26 0022
-- Time: 15:29
-- To change this template use File | Settings | File Templates.
--
--[[
力劈山河    范围控制                
1   刑天举起巨斧蓄力1s，向正前方劈去。              
2   攻击范围：前方3*4的矩形范围             
3   区域角色，受到200%的物理伤害。并造成2s眩晕                
4   技能冷却时间10秒。              

]]

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '20002'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

-- skill施法中
function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    local units = SkillAPI.EnumUnitsRandom(
        self.owner, 
        self:GetRangeParams(), 
        nil, 100000, true)

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