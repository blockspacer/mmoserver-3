---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 伤害：输出伤害提高x次	

--[[
接下来几次【参数1】输出伤害，提高【参数2】	
]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local DamageChange2 = ExtendClass(Buff)

function DamageChange2:__ctor(scene, buff_id, data)
	self.work_independent = true
end

function DamageChange2:OnAdd()
    Buff.OnAdd(self)
    self.cause_damage_change_time = self:GetPara(1)
end

-- 造成伤害时统一使用这个函数
function DamageChange2:ChangeCauseDamage(damage, skill, target)

	if self.cause_damage_change_time > 0 then
		self.cause_damage_change_time = self.cause_damage_change_time - 1
    	return damage * ( 1 + self:GetPara(2) / 10000)
    else
    	self.owner.skillManager:RemoveBuff(self)
    	return damage
    end
end

function DamageChange2:OnCover(data)
    local res = Buff.OnCover(self, data)
    self.cause_damage_change_time = self:GetPara(1)
end


return DamageChange2

