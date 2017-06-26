--
-- Created by IntelliJ IDEA.
-- User: 吴培峰
-- Date: 2016/12/26 0022
-- Time: 15:29
-- To change this template use File | Settings | File Templates.
--
--[[
魔神鞭挞    扇形伤害                    
1   用尾巴攻击身前扇形区域内的玩家角色。                  
2   攻击区域为，半径4米，角度为120度的扇形区域。                    
3   受到攻击的角色，受到200%的物理伤害，并且进入眩晕状态。                   
4   眩晕状态持续3秒。                   
5   蓄力3秒，技能冷却时间15秒。                 
          

]]

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '20004'

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
        {
            area_type = EnumUnitsAreaType.Sector,
            angle = self.area_angle,
            radius = self.area_radius,
        }, 
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