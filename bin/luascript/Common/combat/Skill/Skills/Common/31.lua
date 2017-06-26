---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 31
--[[
被动技能-光环                          
                                                             
]]
---------------------------------------------------
local skill_type = '31'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
    -- 是否是被动技能
    self.passive_skill = true
end

-- skill被添加到单位上时
function SkillLocal:OnAdd()
    Skill.OnAdd(self)

    if not GRunOnClient then
        local function rangeAttack()
            local enemy_flag, ally_flag
            if self:GetPara(1) == 1 then
                enemy_flag = true
            else
                ally_flag = true
            end

            local enemys = SkillAPI.EnumUnitsInCircle(
                self.owner, 
                self.owner:GetPosition(),
                self:GetRangeParams(), 
                nil, enemy_flag, ally_flag)

            for _, unit in pairs(enemys) do
                if self.skill_data.Buff1 ~= 0 then
                    unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
                end
            end

        end

        if self.repeat_time then
            self:StopRangeAttack()
        end

        self.repeat_time = self:GetTimer().Repeat(1, rangeAttack)     
    end
end

function SkillLocal:StopRangeAttack()
    if self.repeat_time then
        self:GetTimer().Remove(self.repeat_time)
        self.repeat_time = nil
    end
end

function SkillLocal:OnRemove()
    Skill.OnRemove(self)
    self:StopRangeAttack()
end

SkillLib[skill_type] = SkillLocal

return SkillLocal