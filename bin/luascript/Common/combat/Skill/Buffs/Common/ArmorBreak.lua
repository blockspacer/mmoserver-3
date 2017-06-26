---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 破甲
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffArmorBreak = ExtendClass(Buff)

function BuffArmorBreak:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- buff被添加到单位上时
function BuffArmorBreak:OnAdd()
    Buff.OnAdd( self )
    self.owner:AddStatus('ArmorBreak', self)
end

-- buff被删除的时候
function BuffArmorBreak:OnRemove()
    Buff.OnRemove( self )
    self.owner:RemoveStatus('ArmorBreak', self)
end

return BuffArmorBreak

