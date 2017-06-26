--songhua --
require "Common/basic/Event"
require "Common/basic/functions"
require "Common/basic/Timer"

local SceneObject = require "Common/basic/SceneObject2"
local TimerTrigger = ExtendClass(SceneObject)

function TimerTrigger:__ctor(scene, data, callback)
	self.TriggerNum = 1		--为-1代表永久，正值代码次数
    self.timerInfo = nil
	
	self.callback = callback
	self.eventResponse = data.EventResponse
	self.delayTime = data.TrggerPara1
	self.data = data

	local para2 = data.TrggerPara2
	if para2 == "" then
		para2 = 1
	else
		para2 = para2 / 1
	end
	self.TriggerNum = para2
end

function TimerTrigger:StartTimer()
	local delayTime = 0
	local paraType = type(self.delayTime)
	if paraType == 'table' then
		local timeNum = #self.delayTime
		if timeNum == 2 then	--时间区间
		delayTime = math.random(self.delayTime[1], self.delayTime[2])
		elseif timeNum == 1 then
		delayTime = self.delayTime[1]
		else
			print('TrggerPara2 is wrong')
			return
		end
	elseif paraType == 'number' then
		delayTime = self.delayTime
	end
	
	if self.TriggerNum == 0 then
		return
	elseif self.TriggerNum >= 1 then
		self.TriggerNum = self.TriggerNum - 1
	end
	self.timerInfo = self:GetTimer().Delay(delayTime, function() self:OnTriggerEnter() self:StartTimer() end)
end

function TimerTrigger:Start()
	self:StartTimer()
end

function TimerTrigger:OnTriggerEnter()
	self.callback(self:GetTriggersManager(), self.eventResponse)
end

function TimerTrigger:Destroy()
	if self.timerInfo then
	
		self:GetTimer().Remove(self.timerInfo)
		self.timerInfo = nil
	end
end

return TimerTrigger


