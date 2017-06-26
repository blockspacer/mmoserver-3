---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/1/10
-- desc： 单位集合触发器
---------------------------------------------------
require "Common/basic/LuaObject"

local SceneObject = require "Common/basic/SceneObject2"
local UnitSetTrigger = ExtendClass(SceneObject)

function UnitSetTrigger:__ctor(scene, data, callback)
    self.timerInfo = nil

    self.data = data
	self.callback = callback

	local paraType = type(data.TrggerPara1)
	if paraType == 'table' then
		self.nums = data.TrggerPara1[1]
	elseif paraType == 'number' then
		self.nums = data.TrggerPara1
	end
    --self.units = {}
    local tmp = string.split(data.TrggerPara2, '|')
    if tmp[2] == nil then
    	self.reborn_time_min = tonumber( tmp[1] )
    	self.reborn_time_max = tonumber( tmp[1] ) 
    else
    	self.reborn_time_min = math.floor(math.min( tonumber(tmp[1]), tonumber(tmp[2])))
    	self.reborn_time_max = math.floor(math.min( tonumber(tmp[1]), tonumber(tmp[2])))
    end
end


function UnitSetTrigger:Start()
	
	for i = 1, self.nums, 1 do
		local reborn_time = math.random(self.reborn_time_min, self.reborn_time_max)
		self:GetTimer().Delay(reborn_time, self.Reborn, self)
	end
	--self:GetTimer().Repeat(1, self.OnTriggerEnter, self)
end
	
function UnitSetTrigger:IsTrigger()
	
	--[[for i = table.getn(self.units), 1, -1 do
		if self.units[i]:IsDestroy() or self.units[i]:IsDied() then
			table.remove( self.units, i )
		end
	end

	if table.getn(self.units) < self.nums then
		return true
	else
		return false
	end]]
end

function UnitSetTrigger:Reborn()
	--while (table.getn(self.units) < self.nums) do
		local temps = self.callback(self:GetTriggersManager(), self.data.EventResponse)
		for _,unit in ipairs( temps ) do

		    local function OnUnitDied()
		    	local reborn_time = math.random(self.reborn_time_min, self.reborn_time_max)
		    	self:GetTimer().Delay(reborn_time, self.Reborn, self)
		    end

		    unit.eventManager.event.AddListener('OnDestroy', OnUnitDied)
		end


	--end
end
    
function UnitSetTrigger:OnTriggerEnter()

	--if (self:IsTrigger()) then
		--self:GetTimer().Delay(self.reborn_time, self.Reborn, self)
	--end
end

function UnitSetTrigger:Destroy()

	if self.timerInfo then
	
		self:GetTimer().Remove(self.timerInfo)
		self.timerInfo = nil
	end
end

return UnitSetTrigger





