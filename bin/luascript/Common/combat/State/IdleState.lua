---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/25
-- desc： 状态idle
---------------------------------------------------

local State = require "Common/combat/State/State"
local IdleState = ExtendClass(State)

function IdleState:__ctor(scene, name, stateType)

end

function IdleState:Excute(owner, ...  )
	
	if owner:IsDied() or owner:IsDestroy() then
	
        return
    end
	
	owner:StopMove()
	owner.behavior:BehaveIdle()
end

function IdleState:OnActive(owner, ...  )      
end

function IdleState:OnDeactive(owner, ...  )
end

return IdleState

