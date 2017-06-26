---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/1
-- desc： 单位表现
---------------------------------------------------
local systemLoginCreate = GetConfig("system_login_create")

local Behavior = require "Logic/Entity/Behavior/Behavior"
local DummyBehavior = ExtendClass(Behavior)

function DummyBehavior:__ctor(owner)
	self.modelId = nil
	self:OnCreate()
end

function DummyBehavior:Moveto(pos)
    Behavior.Moveto(self, pos)
end

local function GetHeroModelID(vocation ,sex)
    local vocationSeg = 'Male'
    if sex == 2 then	
        vocationSeg = 'Female'
    end
    return systemLoginCreate.RoleModel[vocation][vocationSeg]
end

function DummyBehavior:OnCreate()   
    local vocation = self.owner.data.vocation
	local sex = self.owner.data.sex
	self.modelId = GetHeroModelID(vocation,sex)
end

return DummyBehavior