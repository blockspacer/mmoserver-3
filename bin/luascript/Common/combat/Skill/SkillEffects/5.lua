---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/23
-- desc： 每个阶段 动作细分 方案(带预警框)
---------------------------------------------------

require "Common/basic/functions"

local skill_type = '5'

local SkillEffect4 = require "Common/combat/Skill/SkillEffects/4"
local SkillEffectLocal = ExtendClass(SkillEffect4)

function SkillEffectLocal:__ctor(scene, skill_id, data)
    self.default_animation = 'skill'..skill_id..'_A1'
end

function SkillEffectLocal:OnCastStart(data)
    SkillEffect4.OnCastStart(self, data)
    self:CreateSkillRangeWarning()
end

function SkillEffectLocal:OnCastChannel(data)
    SkillEffect4.OnCastChannel(self, data)
    self:DestroySkillRange()
end

function SkillEffectLocal:OnCastFinish(data)
    SkillEffect4.OnCastFinish(self, data)
end

SkillEffectLib[skill_type] = SkillEffectLocal

return SkillEffectLocal