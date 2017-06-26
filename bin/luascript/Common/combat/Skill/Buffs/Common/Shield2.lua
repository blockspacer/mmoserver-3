---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 给目标增加一个能吸收伤害相当于释放者【参数1百分比】血量的护盾
---------------------------------------------------
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME
require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"
local BuffShield = require "Common/combat/Skill/Buffs/Common/Shield"

local BuffShield2 = ExtendClass(BuffShield)


function BuffShield2:__ctor(scene, buff_id, data)

end


function BuffShield2:rechargeShield(data)
	if not GRunOnClient then
    	self.shield = data.source[attrib_id_to_name[self.buff_data.FixedPara[1]]]() * self:GetPara(1) / 10000
    end
end

return BuffShield2
