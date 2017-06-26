---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 10003 技能
--[[
天崩地裂    全场输出    场景内会形成防护罩给玩家提供躲避                            
a   蚩尤举起法杖蓄力，整个场景开始震动（屏幕抖动）。蓄力时间为3秒。                                
b   大量的熔岩石从天而降，坠击地面，对全场景的玩家造成每秒200%物理伤害。（防护罩内可躲避）                               
c   持续5秒。                               
d   技能冷却时间为25s。                             
f   技能释放条件:蚩尤血量低于50%                                                      
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10003'

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

    self:GetTimer().Numberal(1, self:GetPara(3) / 1000, rangeAttack)        
end

function SkillLocal:IsFillCondition()
    return self.owner.hp < self.owner.hp_max() * self:GetPara(1) / 10000
end


function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(2) / 10000

    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal