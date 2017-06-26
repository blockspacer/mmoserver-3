---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/18
-- desc： StatusManager
---------------------------------------------------
require "Common/basic/LuaObject"

--[[
目前有的状态:
出血
眩晕
封脉
虚弱
中毒
减速
驱散
定身
致盲
]]

StatusEffect = {
	SlowDown = 'Common/eff_common@debuff_jiansu',
	Shield = 'Common/eff_common@buff_hudun',
	Poison = 'Common/eff_common@debuff_zhongdu',
	Bleeding = 'Common/eff_common@debuff_liuxue',
}

local StatusManager = {}
StatusManager.__index = StatusManager

setmetatable(StatusManager, {
    __call = function (cls, ...)
    	SuperCtor(cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})


function StatusManager:__ctor(owner)
	-- 所有者
	self.owner = owner
	self.buff_status = {}
	self.statuses = {}
end

-- 添加buff
function StatusManager:AddStatus(status_name, buff)
	local new = true
	for _, v in pairs( self.buff_status ) do
		if v == status_name then
			new = false
		end
	end
	self.buff_status[buff.buff_id] = status_name

	if new then
		self.statuses[status_name] = 1
		self:OnAddStatus(status_name, buff)
	end
end

function StatusManager:RemoveStatus(status_name, buff)
	local deleted = true
	self.buff_status[buff.buff_id] = nil
	for _, v in pairs( self.buff_status ) do
		if v == status_name then
			deleted = false
		end
	end

	if deleted then
		self.statuses[status_name] = nil
		self:OnRemoveStatus(status_name, buff)
	end
end

function StatusManager:HasStatus(status_name)
	if self.statuses[status_name] == 1 then
		return true
	else
		return false
	end
end

function StatusManager:OnAddStatus(status_name, buff)
	-- print(status_name, '产生')
	self.owner:OnAddStatus(status_name, buff)
end

function StatusManager:OnRemoveStatus(status_name, buff)
	-- print(status_name, '消失')
	self.owner:OnRemoveStatus(status_name, buff)
end

function StatusManager:Clear()
	self.owner = nil
	self.buff_status = nil
	self.statuses = nil
end

return StatusManager
