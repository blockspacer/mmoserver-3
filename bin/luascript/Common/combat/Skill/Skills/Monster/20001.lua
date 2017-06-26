--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/22 0022
-- Time: 15:29
-- To change this template use File | Settings | File Templates.
--
--[[
干戚乱舞	圆形伤害
1	原地持续挥舞着自己的武器和盾牌，在自己周围形成一阵旋风。对周围目标造成 大量/秒的伤害。持续6s。
2	攻击区域：以自己为中心，半径3米的圆形区域。
3	受到攻击的角色，受到2000点/秒的伤害
4	蓄力0.5秒，技能冷却时间40秒。
5	不可被打断
]]

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '20001'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

-- skill施法中
function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    local function rangeAttack()
        local units = SkillAPI.EnumUnitsRandom(
            self.owner, 
            {
                area_type = EnumUnitsAreaType.Circle,
                radius = self.area_radius,
            }, 
            nil, 1000, true)

        for _, unit in pairs(units) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        end
    end

    self:GetTimer().Numberal(1, self:GetPara(2), rangeAttack)      
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal