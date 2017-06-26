---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/27
-- desc： 拉过来
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffPullOver = ExtendClass(Buff)

function BuffPullOver:__ctor(scene, buff_id, data)

end

-- buff被添加到单位上时
function BuffPullOver:OnAdd()
    Buff.OnAdd(self)
    --self.owner:LookAt(self.data.source:GetPosition())
    --self.owner:SetAnimationSpeed('', 0)
    if not GRunOnClient then
    	--SkillAPI.MoveToward(self.owner, self.data.source, self.last_time)
        local target_pos = MathHelper.GetForward(self.data.source, 2)
        SkillAPI.MoveToPostion(self.owner, target_pos, 0.3)
    end

    self.owner:AddStatus('PullOver', self)
end

-- buff被删除的时候
function BuffPullOver:OnRemove()
    Buff.OnRemove(self)
    --self.owner:SetAnimationSpeed('', 1)
    self.owner:RemoveStatus('PullOver', self)
end


return BuffPullOver
