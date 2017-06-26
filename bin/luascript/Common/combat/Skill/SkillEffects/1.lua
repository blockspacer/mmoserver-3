---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/23
-- desc： SkillEffect Test
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillEffect"

local skill_type = '1'

local SkillEffect = require "Common/combat/Skill/SkillEffect"
local SkillEffectLocal = ExtendClass(SkillEffect)

function SkillEffectLocal:__ctor(scene, skill_id, data)
	self.default_animation = 'attack'
end

-- 在开始阶段播放动作
function SkillEffectLocal:OnCastStart(data)
    SkillEffect.OnCastStart(self, data)
    self.owner:OnCastSkill('attack')
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


-- 施法阶段发出弹道
function SkillEffectLocal:OnCastChannel(data)
	SkillEffect.OnCastChannel(self, data)
end

SkillEffectLib[skill_type] = SkillEffectLocal

return SkillEffectLocal