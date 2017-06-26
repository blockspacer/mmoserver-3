---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/25
-- desc： 事件管理 
---------------------------------------------------
require "Common/basic/LuaObject"
---------------------------------------------

local function CreateEventItem(name)
	local self = CreateObject()

	local function spawn(f)
	    return coroutine.resume(coroutine.create(function()
	        f()
	    end))
	end

	self.handlers = {}
    self.args = nil
    self.EventName = name or "<Unknown Event>"

    local handle_owners = {}
    self.Connect = function(func, owner)
    	local handler = {}
    	handler.func = func
    	handler.owner = owner
    	table.insert(self.handlers, handler)
    end
    self.Disconnect = function(func, owner)
        for k, v in pairs(self.handlers) do
            if v.func == func and ( (owenr == nil and v.owner == nil ) or v.owner == owner) then
            	table.remove(self.handlers, k)
                break
            end
        end
    end
    self.DisconnectAll = function()
		self.handlers = {}
		handle_owners = {}
	end

	self.Fire = function(...)
		self.args = {...}
		local i = 0
	    for k, v in pairs(self.handlers) do
	    	if v.owner then
	    		v.func(v.owner, unpack(self.args))
	    	else
	    		v.func(unpack(self.args))
	    	end
	    end
	    self.args = nil
	end

	return self
end

function CreateEvent()
	local self = CreateObject()
	self.events = {}
	self.AddListener = function(event, handler, owner)
		if not event then
			-- error("event parameter in addlistener function has to be string, " .. type(event) .. " not right.")
		end
		if not handler or type(handler) ~= "function" then
			-- error("handler parameter in addlistener function has to be function, " .. type(handler) .. " not right")
		end

		if not self.events[event] then
			self.events[event] = CreateEventItem(event)
		end

		self.events[event].Connect(handler, owner)
	end

	self.Brocast = function(event, ...)
		if not self.events[event] then
			-- print("brocast " .. event .. " has no event.")
		else
			local args = {...}
			self.events[event].Fire(unpack(args))
		end
	end

	self.RemoveListener = function(event, handler, owner)
		if not self.events[event] then
			-- error("remove " .. event .. " has no event.")
		else
			self.events[event].Disconnect(handler, owner)
		end
	end
	return self
end

-- 全局Event
-- Event = Event or CreateEvent()

