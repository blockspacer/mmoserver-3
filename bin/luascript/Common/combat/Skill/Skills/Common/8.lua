---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： 己方buff+群体buff

--[[
使周围最多【3】个目标。有【1】概率给自己附加【buff 1】，【2】的概率给敌方附加【buff 2】，并造成【4】的伤害                                    
										
]]

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '8'

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

    local function MakeBuff1(target)
        if self.skill_data.Buff1 ~= 0 then
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        end
    end

    local function MakeBuff2(target)
        if self.skill_data.Buff2 ~= 0 then
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
        end
    end

    SkillAPI.RandEvent(self:GetPara(1)/10000, MakeBuff1, self.owner)

    local units = SkillAPI.EnumUnitsRandom(
        self.owner, 
        self:GetRangeParams(), 
        nil, self:GetPara(3), true)

    for _, unit in pairs(units) do
        SkillAPI.RandEvent(self:GetPara(2)/10000, MakeBuff2, unit)
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(4) / 10000

    return M4 * percent
end

SkillLib[skill_type] = SkillLocal

return SkillLocal