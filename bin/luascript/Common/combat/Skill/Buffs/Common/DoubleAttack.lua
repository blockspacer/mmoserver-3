---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 连击	

--[[
普通攻击时有【1】概率造成【固定参数】连击。普攻伤害会减少【2】。			

]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local DoubleAttack = ExtendClass(Buff)

function DoubleAttack:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- 接受伤害时统一使用这个函数
function DoubleAttack:ChangeCauseDamage(damage, skill, target)

	if skill.slot_id ~= SlotIndex.Slot_Attack then
		return damage
	end

	local function Happen()
		local count = self.buff_data.FixedPara[1]
		for i = 1, count do
			SkillAPI.MinusHp(target, damage * self:GetPara(2) / 10000, self.owner)
		end
    end

    SkillAPI.RandEvent(self:GetPara(1)/10000, Happen)
    return damage

end


return DoubleAttack

