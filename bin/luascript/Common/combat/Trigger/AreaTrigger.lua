
local Vector3 = Vector3
require "Common/basic/LuaObject"

local SceneObject = require "Common/basic/SceneObject2"
local AreaTrigger = ExtendClass(SceneObject)

function AreaTrigger:__ctor(scene, data, callback)
    self.triggerType = data.TrggerPara1
	self.callback = callback
	self.eventResponse = data.EventResponse
	self.data = data
end

function AreaTrigger:Start()

	local boxValues = string.split(self.data.TrggerPara2, "|")
	local w = boxValues[1]
	local h = boxValues[2]
	local l = boxValues[3]
	local pos = Vector3.New()
	local rect = Vector3.New()
	local dir = Quaternion.Euler(tonumber(self.data.ForwardX) or 0, tonumber(self.data.ForwardY) or 0, tonumber(self.data.ForwardZ) or 0)

	pos.x = tonumber(self.data.PosX)
	pos.y = tonumber(self.data.PosY)
	pos.z = tonumber(self.data.PosZ)
	
	rect.x = tonumber(w)
	rect.y = tonumber(h)
	rect.z = tonumber(l)
	
    self.gameObject = self:GetTriggersManager().AreaTriggerManager:CreateTrigger(self, pos, rect, dir)

end
    
function AreaTrigger:OnTriggerEnter(entityType, uid)

	local isTrigger = false
	local paraType = type(self.triggerType)
	local triggerType = 1
	if paraType == 'table' then
		triggerType = self.triggerType[1]
	elseif paraType == 'number' then
		triggerType = self.triggerType
	end
	
	if (triggerType == 1) then  		--1. 所有敌人(Monster)触发
	
		if (entityType == EntityType.Monster) then
		
			isTrigger = true
		end
	elseif (triggerType == 2) then		--2. 所有玩家（Player）
	
		if (entityType == EntityType.Hero or entityType == EntityType.Dummy) then
		
			isTrigger = true
		end		
	elseif (triggerType == 3) then		--3. 所有（All）

		isTrigger = true
	elseif (triggerType == 4) then		--4.npc
	
		if (entityType == EntityType.NPC) then
		
			isTrigger = true
		end
	end
	
	if (isTrigger) then
	
		if (self.eventResponse) then
		
			self.callback(self:GetTriggersManager(), self.eventResponse)
		else
			
			self.callback(self:GetTriggersManager(), uid)
		end
	end
	
	return isTrigger
end
    
function AreaTrigger:Destroy()
    self:GetTriggersManager().AreaTriggerManager:DestoryTrigger(self.gameObject)
    self.gameObject = nil
end

return AreaTrigger
