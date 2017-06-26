---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 反击	

--[[
受到攻击时，会反击【1】的伤害给对方。			
 
]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local CounterAttack = ExtendClass(Buff)

function CounterAttack:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- 接受伤害时统一使用这个函数
function CounterAttack:ChangeTakeDamage(damage, skill, attacker)
	SkillAPI.MinusHp(attacker, damage * self:GetPara(1) / 10000, self.owner)

	return damage
end


return CounterAttack

