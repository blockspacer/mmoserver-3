---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 降低防御

---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffLowerDefense = ExtendClass(Buff)

function BuffLowerDefense:__ctor(scene, buff_id, data)
    self.physic_defencePercent = 1 - self:GetPara(1) / 10000
    self.magic_defencePercent = 1 - self:GetPara(1) / 10000
    self.work_independent = true
end


function BuffLowerDefense:OnTick(interval)
    Buff.OnTick(self, interval)

end

-- buff被添加到单位上时
function BuffLowerDefense:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('LowerDefense', self)
end

-- buff被删除的时候
function BuffLowerDefense:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('LowerDefense', self)
end

return BuffLowerDefense

