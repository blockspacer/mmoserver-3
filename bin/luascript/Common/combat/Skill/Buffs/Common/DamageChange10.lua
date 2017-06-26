---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 为目标附加印记
	

--[[
为目标附加印记
		

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

	if attacker.uid == self.source.uid then
		local percent = ( 1 + self:GetPara(1) / 10000) 
		return math.max(0, damage * percent )
	end

end



return DamageChange

