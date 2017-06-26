---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/06
-- desc： 被嘲讽	
	
-- 指定攻击释放嘲讽的目标，不管当前仇恨是多少	
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local HatredChange = ExtendClass(Buff)

function HatredChange:__ctor(scene, buff_id, data)

end

-- buff被添加到单位上时
function HatredChange:OnAdd()
    Buff.OnAdd( self )
    self.owner:LampoonStart(self.data.source.uid, self:GetPara(1))
    if self.data.source and self.owner.entityType == EntityType.Hero then
    	TargetManager.SetTarget(self.data.source)
    end
end

-- buff被删除的时候
function HatredChange:OnRemove()
    Buff.OnRemove( self )
    self.owner:LampoonOver(self.data.source.uid)
end

return HatredChange
