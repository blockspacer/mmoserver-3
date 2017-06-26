---------------------------------------------------
---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/25
-- desc： timer
---------------------------------------------------

require "Common/basic/LuaObject"
local functions = require "Common/basic/functions"
--flog = require "basic/log"


local gameManager = nil
if GRunOnClient then
	gameManager = gameMgr
end

-- num = 0 表示永久
local function CreateTimerInfo(seconds, func, num, ...)
	local self = CreateObject()

	self.seconds = seconds
	self.func = func
	self.num = num	
	self.args = {...}

	self.remove = false
	self.stop = false
	self.forever = false -- 不会被removeall(如切场景)销毁掉，只能单独销毁
	self.locked = false -- 安全锁 
	self.isAbs = false --  是否是绝对时间timer，绝对时间不受gamespeed影响，相对的timer受gamespeed影响(目前仅客户端用)
	self.createtime = os.time()

	local tick = 0
	self.Tick = function(t)
		if self.stop or self.locked then
			return 
		end
		tick = tick + t

		if tick >= self.seconds then
			self.delta_time = tick
			tick = 0

			self.locked = true -- 防止回调出错而无限调用
			if self.func then
				self.func(unpack(self.args))
			end
			self.locked = false

			if self.num > 0 then
				self.num = self.num - 1
				if self.num <= 0 then
					self.remove = true
					self.stop = true
				end
			end
		end		
	end

	return self
end

local function CreateTimer()
 	local self = CreateObject()
 	local timerEngine = nil
 	local timers = {}
 	-- Warnning 客户端0.01执行，可能涉及到有一些状态什么的，需要快一点
 	if GRunOnClient then
		self.interval = 0.01
	else
		self.interval = 0.1 --其实是100ms的意思
	end

	self.last_tick_time = functions.get_now_time_mille()
	
	-- local intervalCount = 60
	-- local index = 0
 	local Tick = function()
		-- intervalCount = intervalCount + self.interval
		-- if intervalCount >= 60 then
		-- 	index = index + 1
		-- 	intervalCount = 0
		-- 	collectgarbage('collect')
		-- 	local c = collectgarbage('count')
		-- 	print("----- lua mem: 第" .. index ..  "分钟:" .. math.floor(c) .. "kb")
		-- end
		
	    local current_time = functions.get_now_time_mille()
        local delta_time = (current_time - self.last_tick_time)/1000
        self.last_tick_time = current_time
        --print('Tick',delta_time)
        --flog("info", "Tick")
	 	for i = #timers, 1, -1 do
	 		local timer = timers[i]
	 		if timer.remove then
	 			table.remove(timers, i)
	 			timer.args = {}
	 			timer.func = nil
	 			timer = nil
	 		elseif timer.locked then
	 			table.remove(timers, i)
	 			timer.args = {}
	 			timer.func = nil
	 			timer = nil
	 			print('ERROR! timer is locked. tick时间过长或回调函数出错. 已经remove该timer')
	 		else
	 			if GRunOnClient then
	 				if timer.isAbs then
	 					timer.Tick(self.interval) 	-- 绝对时间timer
	 				else
	 					timer.Tick(self.interval * gameManager.GameSpeed) -- 参考timescale timer
	 				end
	 			else
	 				timer.Tick(delta_time)
	 			end
	 		end
		end
 	end
 	local Start = function()
 		if GRunOnClient then
	 		local timerMgr = LuaHelper.GetTimerManager()
			timerMgr:StartTimer(self.interval)

	 		if timerEngine == nil then
	 			timerEngine = TimerInfo.New(self.interval, 0, function () Tick(); end)
				timerMgr:AddTimerEvent(timerEngine)
	 		end
	 	else
	 		local server_timer = require "basic/timer"
	 		local timer_id = server_timer.create_timer(Tick, self.interval * 1000, 1)
	 	end
 	end

	-- 延迟执行
	self.Delay = function(seconds, func, ...)
		local timer = CreateTimerInfo(seconds, func, 1, unpack({...}))
		table.insert(timers, timer)
		return timer
	end

	-- 重复执行
	self.Repeat = function(seconds, func, ...)
		local timer = CreateTimerInfo(seconds, func, 0, unpack({...}))
		table.insert(timers, timer)
		return timer
	end

	-- 执行num次
	self.Numberal = function(seconds, num, func, ...)
		local timer = CreateTimerInfo(seconds, func, num, unpack({...}))
		table.insert(timers, timer)
		return timer
	end

	-- 移除timer
	self.Remove = function(timerInfo)
		if timerInfo then
			timerInfo.remove = true
		end
	end

	-- 暂停timer
	self.Stop = function(timerInfo)
		if timerInfo then
			timerInfo.stop = true
		end
	end

	-- 继续timer
	self.Resume = function(timerInfo)
		if timerInfo then
			timerInfo.stop = false
		end
	end

	self.RemoveAll = function()
		for i = #timers, 1, -1 do
	 		local timer = timers[i]
	 		if not timer.forever then
		 		self.Remove(timer)
		 	end
		end
	end

	self.RepeatForever = function(seconds, func, ...)
		local args = {...}
		local timer = self.Repeat(seconds, func, unpack(args))
		timer.forever = true
		return timer
	end

	Start()
 	return self
end 

Timer = Timer or CreateTimer()

return CreateTimer