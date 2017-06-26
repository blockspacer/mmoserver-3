

local PatrolState = require "Common/combat/State/PatrolState"
local PetPatrolState = ExtendClass(PatrolState)

function PetPatrolState:__ctor(scene, name, stateType)

end

function PetPatrolState:Excute(owner, ...)	
	if owner:IsDied() or owner:IsDestroy() then
		return
	end
	
	local args = {...}
	PatrolState.Excute(self, owner, unpack(args))
end

return PetPatrolState
