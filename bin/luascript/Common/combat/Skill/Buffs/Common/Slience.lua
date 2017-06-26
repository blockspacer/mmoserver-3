---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： BuffTest
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffSlience = ExtendClass(Buff)

function BuffSlience:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- buff被添加到单位上时
function BuffSlience:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Slience', self)
end

-- buff被删除的时候
function BuffSlience:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Slience', self)
end

return BuffSlience

