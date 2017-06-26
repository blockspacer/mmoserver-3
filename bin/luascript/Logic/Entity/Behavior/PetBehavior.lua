---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/1
-- desc： 单位表现
---------------------------------------------------

local Behavior = require "Logic/Entity/Behavior/Behavior"
local PetBehavior = ExtendClass(Behavior)

local GrowingPet = GetConfig( "growing_pet" )

function PetBehavior:__ctor(owner)
	self.modelId = nil
	self:OnCreate()
end

function PetBehavior:GetPetModelRes()  --获取宠物模型
	local modelId
	local modelKey = 'ModelID'	--默认第一种外观
	local petAppearance = self.owner.data.pet_appearance
	if petAppearance == 2 or petAppearance == 3 then   --为第二种外观和第三种外观时
		
		modelKey = modelKey .. petAppearance
	end
	modelId = GrowingPet.Attribute[self.owner.data.pet_id][modelKey]
	
	return modelId
end

function PetBehavior:OnCreate()
	self.modelId = self:GetPetModelRes()
end

return PetBehavior