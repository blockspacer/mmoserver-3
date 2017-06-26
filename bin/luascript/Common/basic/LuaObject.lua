
---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/16
-- desc： 所有lua类的基类
---------------------------------------------------
require "Common/basic/table"
require "Common/basic/Vector3"

function SuperCtor(cls, self, ...)
	local super = getmetatable(cls).__index
	if super and super.__ctor then
		SuperCtor(super, self, ...)
		super.__ctor(self, ...)
	end
end

function ExtendClass(base_class)
	local new_class = {}
	new_class.__index = new_class

	setmetatable(new_class, {
	    __index = base_class,
	    __call = function (cls, ...)
	        local self = setmetatable({}, cls)
	        SuperCtor(cls, self, ...)
	        self:__ctor(...)
	        return self
	    end,
	})

	return new_class
end


function CreateObject()
	local self = {}

	self.base = function()
		local o = {}
				
		for k, v in pairs(self)	do	
			if type(v) == 'function' and k ~= "base" then
				o[k] = v
			end
		end	
		return o
	end

	return self
end