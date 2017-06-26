---------------------------------------------------
-- auth： yanwei
-- date： 2016/2/10
-- desc： 挂机前往下一个目标点
---------------------------------------------------
local PatrolState = require "Common/combat/State/PatrolState"
local HookPatrolState = ExtendClass(PatrolState)
local const = require "Common/constant"

local currentDungeonManager = nil
local paths = nil
local initPathData = function()
	if not currentDungeonManager then
		if SceneManager.currentFightType == const.FIGHT_SERVER_TYPE.MAIN_DUNGEON then 			--主线副本
			currentDungeonManager = MainDungeonManager
		elseif SceneManager.currentFightType == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then  		--组队副本
			currentDungeonManager = TeamDungeonManager
		elseif SceneManager.currentFightType == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then  		--任务副本
			currentDungeonManager = TaskDungeonManager
		else
			error('不是副本，不能添加指路标示')
		end
	end
	paths = currentDungeonManager.getDungeonPaths()
	if not paths or #paths == 0 then
		error('没有找到副本path')
	end
end

function HookPatrolState:__ctor(scene, name, stateType)
	if SceneManager.IsOnDungeonScene() then
		initPathData()
	end
end

function HookPatrolState:MovePatrol(owner, positions)
	if currentDungeonManager.nextPositionIndex == -1 then
		currentDungeonManager.nextPositionIndex = 1
	end
	if owner:isMoving() then
		return
	end
	if #paths > 0 and currentDungeonManager.nextPositionIndex <= #paths then
		local pos = positions[currentDungeonManager.nextPositionIndex]
        owner:Moveto(pos)
	elseif currentDungeonManager.nextPositionIndex > #paths then
	   owner:StopMove()
	   --SceneManager.GetEntityManager().hero.stateManager:StopTick()
	end
end

function HookPatrolState:Excute(owner, ...)
	if TargetManager.GetHookMonster() ~= nil then	
		owner.stateManager:GotoState(StateType.eHookAttack)
		return
	end
	
	if next(paths) == nil then
	   return
	end
    self:MovePatrol(owner,paths)

end

return HookPatrolState
