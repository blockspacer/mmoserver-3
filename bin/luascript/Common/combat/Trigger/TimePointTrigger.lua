--zhangzeng --
require "Common/basic/Event"
require "Common/basic/functions"
require "Common/basic/Timer"

local SceneObject = require "Common/basic/SceneObject2"
local TimePointTrigger = ExtendClass(SceneObject)

function TimePointTrigger:__ctor(scene, data, callback)
    self.timerInfo = nil
	self.TriggerNum = -1   					--無限次循環
	self.delayTime = 50                		--50s刷新一次
	self.callback = callback
	self.eventResponse = data.EventResponse
	self.para1 = data.TrggerPara1       	--星期
	self.para2 = data.TrggerPara2			--時鐘
	self.data = data
	self.timesTable = {}
	self.weekName = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'}
end

function TimePointTrigger:StartTimer()
	local week = os.date( "%A", time)
	local hour = os.date( "%H", time)
	local minu = os.date( "%M", time)
	
	for k, v in pairs (self.timesTable) do   								--k代表星期
		if week == self.weekName[k] then 									--星期一致
			for i = 1, #v do
				local flag = self.timesTable[k][i].flag
				local value = self.timesTable[k][i].value
				local timeList = string.split(value, "-")       			--13-50代表13點50分
				if not flag then
					if hour == timeList[1] and minu == timeList[2] then   	--代表時間一致
						self.timesTable[k][i].flag = true
						self:OnTriggerEnter()								--觸發定點觸發器
					end
				else
					if hour >= timeList[1] and minu > timeList[2] then
						self.timesTable[k][i].flag = false
					end
				end
			end
		end
	end

	if self.TriggerNum == 0 then
		if self.timerInfo then
			self:GetTimer().Remove(self.timerInfo)
			self.timerInfo = nil
		end
		return
	elseif self.TriggerNum >= 1 then
		self.TriggerNum = self.TriggerNum - 1
	end
end

function TimePointTrigger:StoreTimes()
	local para1Type = type(self.para1)
	if para1Type == 'table' then 
		local weekNum = #self.para1
		for i = 1, weekNum do
			self.timesTable[self.para1[i]] = {}
			local times = string.split(self.para2, "|")
			for j = 1, #times do
				local flagTable = {}
				flagTable.value = times[j]
				flagTable.flag = false
				self.timesTable[self.para1[i]][j] = flagTable
			end
		end
	elseif para1Type == 'number' then
		self.timesTable[self.para1] = {}
		local times = string.split(self.para2, "|")
		for j = 1, #times do
			local flagTable = {}
			flagTable.value = times[j]
			flagTable.flag = false
			self.timesTable[self.para1][j] = flagTable
		end
	end
end

function TimePointTrigger:ClearTimes()
	for k, v in pairs(self.timesTable) do
		for i = 1, #v do
			table.remove(self.timesTable[k], i)
		end
		table.remove(self.timesTable, k)
	end
	self.timesTable = nil
end

function TimePointTrigger:Start()
	self:StoreTimes()
	self.timerInfo = self:GetTimer().Repeat(self.delayTime, function() self:StartTimer()  end)
end

function TimePointTrigger:OnTriggerEnter()
	local temps = self.callback(self:GetTriggersManager(), self.eventResponse)
	if self.timerInfo then
		self:GetTimer().Remove(self.timerInfo)
		self.timerInfo = nil
	end
	
	local OnEnityDied = function(elementId)
		if not self.timerInfo then
			self.timerInfo = self:GetTimer().Repeat(self.delayTime, function() self:StartTimer()  end)
		end
	end

	for _,enity in ipairs(temps) do
		enity.eventManager.event.AddListener('OnDestroy', OnEnityDied)
	end
end

function TimePointTrigger:Destroy()
	if self.timerInfo then
	
		self:GetTimer().Remove(self.timerInfo)
		self.timerInfo = nil
	end
	self:ClearTimes()
end

return TimePointTrigger


