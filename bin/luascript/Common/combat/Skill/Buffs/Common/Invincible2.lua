---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/06
-- desc： 无敌：限制	
-- 任何掉血都强制为0，若自身或自身宠物对任何目标造成一次伤害则此buff消失	
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local Invincible2 = ExtendClass(Buff)

function Invincible2:__ctor(scene, buff_id, data)
	self.invincible_able = true
	self.work_independent = true
end

function Invincible2:ChangeTakeDamage(damage)
	if self.invincible_able then
    	return 0
    else
    	return damage
    end
end

function Invincible2:OnCauseDamage(damage, victim, skill_id, event_type)
	
	self.invincible_able = false
    
end

return Invincible2
