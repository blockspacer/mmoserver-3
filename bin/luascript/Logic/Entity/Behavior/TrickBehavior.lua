---------------------------------------------------
-- auth： panyinglong
-- date： 2017/3/18
-- desc： 机关
---------------------------------------------------

local Behavior = require "Logic/Entity/Behavior/Behavior"
local TrickBehavior = ExtendClass(Behavior)

function TrickBehavior:__ctor(owner)
    
end

function TrickBehavior:BehaviorTrigger()
    
    return true
end

return TrickBehavior
