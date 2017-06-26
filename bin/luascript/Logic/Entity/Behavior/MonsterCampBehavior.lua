---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/26
-- desc： 单位表现
---------------------------------------------------

local MonsterBehavior = require "Logic/Entity/Behavior/MonsterBehavior"
local MonsterCampBehavior = ExtendClass(MonsterBehavior)

function MonsterCampBehavior:__ctor(owner)

end

function MonsterCampBehavior:OnCreate()   
    MonsterBehavior.OnCreate(self)
end

return MonsterCampBehavior