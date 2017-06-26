---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/23
-- desc： SkillEffect Test
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillEffect"

local skill_type = '2'

local SkillEffect = require "Common/combat/Skill/SkillEffect"
local SkillEffectLocal = ExtendClass(SkillEffect)

function SkillEffectLocal:__ctor(scene, skill_id, data)
	self.default_animation = 'skill'..skill_id
end

function SkillEffectLocal:OnCastStart(data)
    SkillEffect.OnCastStart(self, data)
    self.owner:OnCastSkill('skill'..self.skill_id)
   	if self.skill.Bullet ~= 0 then
    	if self.skill.bullet_hit_master then
    		self:FireBullet(self.owner.owner)
        elseif self.skill.bullet_hit_location and data.target then
            self:FireBullet(nil, data.target:GetPosition())
    	else 
    		self:FireBullet(data.target)
    	end
    end
end

SkillEffectLib[skill_type] = SkillEffectLocal

return SkillEffectLocal