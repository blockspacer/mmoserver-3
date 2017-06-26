---------------------------------------------------
-- auth： zhangzeng
-- date： 2016/9/13
-- desc： 数据触发器
---------------------------------------------------
require "Common/basic/LuaObject"

local SceneObject = require "Common/basic/SceneObject2"
local DatasTrigger = ExtendClass(SceneObject)

function DatasTrigger:__ctor(scene, data, callback)
    self.callback = callback
	self.delayTime = 0.1
	self.data = data
	self.timerInfo = nil
end

function DatasTrigger:Start()
	self.timerInfo = self:GetTimer().Repeat(self.delayTime, function()
		self:OnTriggerEnter()
	end)
end

local IsDummy = function(p)
	if p.entityType == EntityType.Dummy or p.entityType == EntityType.Hero then
		return true
	end
	return false	
end

local sceneID = -1
local IsScenePuppet = function(p)
	if p.data.ElementID == sceneID then
		return true
	end
	return false
end

function DatasTrigger:IsTrigger()
	local ret = false
	local trggerPara1 = -1
	local paraType = type(self.data.TrggerPara1)
	if paraType == 'table' then
		trggerPara1 = self.data.TrggerPara1[1]
	elseif paraType == 'number' then
		trggerPara1 = self.data.TrggerPara1
	end
	
	local trggerPara2 = tonumber(self.data.TrggerPara2)
	if trggerPara1 == -1 then --所有玩家
	
		local dummys = self:GetEntityManager().QueryPuppetsAsArray(IsDummy)
		for k, v in pairs(dummys) do
			local hpRate = v.hp * 100 / v.base_hp_max()
			if hpRate <= trggerPara2 then
			
				return true
			end
		end
	else				--场景元素
		
		sceneID = trggerPara1
		local puppet = self:GetEntityManager().QueryPuppet(IsScenePuppet)
		if puppet then
			
			local hpRate = puppet.hp * 100 / puppet.base_hp_max()
			if hpRate <= trggerPara2 then
			
				return true
			end
		end
	end
	
	return ret
end

function DatasTrigger:OnTriggerEnter()
	if self:IsTrigger() then
		self.callback(self:GetTriggersManager(), self.data.EventResponse)
		self:GetTimer().Remove(self.timerInfo)
		self.timerInfo = nil
	end
end

function DatasTrigger:Destroy()
	if self.timerInfo then
		self:GetTimer().Remove(self.timerInfo)
		self.timerInfo = nil
	end
end

return DatasTrigger





