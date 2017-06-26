---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 火防御提升
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffFireDefenceUp = ExtendClass(Buff)

function BuffFireDefenceUp:__ctor(scene, buff_id, data)
	self.work_independent = true
	self.fire_defence = self:GetPara(1) / 10000
end


function BuffFireDefenceUp:OnTick(interval)
    Buff.OnTick(self, interval)
    
end

-- buff被添加到单位上时
function BuffFireDefenceUp:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('FireDefenceUp', self)
end

-- buff被删除的时候
function BuffFireDefenceUp:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('FireDefenceUp', self)
end

return BuffFireDefenceUp

