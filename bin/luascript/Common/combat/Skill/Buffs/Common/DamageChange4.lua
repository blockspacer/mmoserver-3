---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/06
-- desc： 伤害：受到伤害减少x次	


--[[
接下来受到的几次【参数1】伤害，降低【参数2】	
]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local DamageChange4 = ExtendClass(Buff)

function DamageChange4:__ctor(scene, buff_id, data)
    self.work_independent = true
end

function DamageChange4:OnAdd()
    Buff.OnAdd(self)
    self.cause_damage_change_time = self:GetPara(1)
end

function DamageChange4:OnTick(interval)
    Buff.OnTick( self , interval )
end

-- 接受伤害时统一使用这个函数
function DamageChange4:ChangeTakeDamage(damage, skill)

	if self.cause_damage_change_time > 0 then
		self.cause_damage_change_time = self.cause_damage_change_time - 1
    	return math.max(0, damage * ( 1 + self:GetPara(2) / 10000))
    else
        self.owner.skillManager:RemoveBuff(self)
    	return damage
    end

end

function DamageChange4:OnCover(data)
    local res = Buff.OnCover(self, data)
    self.cause_damage_change_time = self:GetPara(1)
end

return DamageChange4

