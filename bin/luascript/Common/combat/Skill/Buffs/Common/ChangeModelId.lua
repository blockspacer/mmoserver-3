---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 易容丹
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffChangeModelId = ExtendClass(Buff)

function BuffChangeModelId:__ctor(scene, buff_id, data)
    self.work_independent = true
end

function BuffChangeModelId:OnTick(interval)
    Buff.OnTick(self, interval)
end

-- buff被添加到单位上时
function BuffChangeModelId:OnAdd()
    Buff.OnAdd(self)
    self.owner.disguise_model_id = self.buff_data.FixedPara[1] or 0
end

-- buff被删除的时候
function BuffChangeModelId:OnRemove()
    Buff.OnRemove(self)
    self.owner.disguise_model_id = 0
end

return BuffChangeModelId

