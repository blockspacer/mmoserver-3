---------------------------------------------------
-- auth： zhangzeng
-- date： 2016/9/12
-- desc： 数量触发器
---------------------------------------------------
require "Common/basic/LuaObject"

local SceneObject = require "Common/basic/SceneObject2"
local NumsTrigger = ExtendClass(SceneObject)

function NumsTrigger:__ctor(scene, data, callback)
    self.timerInfo = nil

    self.data = data
	self.callback = callback
	self.delayTime = 0.1
end

function NumsTrigger:Start()
	
	self.timerInfo = self:GetTimer().Repeat(self.delayTime, self.OnTriggerEnter, self)
end
	
function NumsTrigger:IsTrigger()
	
	local ret = false
	local entityType
	local nums = 0
	local trggerPara1 = 1
	local paraType =  type(self.data.TrggerPara1)
	if paraType == 'number' then
		trggerPara1 = self.data.TrggerPara1
	elseif paraType == 'table' then
		trggerPara1 = self.data.TrggerPara1[1]
	end
	
	local trggerPara2 = tonumber(self.data.TrggerPara2)
	if (trggerPara1 == 1) then    --所有怪物
		if (trggerPara2 <= 0) then   --剩下该类型的数量
			local nums = self:GetEntityManager().GetNums(EntityType.Monster)
			trggerPara2 = -trggerPara2
			if (trggerPara2 >= nums) then
				ret = true
			end
		else 
			local killedNums = self:GetEntityManager().GetKilledNums(EntityType.Monster)
			if (trggerPara2 <= killedNums) then
				ret = true
			end
		end
	elseif (trggerPara1 == 2) then		--所有玩家
		if (trggerPara2 <= 0) then	--剩下该类型的数量
			nums = self:GetEntityManager().GetNums(EntityType.Hero)
			nums = nums + self:GetEntityManager().GetNums(EntityType.Dummy)
			trggerPara2 = -trggerPara2
			if (trggerPara2 >= nums) then
				ret = true
			end
		else 
			nums = self:GetEntityManager().GetKilledNums(EntityType.Hero)
			nums =  nums + self:GetEntityManager().GetKilledNums(EntityType.Dummy)
			if (trggerPara2 <= nums) then
				ret = true
			end
		end
	end
	
	return ret
end
    
function NumsTrigger:OnTriggerEnter()
	if (self:IsTrigger()) then
		self.callback(self:GetTriggersManager(), self.data.EventResponse)
		self:GetTimer().Remove(self.timerInfo)
		self.timerInfo = nil
	end
end

function NumsTrigger:Destroy()

	if self.timerInfo then
	
		self:GetTimer().Remove(self.timerInfo)
		self.timerInfo = nil
	end
end

return NumsTrigger





