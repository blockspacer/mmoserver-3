---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/06
-- desc： 伤害：抵挡x次伤害  



--[[
接下来几次【参数1】的掉血强制为0.（即抵挡接下来几次伤害，任何掉血都算一次）
]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local DamageChange5 = ExtendClass(Buff)

function DamageChange5:__ctor(scene, buff_id, data)
    self.work_independent = true
end

function DamageChange5:OnAdd()
    Buff.OnAdd(self)
    self.cause_damage_change_time = self:GetPara(1)
end

function DamageChange5:OnTick(interval)
    Buff.OnTick( self , interval )
end

-- 接受伤害时统一使用这个函数
function DamageChange5:ChangeTakeDamage(damage, skill)

	if self.cause_damage_change_time > 0 then
		self.cause_damage_change_time = self.cause_damage_change_time - 1
    	return 0
    else
        self.owner.skillManager:RemoveBuff(self)
    	return damage
    end

end

function DamageChange5:OnCover(data)
    local res = Buff.OnCover(self, data)
    self.cause_damage_change_time = self:GetPara(1)
end

return DamageChange5

