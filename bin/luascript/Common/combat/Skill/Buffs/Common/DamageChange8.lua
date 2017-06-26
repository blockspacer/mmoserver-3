---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 伤害：受到伤害修改	

--[[
受到的物理伤害提高【1】，受到的法术伤害提高【2】			

]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local DamageChange = ExtendClass(Buff)

function DamageChange:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- 接受伤害时统一使用这个函数
function DamageChange:ChangeTakeDamage(damage, skill, attacker)

	if skill.damage_mode == AttackMode.Physic then
		local percent = ( 1 + self:GetPara(1) / 10000) 
		return math.max(0, damage * percent )
	else
		local percent = ( 1 + self:GetPara(2) / 10000) 
		return math.max(0, damage * percent )
	end
end



return DamageChange

