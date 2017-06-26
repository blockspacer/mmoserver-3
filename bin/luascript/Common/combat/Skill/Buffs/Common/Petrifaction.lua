---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 石化
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffPetrifaction = ExtendClass(Buff)

function BuffPetrifaction:__ctor(scene, buff_id, data)
    self.work_independent = true
end

function BuffPetrifaction:OnTick(interval)
    Buff.OnTick(self, interval)
    -- TODO 修改 伤害降低属性
end

-- buff被添加到单位上时
function BuffPetrifaction:OnAdd()
    Buff.OnAdd(self)
    self.owner:CastEffect("FossilisedEffect")
    self.owner:SetAnimationSpeed('', 0)
    self.owner:AddStatus('Petrifaction', self)
end

-- buff被删除的时候
function BuffPetrifaction:OnRemove()
    Buff.OnRemove(self)
    self.owner:SetAnimationSpeed('', 1)
    self.owner:RevertEffect()
    self.owner:RemoveStatus('Petrifaction', self)
end

return BuffPetrifaction

