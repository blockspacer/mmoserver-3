---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 增加血量
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffHp = ExtendClass(Buff)

function BuffHp:__ctor(scene, buff_id, data)
	self.hp_max = self:GetPara(1) / 10000
	self.work_independent = true
end

function BuffHp:OnTick(interval)
    Buff.OnTick(self, interval)
    
end

return BuffHp

