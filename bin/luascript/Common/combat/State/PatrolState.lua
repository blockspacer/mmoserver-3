---------------------------------------------------
-- auth： panyinglong
-- date： 2016/9/11
-- desc： 巡逻状态
---------------------------------------------------
local Vector3 = Vector3

local fightBaseScheme = GetConfig("common_fight_base")

PatrolAction = {
	eNone = 0,
	eMove = 1,
	eIdle = 2,
};

PatrolType = {
	A = 1, 	-- 不移动
	B = 2,	-- 围绕中心点画圆, 在圆内随机点移动/idle
	C = 3,	-- 未实现
	D = 4, 	-- 沿特定路径点移动
	E = 5, 	-- 不移动, 如果不在出生点了, 则回到出生点
};

function CreatePatrolData(owner)
	local self = CreateObject()
	local data = owner.data
	self.dataStr = data.LimitedRadius

	self.type = ''
	self.posData = {}
	self.center = owner:GetBornPosition()

	local ToPos = function(posStr)
		local t = {}
		local posStrArr = string.split(posStr, '|')
		for i = 1, #posStrArr do
			local itemStrArr = string.split(posStrArr[i], '*')
			local pos = Vector3.New(itemStrArr[1]/1, itemStrArr[2]/1, itemStrArr[3]/1)
			table.insert(t, pos)
		end
		return t
	end

	-- 巡逻半径
	local t = string.sub(self.dataStr, 1, 1) 

	local commonParamConfig = commonParameterFormula
	if t == 'A' then
		self.type = PatrolType.A
	elseif t == 'B' then
		local datas = string.split(self.dataStr, '=')
		local patrolId = datas[2]/1
		local moveLogic = fightBaseScheme.MoveLogic[patrolId]
		self.PatrolIdleMin = moveLogic.TimeMin/1000
		self.PatrolIdleMax = moveLogic.TimeMax/1000
		self.PatrolRadius = moveLogic.R/100
		self.type = PatrolType.B
	elseif t == 'C' then	
		self.type = PatrolType.C
	elseif t == 'D' then
		self.type = PatrolType.D
		local posStr = string.sub(self.dataStr, 3)
		self.posData = ToPos(posStr)
	elseif t == 'E' then
		self.type = PatrolType.E
	end

	return self
end

local State = require "Common/combat/State/State"
local PatrolState = ExtendClass(State)
local flog = require "basic/log"

function PatrolState:__ctor(scene, name, stateType)
	self.destination = nil
	self.isIdle = false
	self.isPatroling = false
	self.lastAction = PatrolAction.eIdle

	self.nextPositionIndex = -1
end

-- 执行巡逻(走一段，停一段)
-- local testIndex = 1
-- local testPos = {
-- 	Vector3.New(3, -1.5, 7.8),
-- 	Vector3.New(-8, -1.5, 1.4),
-- 	Vector3.New(5, -1.5, -6),
-- }
-- local testPos = {
-- 	Vector3.New(63, 41, -70),
-- 	Vector3.New(69, 41, -66),
-- 	Vector3.New(65, 41, -61),
-- }
function PatrolState:RandPatrol(owner, center, radius, minIdle, maxIdle)
	local function excuteIdle()
		local idleTime = math.random(minIdle, maxIdle)
		self.isIdle = true
		self:GetTimer().Delay(idleTime, function() self.isIdle = false; end)
		self.lastAction = PatrolAction.eIdle
	end
	local function checkPatrolOver()
		local isMoving = owner:isMoving()
		if self.isPatroling and not isMoving then -- 正在moving
			owner:StopMove()
			self.isPatroling = false
			self.destination = nil

			-- local pos = owner:GetPosition()
			-- if owner.data.flag == 'test' then
			-- 	flog('pylDebug', string.format("stop move pos:(%.2f, %.2f, %.2f) uid=%s", pos.x, pos.y, pos.z, owner.uid))
			-- end
		end
	end
	local function getRandPos()	
		local ret = false
	    local randPos = Vector3.New(
	        math.random((center.x - radius)*100, (center.x + radius)*100) / 100,
			center.y, 
	        math.random((center.z - radius)*100, (center.z + radius)*100) / 100
		)
	
		-- 测试用
		-- local randPos = testPos[(testIndex % 3) + 1]
		-- testIndex = testIndex + 1 

		randPos, ret = owner:GetCombatScene():GetNearestPolyOfPoint(randPos)
		return randPos, ret
	end
	local function excutePatrol()		
		local randPos, ret = getRandPos()
		if not ret then
			return -- 找点失败，可能是没有找到矫正
		end
		if Vector3.InDistance(randPos, owner:GetPosition(), 1) then -- 距离当前点小于1米也重新找
			return
		end
		owner:Moveto(randPos)
		self.destination = randPos
		self.isPatroling = true
		self.lastAction = PatrolAction.eMove
		-- if owner.data.flag == 'test' then
			-- flog('pylDebug', string.format("move to pos:(%.2f, %.2f, %.2f) uid=%s", randPos.x, randPos.y, randPos.z, owner.uid))
		-- end
	end
	if self.isPatroling then
		checkPatrolOver()
	end

	if self.isPatroling or self.isIdle then
		return		
	end	

	if self.lastAction == PatrolAction.eMove --[[ and Vector3.InDistance(owner:GetPosition(), center, radius)]] then
		excuteIdle()
	else
		excutePatrol()
	end
end

-- 固定点走位

function PatrolState:OrdinalMovePatrol(owner, positions)
	if self.nextPositionIndex == -1 then
		self.nextPositionIndex = 1
	end
	local op = owner:GetPosition()
	local np = positions[self.nextPositionIndex]
	local dx = op.x - np.x
	local dz = op.z - np.z
	local dis = math.sqrt(dx * dx + dz * dz)
	if dis < 0.5 then
		owner:SetBornPosition(positions[self.nextPositionIndex])	--注意!!!!!!!!!! 每到一个点,就将其出生位置设置到该点
		if self.nextPositionIndex < #positions then
			self.nextPositionIndex = self.nextPositionIndex + 1
		else
			-- print("end")
			-- owner:StopMove()
		end
	else
		if not owner:isMoving() then
			local nextConfigPos = positions[self.nextPositionIndex]
			local nextPos, ret = owner:GetCombatScene():GetNearestPolyOfPoint(nextConfigPos)
			if not ret then
				flog('error', 'move failed! pos:(' .. nextConfigPos.x .. ',' .. nextConfigPos.y .. ',' .. nextConfigPos.z .. ')')
			else
				owner:Moveto(nextPos)
			end
		end
	end
end


function PatrolState:OnActive( owner, ... )
	State.OnActive(self)

	self.destination = nil
	self.isIdle = false
	self.isPatroling = false
	self.lastAction = PatrolAction.eIdle
end

function PatrolState:Excute(owner, ...)	
	if owner.patrolData.type == PatrolType.A then
		-- 不移动
	elseif owner.patrolData.type == PatrolType.B then
		self:RandPatrol(owner, owner.patrolData.center, owner.patrolData.PatrolRadius, owner.patrolData.PatrolIdleMin, owner.patrolData.PatrolIdleMax)
	elseif owner.patrolData.type == PatrolType.C then
		-- 未定义
	elseif owner.patrolData.type == PatrolType.D then	-- 依次走完所有的节点
		self:OrdinalMovePatrol(owner, owner.patrolData.posData)
	elseif owner.patrolData.type == PatrolType.E then
		if not Vector3.InDistance(owner:GetBornPosition(), owner:GetPosition(), 1) then
			owner:Moveto(owner:GetBornPosition())
		end
	else
		error("未知巡逻类型：" .. owner.patrolData.dataStr)
	end
end

return PatrolState