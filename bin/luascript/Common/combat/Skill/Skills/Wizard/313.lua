---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/14
-- desc： 313技能
-- 有【参数3百分比】概率给自己附加【buff ID1】（提高自身的伤害15%），
-- 同时治疗自身，恢复【参数1 属性ID】*【参数2百分比】法术攻击的血量（CD 30s）
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME

local skill_type = '313'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_ALLY
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    local function Happen()
        self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end
    SkillAPI.RandEvent(self:GetPara(3) / 10000, Happen)

    local target = data.target

    if target then
        SkillAPI.AddHp(target, self.owner[attrib_id_to_name[self:GetPara(1)]]() * self:GetPara(2) / 10000, self.owner, self.skill_id)
    end
    
end

SkillLib[skill_type] = SkillLocal

return SkillLocal