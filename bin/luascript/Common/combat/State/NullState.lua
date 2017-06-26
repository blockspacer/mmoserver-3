---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/25
-- desc： 状态NullState
---------------------------------------------------

local State = require "Common/combat/State/State"
local NullState = ExtendClass(State)

function NullState:__ctor(scene, name, stateType)

end

function NullState:Excute( stateManager, ...  )        
end

function NullState:OnActive( stateManager, ...  )        
end

function NullState:OnDeactive( stateManager, ...  )        
end

return NullState
