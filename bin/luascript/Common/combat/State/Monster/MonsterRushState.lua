---------------------------------------------------
-- auth： panyinglong
-- date： 2017/2/27
-- desc： 对冲状态
---------------------------------------------------
local Vector3 = Vector3

local State = require "Common/combat/State/State"
local MonsterRushState = ExtendClass(State)

function MonsterRushState:__ctor(scene, name, stateType)
end

function MonsterRushState:Excute(owner, ...)
	local FindEnemy = function()
	    local mgr = owner:GetEntityManager()
	    if mgr == nil then
	        return nil
	    end
		enemy = owner:GetCurrentHatredEntity() -- 选择仇恨值高的
		if enemy then
			return enemy
		end
		return nil
	end

	if owner:IsDied() or owner:IsDestroy() then
		return
	end
	local enemy = FindEnemy()
	if enemy then
		owner.stateManager:GotoState(StateType.eAttack, enemy)  
		return
	end
end

return MonsterRushState
