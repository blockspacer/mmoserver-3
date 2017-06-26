---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 血量无法被降低至【参数1万分比】
	

--[[
血量无法被降低至【参数1万分比】
			

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

	local tmp = math.max(self.owner.hp - self.owner.hp_max() * self:GetPara(1) / 10000, 0)
	damage = math.min(damage, tmp)

	return damage

end



return DamageChange

