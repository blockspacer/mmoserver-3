---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 给目标增加一个能吸收伤害相当于释放者【参数1百分比】血量的护盾
-- 护盾：按施法者计算（破碎后，对周围所有敌人造成等量伤害）	

---------------------------------------------------
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME
require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"
local BuffShield = require "Common/combat/Skill/Buffs/Common/Shield"

local BuffShield4 = ExtendClass(BuffShield)


function BuffShield4:__ctor(scene, buff_id, data)

end


function BuffShield4:rechargeShield(data)
	if not GRunOnClient then
		self.shield_energy = data.source[attrib_id_to_name[self.buff_data.FixedPara[1]]]() * self:GetPara(1) / 10000
    	self.shield = self.shield_energy
    end
end

-- buff被删除的时候
function BuffShield4:OnRemove()
    BuffShield.OnRemove(self)
    if self.shield_energy then
    	local tmp = self.shield_energy - self.shield
    	local units = SkillAPI.EnumUnitsInCircle(
	        self.owner,
	        self.owner:GetPosition(), 
	        {
	            area_type = EnumUnitsAreaType.Circle,
	            radius = self:GetPara(2),
	        }, 
	        nil, true)

    	for _, unit in pairs(units) do
        	 SkillAPI.MinusHp(unit, tmp, self.owner)
    	end
    end 
end

return BuffShield4
