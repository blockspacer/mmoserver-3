---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 主动技能-光环


--[[

释放后，对范围内【参数1（1：敌方；2：友方）】，每【参数2：ms】时间附加【buffID1】。光环持续【参数3：ms】
                                                    
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '32'

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
        local enemy_flag 
        local ally_flag
        if self:GetPara(1) == 1 then
            enemy_flag = true
        else
            ally_flag = true
        end

        local units = SkillAPI.EnumUnitsRandom(
            self.owner, 
            self:GetRangeParams(), 
            nil, 10000, enemy_flag, ally_flag)

        for _, unit in pairs(units) do
            if self.skill_data.Buff1 ~= 0 then
                unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
            end
        end
        if ally_flag then
            if self.skill_data.Buff1 ~= 0 then
                self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
            end
        end

    end
    if self.skill_data.Buff2 ~= 0 then
        self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
    end
    self:GetTimer().Numberal(self:GetPara(2) / 1000, self:GetPara(3) / self:GetPara(2), rangeAttack)        
end

SkillLib[skill_type] = SkillLocal

return SkillLocal