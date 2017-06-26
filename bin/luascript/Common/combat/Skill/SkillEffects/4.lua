---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/23
-- desc： 每个阶段 动作细分 方案
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/SkillEffect"

local skill_type = '4'

local SkillEffect = require "Common/combat/Skill/SkillEffect"
local SkillEffectLocal = ExtendClass(SkillEffect)

function SkillEffectLocal:__ctor(scene, skill_id, data)
    self.default_animation = 'skill'..skill_id..'_A1'
end

function SkillEffectLocal:PlayIt(cur_alpha, stage)
	if self.skill_animation_timer then
		self:GetTimer().Remove(self.skill_animation_timer)
   		self.skill_animation_timer = nil
	end

    if self.owner:IsDied() or self.owner:IsDestroy() then
        return 
    end
    
    local cur_animation = 'skill'..self.skill_id..'_'..cur_alpha..tostring(stage)
    if self.owner.behavior:HasAnimation(cur_animation) then
    	--print('SkillEffectLocal:PlayIt', cur_animation)
    	self.owner:OnCastSkill(cur_animation)
    	local last_time = self.owner.behavior:GetAnimationLength(cur_animation)
    	self.skill_animation_timer = self:GetTimer().Delay(last_time, self.PlayIt, self, cur_alpha, stage + 1)
    end
end

function SkillEffectLocal:ChangeDataAnimation(stage)
    self.default_animation = 'skill'..self.skill_id..'_'..stage
end

function SkillEffectLocal:BreakSkill()
    SkillEffect.BreakSkill(self)
    self:GetTimer().Remove(self.skill_animation_timer)
    self.skill_animation_timer = nil
end

function SkillEffectLocal:OnCastStart(data)
    SkillEffect.OnCastStart(self, data)
    self:ChangeDataAnimation('A1')
    self:PlayIt('A', 1)
    if self.skill.Bullet ~= 0 then
        if self.skill.bullet_hit_master then
            self:FireBullet(self.owner.owner)
        elseif self.skill.bullet_hit_location  and data.target then
            self:FireBullet(nil, data.target:GetPosition())
        else 
            self:FireBullet(data.target)
        end
    end
end

function SkillEffectLocal:OnCastChannel(data)
    SkillEffect.OnCastChannel(self, data)
    self:ChangeDataAnimation('B1')
    self:PlayIt('B', 1)
    if self.skill.Bullet ~= 0 then
        if self.skill.bullet_hit_master then
            self:FireBullet(self.owner.owner)
        elseif self.skill.bullet_hit_location  and data.target then
            self:FireBullet(nil, data.target:GetPosition())
        else 
            self:FireBullet(data.target)
        end
    end
end

function SkillEffectLocal:OnCastFinish(data)
    SkillEffect.OnCastFinish(self, data)
    self:ChangeDataAnimation('C1')
    self:PlayIt('C', 1)
    if self.skill.Bullet ~= 0 then
        if self.skill.bullet_hit_master then
            self:FireBullet(self.owner.owner)
        elseif self.skill.bullet_hit_location then
            self:FireBullet(nil, data.target:GetPosition())
        else 
            self:FireBullet(data.target)
        end
    end
end

SkillEffectLib[skill_type] = SkillEffectLocal

return SkillEffectLocal