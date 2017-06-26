---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 魅惑
---------------------------------------------------

local CreateCharmState = require "Common/combat/State/Skill/CharmState"
require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffCharm = ExtendClass(Buff)

function BuffCharm:__ctor(scene, buff_id, data)
	self.work_independent = true
end

 -- buff被添加到单位上时
function BuffCharm:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('Charm', self)

	self.owner.stateManager:GotoState(StateType.eCharm)
end

-- buff被删除的时候
function BuffCharm:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('Charm', self)

    self.owner.stateManager:Rollback()
end

return BuffCharm
