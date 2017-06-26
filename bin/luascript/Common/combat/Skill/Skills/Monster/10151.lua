---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： 10151 技能
--[[
用尾巴将目标击飞，每击飞1米，造成【3 万分比】物理伤害。
最小【1数值】米，最大击飞【2数值】米。击飞距离与目标物攻差有关。
相差越大，击飞距离越远。击飞距离=max（【2】，（宠物物攻-目标物攻）/宠物物攻*【1】米）。
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '10151'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)
    local target = data.target

    if target then
        local tmp = (self.owner.physic_attack() - target.physic_attack()) / self.owner.physic_attack()
        self.move_distance = math.max(self:GetPara(1), self:GetPara(2) * tmp)
        SkillAPI.MoveBackwardTo(target, self.owner, self.move_distance, 0.3)
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)

    end

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(3) / 10000 * self.move_distance
    return M4 * percent
end

SkillLib[skill_type] = SkillLocal

return SkillLocal