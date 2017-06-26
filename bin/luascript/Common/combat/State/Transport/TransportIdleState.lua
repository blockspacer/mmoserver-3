---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/25
-- desc： 状态idle
---------------------------------------------------

local IdleState = require "Common/combat/State/State"
local TransportIdleState = ExtendClass(State)

function TransportIdleState:__ctor(scene, name, stateType)

end

function TransportIdleState:FindEnemy(owner)
	return owner:AOIQueryPuppet(function(puppet)
		if owner:IsEnemy(puppet) and Vector3.InDistance(owner:GetPosition(), puppet:GetPosition(), owner.LeaveRadius) then
			return true
		end
		return false
	end)
end

function TransportIdleState:Excute(owner, ...  )
	if not self:FindEnemy(owner) then
		if owner.scene.scene_id == 3 then
			--_info('stateManager:GotoState ePatrol')
			--_info('stateManager:GotoState ePatrolowner.uid = ' ..owner.uid)
		end
		--owner.stateManager:GotoState(StateType.ePatrol)
		return
	end
	
	if owner:IsDied() or owner:IsDestroy() then
	
        return
    end
	if owner.scene.scene_id == 3 then
		--_info('TransportIdleState:Excute')
		--_info('TransportIdleStateowner.uid = ' ..owner.uid)
	end
	owner.enabled = false
	owner:StopMove()
	owner.behavior:BehaveIdle()
end

function TransportIdleState:OnActive(owner, ...  )      
end

function TransportIdleState:OnDeactive(owner, ...  )
end

return TransportIdleState

