---------------------------------------------------
-- auth： panyinglong
-- date： 2016/10/20
-- desc： command
---------------------------------------------------
require "Common/basic/SceneObject"

CommandType = {
	eMovePos = 1,
	eMoveDir = 2,
	eSkill = 3,
	eSkillToSky = 4,
	eSkillSync = 5,
	eMoveSync = 6,
	eBehit = 7,
	eStopMoveSync = 8,
	eStopMove = 9,
	eRotate = 10,
	eSetPosition = 11,
}

function CreateCommand(owner, ...)
	local self = CreateObject()
	self.owner = owner
    self.args = {...}
    self.isMoveCmd = false
    self.isSkillCmd = false
    self.onExcute = function()
    	-- TODO
	end
	self.isFinished = function()
		return true
	end
    return self
end

function CreateMovePosCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eMovePos
    self.isMoveCmd = true
    self.onExcute = function()
		if owner:CanMove() then
			local pos = self.args[1]
			local stopDistance = self.args[2]
			local onArrived = self.args[3]
			local callbackArgs = self.args[4]
			owner.behavior:Moveto(pos)
			owner:stopListerMoveto()
			owner.movetoArgs = callbackArgs
			owner.onMovetoCallback = onArrived
			owner.destionation = pos
			owner.stopDistance = stopDistance
			owner:startListenMoveto()
			owner.eventManager.Fire('OnMove', pos)
		end
	end
	self.isFinished = function()
		if owner:isMoving() then
			return false
		else
			return true
		end
	end
	return self
end

function CreateMoveDirCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eMoveDir
    self.isMoveCmd = true
    self.onExcute = function()
		if owner:CanMove() then
			owner:stopListerMoveto()
			local dir = self.args[1]
			owner.behavior:MoveDir(dir)
			owner.eventManager.Fire('OnMove', dir)
		end
	end
	return self
end

function CreateMoveSyncCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eMoveSync
    self.isMoveCmd = true
    self.onExcute = function()
		owner:stopListerMoveto()
		local pos = self.args[1]
		local speed = self.args[2]
		local rotation = self.args[3]
		local delaytime = self.args[4]

		owner.behavior:UpdateMoveto(pos, speed, rotation, delaytime)
	end
	self.isFinished = function()
		-- local des = curCommand.args[1]
		-- if Vector3.InDistance(owner:GetPosition(), des, 0.5) or not owner:isMoving() then
		-- 	return true
		-- else
		-- 	return false
		-- end
		return true
	end
	return self
end

function CreateSkillCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eSkill
    self.isSkillCmd = true
    self.onExcute = function()
    	if owner.skillManager:IsLimitAttack() then
			return false
		end
		if not owner.canAttack then
			return false
		end
		local slot_id = self.args[1]
		-- 禁止技能的时候，不能释放除了普攻之外的技能
		if slot_id ~= SlotIndex.Slot_Attack and owner.skillManager:IsLimitSkill() then
			return false
		end
		local enemy = self.args[2]
		if enemy then
			if enemy:IsDied() or enemy:IsDestroy() then
				return false
			end
			if not enemy.canBeattack then
				return false
			end
			owner:LookAt(enemy:GetPosition())
			owner.target = enemy
		end
        owner:StopMoveImmediately()
        return owner.skillManager:CastSkill(slot_id, enemy)
	end
	self.isFinished = function()
		if owner.skillManager:IsOnCommonCD() then
			return false
		else
			return true
		end
	end
	return self
end

function CreateSkillToSkyCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eSkillToSky
    self.isSkillCmd = true
    self.onExcute = function()
    	if not owner.canAttack then
			return
		end
		local slot_id = self.args[1]
        owner:StopMoveImmediately()
		owner.skillManager:CastSkillToSky(slot_id)
	end
	self.isFinished = function()
		if owner.skillManager:IsOnCommonCD() then
			return false
		else
			return true
		end
	end
	return self
end

function CreateSkillSyncCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eSkillSync
    self.isSkillCmd = true
	self.onExcute = function()
    	local slot_id = self.args[1]
		local enemy = self.args[2]
		if enemy and not enemy:IsDestroy() then
			owner:LookAt(enemy:GetPosition())
		end
        owner:StopMoveImmediately()
        owner.skillManager:CastSkillStart(slot_id, {target = enemy})
	end
	self.isFinished = function()
		-- if owner.skillManager:IsOnCommonCD() then
		-- 	return false
		-- else
		-- 	return true
		-- end
		return true
	end
	return self
end

function CreateBehitCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eBehit
    self.onExcute = function()
		local curHP = self.args[1]
		local num = self.args[2]
		local attacker = self.args[3]
		local spellId = self.args[4]
		local evtType = self.args[5]
        owner:SetHp(curHP)
        owner:TakeDamage(num, attacker, spellId, evtType)
	end
	return self
end

function CreateStopMoveSyncCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eStopMoveSync
    self.onExcute = function()
		local pos = self.args[1]
		local rotation = self.args[2]
		owner.behavior:StopAt(pos, rotation)
	end
	self.isFinished = function()
		-- local des = curCommand.args[1]
		-- if Vector3.InDistance(owner:GetPosition(), des, 0.5) or not owner:isMoving() then
		-- 	return true
		-- else
		-- 	return false
		-- end
		return true
	end
	return self
end

function CreateStopMoveCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eStopMove
    self.onExcute = function()
		owner:stopListerMoveto()
		owner.behavior:StopMove()
	end
	return self
end

function CreateRotateCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eRotate
    self.onExcute = function()
    	local rotation = self.args[1]
    	owner.behavior:SetRotation(rotation)
	end
	return self
end

function CreateSetPositionCommand(owner, ...)
	local self = CreateCommand(owner, ...)
	self.type = CommandType.eSetPosition
    self.onExcute = function()
		owner:stopListerMoveto()
    	local pos = self.args[1]
		-- owner:SetNavMesh(false)
    	owner.behavior:SetPosition(pos)
		-- owner:SetNavMesh(true)
	end
	return self
end

function CreateCommandManager(owner, scene)
	local self = CreateSceneObject(scene)
	self.cmdCapacity = 3

	local lastCmdTime = os.clock()

	local curCommand = nil
	local timer = nil
	local commandList = {}

	local stopTimer = function()
		if timer then
			self.GetTimer().Remove(timer)
		end
		timer = nil
	end

	local removeCurCommand = function()
		if curCommand then
			curCommand = nil
			table.remove(commandList, 1)
		end
	end
	local tick = function()
		if not owner or owner:IsDestroy() then
			self.Clear()
			return
		end
		if not owner.enabled then
			return
		end
		if not curCommand then
			if #commandList > 0 then
				curCommand = commandList[1]
				curCommand.onExcute()
			end
		end
		if curCommand and curCommand.isFinished() then
			removeCurCommand()
		end
	end
	local startTimer = function()
		if not timer then
			timer = self.GetTimer().Repeat(0.01, tick)
		end
	end
	self.PushBack = function(cmd)
		if cmd.isMoveCmd then
			if curCommand and curCommand.isMoveCmd then
				removeCurCommand()
			end
		elseif cmd.isSkillCmd then
			if curCommand and curCommand.isMoveCmd and owner:IsControl() then -- 移动时放技能，要先stop
				removeCurCommand()
			end
		end
		if #commandList >= self.cmdCapacity and self.cmdCapacity >= 2 then 
			table.remove(commandList, #commandList)
		end
		table.insert(commandList, cmd)		
	end

	self.Excute = function(cmd)
		if not cmd or not cmd.type then
			return
		end
		if cmd.type == CommandType.eMovePos or 
			cmd.type == CommandType.eMoveDir or 
			cmd.type == CommandType.eSkill or 
			cmd.type == CommandType.eSkillToSky then
				lastCmdTime = os.clock()
		end
		if owner:IsControl() then -- 如果是自己控制, 则将指令添加到末尾
			self.PushBack(cmd)
			return false
		else -- 否则为同步指令, 立即执行
			local res = cmd.onExcute()
			return true, res
		end
	end
	self.Stop = function()
		stopTimer()
		commandList = {}
	end
	self.Start = function()
		startTimer()
	end

	self.Clear = function()
		commandList = {}
		curCommand = nil
	end
	self.GetIdleTime = function()
		return os.clock() - lastCmdTime
	end

	self.Start()
	return self
end