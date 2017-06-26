---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： SkillEffect Test
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillEffect"

local skill_name = 'Test'

function CreateSkillEffectTest(data)
	local self = CreateSkillEffect(skill_name, data)
    local base = self.base();

    self.OnCastStart = function(data)
        base.OnCastStart(data)
        self.owner:OnCastSkill(0)
        print("SkillEffectTest:OnCastStart", self.skill.skill_stage)
    end

    self.OnCastChannel = function(data)
        base.OnCastChannel(data)
        --print("SkillEffectTest:OnCastChannel")
    end

    self.OnCastFinish = function(data)
        base.OnCastFinish(data)
        --print("SkillEffectTest:OnCastFinish")
    end
	return self
end

SkillEffectLib[skill_name] = CreateSkillEffectTest