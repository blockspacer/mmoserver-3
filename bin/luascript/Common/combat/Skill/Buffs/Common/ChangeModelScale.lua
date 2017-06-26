---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 巨大化
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffChangeModelScale = ExtendClass(Buff)

function BuffChangeModelScale:__ctor(scene, buff_id, data)
    self.work_independent = true
end

function BuffChangeModelScale:OnTick(interval)
    Buff.OnTick(self, interval)
end

-- buff被添加到单位上时
function BuffChangeModelScale:OnAdd()
    Buff.OnAdd(self)
    self.owner.disguise_model_scale = self:GetPara(1) / 100
end

-- buff被删除的时候
function BuffChangeModelScale:OnRemove()
    Buff.OnRemove(self)
    self.owner.disguise_model_scale = 100
end

return BuffChangeModelScale

