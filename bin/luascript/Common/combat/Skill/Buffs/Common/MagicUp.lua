---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 法术提升
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffMagicUp = ExtendClass(Buff)

function BuffMagicUp:__ctor(scene, buff_id, data)
	self.magic_attackPercent = 1 + self:GetPara(1)/10000
	self.work_independent = true
end

function BuffMagicUp:OnTick(interval)
    Buff.OnTick(self, interval)
    
end

-- buff被添加到单位上时
function BuffMagicUp:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('MagicUp', self)
end

-- buff被删除的时候
function BuffMagicUp:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('MagicUp', self)
end

return BuffMagicUp

