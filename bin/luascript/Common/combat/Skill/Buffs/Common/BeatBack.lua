---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/27
-- desc： 击退
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffBeatBack = ExtendClass(Buff)

function BuffBeatBack:__ctor(scene, buff_id, data)

end

-- buff被添加到单位上时
function BuffBeatBack:OnAdd()
    Buff.OnAdd(self)
    --self.owner:LookAt(self.data.source:GetPosition())
    --self.owner:SetAnimationSpeed('', 0)
    if not GRunOnClient then
    	SkillAPI.MoveBackwardTo(self.owner, self.data.source, self:GetPara(1), self.last_time)
    end

    self.owner:AddStatus('BeatBack', self)
end

-- buff被删除的时候
function BuffBeatBack:OnRemove()
    Buff.OnRemove(self)
    --self.owner:SetAnimationSpeed('', 1)
    self.owner:RemoveStatus('BeatBack', self)
end


return BuffBeatBack
