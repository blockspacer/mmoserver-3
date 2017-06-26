---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/7
-- desc： 
--[[
给主人附加一个【buffID1】的buff（能吸收宠物血量的20%的护盾，持续5s。）
如果圣盾消失，则对周围随机一个目标造成吸收的同等伤害。

]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '10081'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE

end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    if self.owner.owner and self.skill_data.Buff1 and self.skill_data.Buff1 ~= 0 then
        self.owner.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end

    if self.skill_data.Buff2 and self.skill_data.Buff2 ~= 0 then
        self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
    end

end

SkillLib[skill_type] = SkillLocal

return SkillLocal