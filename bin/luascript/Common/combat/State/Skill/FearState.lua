---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/1/19
-- desc： 恐惧状态
---------------------------------------------------
local Vector3 = Vector3

local State = require "Common/combat/State/State"
local FearState = ExtendClass(State)

function FearState:__ctor(scene, name, stateType)

end

function FearState:Excute(owner, ...)
    self.owner = owner

end

function FearState:StopWalk()
    if self.random_walk_timer then
        self:GetTimer().Remove(self.random_walk_timer)
        self.random_walk_timer = nil
    end
end

function FearState:OnActive( owner, ... )
    State.OnActive(self, owner, ...)
    self.owner = owner

    self:StopWalk()

    local function walk()
    	local direction = Vector3.New(math.random()*2-1,0,math.random()*2-1):Normalize()
        local destination = self.owner:GetPosition() + direction * 4
        destination = self.owner:GetCombatScene():GetNearestPolyOfPoint(destination)
        self.owner:Moveto(destination)
    end
    self.random_walk_timer = self.owner:GetTimer().Repeat(1, walk)
end

function FearState:OnDeactive( owner, ... )
    State.OnDeactive(self, owner, ...)
    self:StopWalk()
end

return FearState
