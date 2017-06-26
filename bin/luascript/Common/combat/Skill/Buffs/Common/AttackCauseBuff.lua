---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 修正普通攻击	

--[[
普通攻击时有【1】概率给目标附加【固定参数：buffID】。			

]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local AttackCauseBuff = ExtendClass(Buff)

function AttackCauseBuff:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- 造成伤害时统一使用这个函数
function AttackCauseBuff:ChangeCauseDamage(damage, skill, target)

	if skill.slot_id ~= SlotIndex.Slot_Attack then
		return damage
	end

	target.skillManager:AddBuff(tostring(self.buff_data.FixedPara[1]), 
		{
        source = self.owner, 
        level = self.level,
        })

    return damage * ( 1 + self:GetPara(1) / 10000) + self:GetPara(2) / 10000
end


return AttackCauseBuff

