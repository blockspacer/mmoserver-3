---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/6/15
-- desc： 341 技能
--[[
向指定方向释放陷阱，对沿途敌人造成【1万分比】法术伤害以及【2万分制】额外伤害，
陷阱会向前方移动【3】米，共耗时【4】秒                                                  
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/basic/Timer"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '341'

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

    local pos = self.owner:GetPosition()
    local speed = self:GetPara(3) / self:GetPara(4) * 100
    local summon = self:GetEntityManager().CreateEffectOnServer(
        pos.x, pos.y, pos.z, "BossChiyou/eff_boss@chiyou_skill01_bullet", speed)

    local dest = MathHelper.GetForward(self.owner, self:GetPara(3))

    local function OnHit()
        self:GetEntityManager().DestroyPuppet(summon.uid)
    end
    summon:StartApproachPosition(dest, 1, OnHit)

    local victim = {}

    local function rangeAttack()
        if summon == nil then 
            return 
        end
        local enemys = SkillAPI.EnumUnitsInCircle(
            self.owner,
            summon:GetPosition(), 
            {
                area_type = EnumUnitsAreaType.Circle,
                radius = 4,
            }, 
            nil, true)

        for _, unit in pairs(enemys) do
            if victim[unit.uid] == nil then
                SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
                victim[unit.uid] = 1
            end
        end

    end

    self:GetTimer().Numberal(1, self:GetPara(4), rangeAttack)

end


function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent  + self:GetPara(2) / 10000
end


SkillLib[skill_type] = SkillLocal

return SkillLocal