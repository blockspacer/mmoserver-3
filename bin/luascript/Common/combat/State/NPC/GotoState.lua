---------------------------------------------------
-- auth： panyinglong
-- date： 2016/11/8
-- desc： 行进状态
---------------------------------------------------
local Vector3 = Vector3

local State = require "Common/combat/State/State"
local GotoState = ExtendClass(State)
local flog = require "basic/log"

function GotoState:__ctor(scene, name, stateType)
    self.destionation = nil
end

function GotoState:moveTo(owner, pos)
	owner.taskData.current = owner.taskData.current + 1
	if owner.taskData.current > #owner.taskData.positions then
		print("over")
		return
	else
		owner:Moveto(owner.taskData.positions[owner.taskData.current])
	end
end
-------------------
function GotoState:isReached(owner, pos)
	if Vector3.InDistance(owner:GetPosition(), pos, 2) and not owner:isMoving() then
		return true
	end
	return false
end
--------------------

function GotoState:Excute(owner, ...)
	if owner:IsDied() or owner:IsDestroy() then
		return
	end

	if not owner.taskData or not owner.taskData.positions or not owner.taskData.radius then
		print("error!!! gotostate invalidate owner.taskData")
		return
	end

	if self.destionation == nil then			
		owner.taskData.current = owner.taskData.current + 1
		if owner.taskData.current > #owner.taskData.positions then
			-- print("over 走完了")
			owner.taskData.isReached = true
			return
		end
		self.destionation = owner.taskData.positions[owner.taskData.current]
		owner.patrolData.center = self.destionation
	end

	if self.destionation then
		if self:isReached(owner, self.destionation) then
			self.destionation = nil
			-- print("gotostate ePatrol")
			owner.stateManager:GotoState(StateType.ePatrol)  
		else
			owner:Moveto(self.destionation)
		end
	end
end

return GotoState
