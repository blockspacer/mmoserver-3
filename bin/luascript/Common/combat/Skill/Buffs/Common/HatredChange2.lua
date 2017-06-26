---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/06
-- desc： 仇恨提高
	
	
-- 自身对目标造成的仇恨提高比例【参数1】	
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local HatredChange2 = ExtendClass(Buff)

function HatredChange2:__ctor(scene, buff_id, data)

end

-- buff被添加到单位上时
function HatredChange2:OnAdd()
    Buff.OnAdd( self )
    local tmp = self.owner:GetEntityHatredValue(self.data.source.uid)
    self.owner:LampoonStart(self.data.source.uid, tmp * (1 + self:GetPara(1) / 10000) )
end

-- buff被删除的时候
function HatredChange2:OnRemove()
    Buff.OnRemove( self )
end

return HatredChange2
