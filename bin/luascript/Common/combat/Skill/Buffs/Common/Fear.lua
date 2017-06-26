---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 恐惧

-- 每隔1秒，向一个随机方向移动（1秒后，执行新的移动命令）。并且防御力降低【参数1百分比】。
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local CreateFearState = require "Common/combat/State/Skill/FearState"
local Buff = require "Common/combat/Skill/Buff"

local BuffFear = ExtendClass(Buff)

function BuffFear:__ctor(scene, buff_id, data)
	self.work_independent = true
    self.magic_defencePercent = 1 - self:GetPara(1) / 10000
	self.physic_defencePercent = 1 - self:GetPara(1) / 10000
end

-- buff被添加到单位上时
function BuffFear:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Fear', self)

	self.owner.stateManager:GotoState(StateType.eFear)
end

-- buff被删除的时候
function BuffFear:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Fear', self)
    
    self.owner.stateManager:Rollback()
    
end

function BuffFear:OnTick(interval)
    Buff.OnTick(self, interval)


end


return BuffFear

