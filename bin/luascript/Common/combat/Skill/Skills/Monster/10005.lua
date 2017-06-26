---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 三尾狐 10005 技能
--[[
幽冥之罚   扇形范围伤害                                      
a   妖狐尾巴发亮，像呼吸一样来回收缩，开始吟唱蓄力。以妖狐为中心，后形成一个半径为10米的红圈。蓄力时间为3秒。                                      
b   然后尾部整个张开，红圈内出现强烈的蓝光。                                        
c   在红圈内的玩家，受到每秒120%的法术伤害，并且加上减速效果。                                     
d   技能冷却时间为15秒。                                     
f   技能释放条件:无                                        
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10005'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

-- skill开始施法
function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)
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