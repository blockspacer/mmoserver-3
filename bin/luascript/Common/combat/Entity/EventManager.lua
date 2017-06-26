---------------------------------------------------
-- auth： panyinglong
-- date： 2016/12/27
-- desc： 事件管理
---------------------------------------------------
require "Common/basic/LuaObject"
require "Common/basic/Event"

EventExcuteType = {
	ALL = 1,
	SERVER = 2
}

EventList = {
	OnHpChanged = EventExcuteType.ALL,
	OnTakeDamage = EventExcuteType.ALL,
	OnCauseDamage = EventExcuteType.ALL,
	OnFightStateChanged = EventExcuteType.ALL,
	OnAddHp = EventExcuteType.ALL,
	OnReduceHp = EventExcuteType.ALL,
	OnAddMp = EventExcuteType.ALL,
	OnReduceMp = EventExcuteType.ALL,
	OnBeTarget = EventExcuteType.ALL,
	OnDied = EventExcuteType.SERVER,
	OnBesoul = EventExcuteType.ALL,
	OnResurrect = EventExcuteType.ALL,
	OnDestroy = EventExcuteType.ALL,
	OnMove = EventExcuteType.ALL,
	OnBorn = EventExcuteType.ALL,
	OnBehitStateChanged = EventExcuteType.ALL,
	OnCurrentAttributeChanged = EventExcuteType.ALL,
	OnHatredChanged = EventExcuteType.ALL,
	OnEnterScene = EventExcuteType.ALL,
	OnSpurTo = EventExcuteType.ALL,
}

local GRunOnClient = GRunOnClient

local function CreateEventManager(owner)
	local self = CreateObject()
	self.owner = owner
	self.event = CreateEvent()

	self.Fire = function(event, ...)
		local args = {...}
		-- TODO

		local permission = self.GetPermission(event)

		if not permission then 
			return
		end

		if self.owner[event] then
			self.owner[event](self.owner, unpack(args))
		else
			--print('not found owner event:' .. (event or 'nil'))
		end

		self.event.Brocast(event, unpack(args))
	end

	self.GetPermission = function(event)
		if EventList[event] == nil then
			print('Warnning: EventManager didnt find event:', event, ' but still fire event.')
			return true
		end

		if EventList[event] == EventExcuteType.ALL then
			return true
		end

		if EventList[event] == EventExcuteType.SERVER then
			if not GRunOnClient then
				return true
			end
		end

		return false
	end
	self.Clear = function()
		self.owner = nil
		self.event = nil
	end

	return self
end
return CreateEventManager