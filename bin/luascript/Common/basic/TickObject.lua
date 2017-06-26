
---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/16
-- desc： 
---------------------------------------------------

require "Common/basic/Timer"
local SceneObject = require "Common/basic/SceneObject2"
local TickObject = ExtendClass(SceneObject)

function TickObject:__ctor(scene)
	self.interval = 0.1
	self.timer = nil
end

function TickObject:Tick(interval)
	
end

function TickObject:RealTick()
	self:Tick(self.timer.delta_time)
end

function TickObject:StartTick(forever)
	forever = forever or false
	if self.timer ~= nil then
		self:StopTick()
	end

	if forever then
		self.timer = self:GetTimer().RepeatForever(self.interval, self.RealTick, self)
	else
		self.timer = self:GetTimer().Repeat(self.interval, self.RealTick, self)
	end
		

end

function TickObject:StopTick()
	if self.timer then
		self:GetTimer().Remove(self.timer)
		self.timer = nil
	end	
end

return TickObject
