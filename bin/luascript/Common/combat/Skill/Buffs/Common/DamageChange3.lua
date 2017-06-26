---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/06
-- desc： 伤害：受到伤害减少  

--[[
自身受到伤害减速比例【参数1】，并再额外降低【参数2】伤害  
]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local DamageChange3 = ExtendClass(Buff)

function DamageChange3:__ctor(scene, buff_id, data)
	self.work_independent = true
end

function DamageChange3:OnTick(interval)
    Buff.OnTick( self , interval )
end

-- 接受伤害时统一使用这个函数
function DamageChange3:ChangeTakeDamage(damage, skill)

	local percent = ( 1 + self:GetPara(1) / 10000) 
	local bonus = self:GetPara(2)/10000

    return math.max(0, damage * percent + bonus )
end

return DamageChange3

