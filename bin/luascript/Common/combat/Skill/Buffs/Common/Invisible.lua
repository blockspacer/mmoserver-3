---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 隐身
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffInvisible = ExtendClass(Buff)

function BuffInvisible:__ctor(scene, buff_id, data)
    self.work_independent = true
end

function BuffInvisible:OnTick(interval)
    Buff.OnTick(self, interval)
end

-- buff被添加到单位上时
function BuffInvisible:OnAdd()
    Buff.OnAdd(self)
    self.owner.is_stealthy = true
end

-- buff被删除的时候
function BuffInvisible:OnRemove()
    Buff.OnRemove(self)
    self.owner.is_stealthy = false
end

return BuffInvisible

