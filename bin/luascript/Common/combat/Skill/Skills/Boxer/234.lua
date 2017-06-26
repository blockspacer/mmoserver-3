---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/08
-- desc： Skill Test
--[[
【气劲】嘲讽自身周围5米范围内的所有敌人，
同时凝聚真气，形成一道护盾围绕自身，护盾值为100%的物理攻击力
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillConst"

local skill_type = '234'

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
    -- TODO 嘲讽,没有嘲讽 机制，目前还无法做

    -- 产生护盾
    self.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
end

SkillLib[skill_type] = SkillLocal

return SkillLocal