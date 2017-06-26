--wupeifeng --
require "Common/basic/Event"
require "Common/basic/functions"
require "Common/basic/MathHelper"
local TickObject = require "Common/basic/TickObject"

local AreaTriggerManager = ExtendClass(TickObject)

function AreaTriggerManager:__ctor(scene)
	self.area_triggers = {}
end

function AreaTriggerManager:CreateTrigger(trigger_object, pos, rect, dir)
	local trigger = {}
	trigger.trigger_object = trigger_object
	trigger.pos = pos
	trigger.rect = rect
	trigger.dir = dir
	trigger.need_trigger = true
	table.insert( self.area_triggers, trigger )
	return table.maxn( self.area_triggers )
end

function AreaTriggerManager:DestoryTrigger(pos)
	table.remove( self.area_triggers, pos )
end

-- 检测是否在区域内
function AreaTriggerManager:Tick(interval)
	local mgr = self:GetEntityManager()
	if mgr == nil then
		return 
	end
	local units = mgr.QueryPuppets(function(v) 
			return true
		end)

	--print('AreaTriggerManager:Tick.  unit count', table.maxn(units))
	for _,trigger in ipairs(self.area_triggers) do
		if trigger.need_trigger then
			for _,unit in pairs(units) do

				local biggest = math.max( trigger.rect.x, trigger.rect.y, trigger.rect.z )
				if unit.GetPosition and 
					MathHelper.IsInMiddleRect(trigger.pos, trigger.dir, trigger.rect, unit:GetPosition()) then

					local res = trigger.trigger_object:OnTriggerEnter(unit.entityType, unit.uid)
					if res then
						trigger.need_trigger = false
						break
					end
				end
			end
		end

	end

end

function AreaTriggerManager:Destroy()
	self.area_triggers = {}
end

return AreaTriggerManager




