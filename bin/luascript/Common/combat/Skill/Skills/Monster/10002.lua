---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 10002 技能
--[[
对目标造成【参数1百分比】 的最大血量伤害。移动完成后发生爆炸，
爆炸对范围目标造成【参数2百分比】 的最大血量伤害，
并对受到熔岩球伤害的目标附加（BUFFID为【buffid1】）的BUFF效果。
（半径5米，移动速度6m/s,。写在程序里，调试好一次就不用改了)                                                   
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10002'

local function CreateSkillLocal(skill_id, data)
    local config = GetConfig("growing_skill")
    local skill_data = config.Skill[tonumber(skill_id)]
    local self = CreateSkill(skill_id, data)
    local base = self.base();

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT

    local the_target = nil
    local timer = nil

    self.OnCastStart = function(data)
        base.OnCastStart(data)
        local target = data.target
        if target then
            the_target = target 
            self.owner:StartApproachTarget(target, 2, self.HitTarget)
            -- 5秒之内没移动到的话 就 自爆
            timer = self:GetTimer().Delay(5, self.Bang)
        end
    end

    -- 撞击
    self.HitTarget = function()
        SkillAPI.MinusHp(the_target, the_target.hp_max() * self:GetPara(1) / 10000)
        self.Bang()
    end

    -- 自爆
    self.Bang = function()
        -- 如果是由 撞击触发的 自爆 那就要把之前的定时器取消掉
        if timer then
            self:GetTimer().Remove(timer)
            timer = nil
        end
        local units = SkillAPI.EnumUnitsRandom(
            self.owner, 
            {
                area_type = EnumUnitsAreaType.Circle,
                radius = self.area_radius,
            }, 
            nil, 100000, true)

        for _, unit in pairs(units) do
            SkillAPI.MinusHp(unit, unit.hp_max() * self:GetPara(2) / 10000)
            unit.skillManager:AddBuffFromSkill(tostring(skill_data.Buff1), self)
        end
        self:GetEntityManager().DestroyPuppet(self.owner.uid)
    end
    
    return self
end

SkillLib[skill_type] = CreateSkillLocal