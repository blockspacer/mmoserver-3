---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 伤害：输出伤害改变
--[[
自身输出伤害增加比例【参数1】，并再额外附加数值【参数2】伤害 
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

-- 造成伤害时统一使用这个函数
function DamageChange:ChangeCauseDamage(damage, skill, target)

    return damage * ( 1 + self:GetPara(1) / 10000) + self:GetPara(2) / 10000
end


return DamageChange

