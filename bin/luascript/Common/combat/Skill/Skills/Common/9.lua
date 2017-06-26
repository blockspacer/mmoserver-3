---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 己方buff+治疗

-- 有【3】概率给自己附加【buff 1】和【buff 2】，并治疗自己【1】*【2】的血量。                                        

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME

local skill_type = '9'

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

    local function MakeBuff(target)
        if self.skill_data.Buff1 ~= 0 then
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        end
        if self.skill_data.Buff2 ~= 0 then
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
        end
    end
    SkillAPI.RandEvent(self:GetPara(3)/10000, MakeBuff1, self.owner)

    SkillAPI.AddHp(self.owner, self.owner[attrib_id_to_name[self:GetPara(1)]]() * self:GetPara(2) / 10000, self.owner, self.skill_id)
end

SkillLib[skill_type] = SkillLocal

return SkillLocal