---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/25
-- desc： 状态管理基类
---------------------------------------------------

require "Common/basic/LuaObject"
require "Common/basic/Event"
require "Common/basic/Timer"
require "Common/combat/State/State"
local CreateNullState = require "Common/combat/State/NullState"
local SceneObject = require "Common/basic/SceneObject2"
local StateManager = ExtendClass(SceneObject)

local OnStateChangeEvent = "ON_STATE_CHANGE"

function StateManager:__ctor(scene, owner)
	self.owner = owner

	self.npcStateDic = {}

	self.currentState = CreateNullState()
	self.lastState = CreateNullState()

	self.stateArgs = {}
	self.StateChangeEvent = CreateEvent()

	self.interval = 0.1
	self.timer = nil
	self:AddState(StateType.eNull, CreateNullState())

end

function StateManager:Tick()
	if self.owner:IsControl() then
		self.currentState:Excute(self.owner, unpack(self.stateArgs))
	end
end

function StateManager:StartTick()
	if self.timer == nil then
		self.timer = self:GetTimer().Repeat(self.interval, function() self:Tick(); end)
	else
		self:GetTimer().Resume(self.timer)
	end	
end

function StateManager:StopTick()
	if self.timer then
		self:GetTimer().Stop(self.timer)
	end
end

function StateManager:GetState(stateType)
	return self.npcStateDic[stateType];
end

function StateManager:Rollback()
	self:GotoState(self.lastState.stateType)
end

function StateManager:GotoState( stateType, ... )
	if not self.owner:IsControl() then
		return 
	end
	self.stateArgs = {...}
	if self.currentState.stateType == stateType then
		return true
	end

	local state = self:GetState(stateType)
	if state == nil then
		return false
	end
	self.lastState = self.currentState;
	self.currentState = state;
	self.lastState:OnDeactive(self.owner, unpack(self.stateArgs))
	self.currentState:OnActive(self.owner, unpack(self.stateArgs))

	-- print("state changed! lastState:"..self.lastState.name.."; currentState:"..self.currentState.name..
	-- 	" type:"..self.owner.entityType.. " uid:"..self.owner.data.EntityUID)
	self.StateChangeEvent.Brocast(OnStateChangeEvent, unpack(self.stateArgs))	
	return true	
end

function StateManager:Clear()
	self.owner = nil
	self.npcStateDic = nil
	self.currentState = nil
	self.lastState = nil
	self.stateArgs = nil
	self.StateChangeEvent = nil
	self.interval = nil
	self.timer = nil
end

function StateManager:AddState(stateType, state)
	state.scene = self.scene
	self.npcStateDic[stateType] = state
end

function StateManager:RemoveState(stateType)
	if 	self.currentState.stateType == stateType then
		self.currentState = CreateNullState()
	end
	
	if self.lastState.stateType == stateType then
		self.lastState = CreateNullState()
	end
	self.npcStateDic[stateType] = nil
end

function StateManager:AddStateChangeListener(func)
	self.StateChangeEvent.AddListener(OnStateChangeEvent, func)
end

function StateManager:RemoveStateChangeListener(func)
	self.StateChangeEvent.RemoveListener(OnStateChangeEvent, func)
end

return StateManager