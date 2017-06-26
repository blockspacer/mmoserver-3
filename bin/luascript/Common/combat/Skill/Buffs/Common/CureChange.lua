---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 治疗效果改变	

--[[
自身受到的治疗（所有加血）效果提高/降低百分比	
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
function DamageChange:ChangeAddHp(hp)

    return hp * ( 1 + self:GetPara(1) / 10000) 
end


return DamageChange

