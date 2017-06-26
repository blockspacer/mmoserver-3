---------------------------------------------------
-- auth： panyinglong
-- date： 2016/10/31
-- desc： 副本里的npc
---------------------------------------------------
local Vector3 = Vector3

local CreateDungeonNPCBehavior = require "Logic/Entity/Behavior/DungeonNPCBehavior"
require "Common/combat/Entity/Puppet"
local NPCPatrolState = require "Common/combat/State/NPC/NPCPatrolState"
local CreateNPCAttackState = require "Common/combat/State/NPC/NPCAttackState"
local CreateGotoState = require "Common/combat/State/NPC/GotoState"
local CreatePatrolState = require "Common/combat/State/PatrolState"
local CreateDungeonNPCDelegate = require "Logic/Entity/Delegate/DungeonNPCDelegate"
local CreateHatredManager = require "Common/combat/Entity/HatredManager"
local CreateCharmState = require "Common/combat/State/Skill/CharmState"
local CreateFearState = require "Common/combat/State/Skill/FearState"

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end


-------------------------- npc 任务 ------------------------------
local dungeonTable = GetConfig("challenge_main_dungeon") 
local growSkillTable = GetConfig("growing_skill")
local fightbaseTable = GetConfig("common_fight_base")

NPCTask = {
	None = 0,
	Escort = 1, -- 护送
	Defend = 2, -- 守卫
};
function CreateTask()
	local self = CreateObject()
	self.taskType = NPCTask.None
	self.isShowHalfHP = false
	self.isShowLowHP = false
	return self
end

-- 护送
function CreateEscortTask(para)
	local self = CreateTask()
	self.data = para
	self.taskType = NPCTask.Escort

	self.radius = 0
	self.positions = {}
	self.current = nil	
	self.isReached = false
	self.waitTime = dungeonTable.Parameter[13].Value[1]/1000


	local create = function()
		local strArr = string.split(self.data, '|')
		self.radius = strArr[1]/1
		for i = 2, #strArr do
			local itemStrArr = string.split(strArr[i], '*')
			local pos = Vector3.New(itemStrArr[1]/1, itemStrArr[2]/1, itemStrArr[3]/1)
			table.insert(self.positions, pos)
		end
		self.current = 0
	end

	create()
	return self
end
function CreateDefendTask(para)
	local self = CreateTask()
	self.taskType = NPCTask.Defend
	return self
end
-------------------------------------------------------------------------
local Puppet = require "Common/combat/Entity/Puppet"
local DungeonNPC = ExtendClass(Puppet)

function DungeonNPC:__ctor(scene, data, event_delegate)

	if event_delegate == nil then
		if self.event_delegate then
			self.event_delegate:Destroy()
		end
		self.event_delegate = CreateDungeonNPCDelegate()
		self.event_delegate:SetOwner(self)
	end

	self.entityType = EntityType.NPC
	self.camp_type = data.Camp

	self.name = self:GetName(data)
	
	self.behavior = CreateDungeonNPCBehavior(self)

	self.npcConfig = nil
	self.taskData = nil
	self.patrolData = nil
end

function DungeonNPC:getRadius(monsterType)
	local defaultLeaveRadius = 0
	local defaultAttackRadius = 0
	local curSceneType = self:GetSceneType()
	for k, v in pairs(fightbaseTable.Type) do
		if v.SceneType == -1 and v.type == monsterType then
			defaultLeaveRadius = v.off/100
			defaultAttackRadius = v.scope/100
		end
		if v.SceneType == curSceneType and v.type == monsterType then
			return (v.off/100), (v.scope/100)
		end
	end
	if defaultLeaveRadius == 0 or defaultAttackRadius == 0 then
		error('怪物radius配置出错')
	end
	return defaultLeaveRadius,defaultAttackRadius
end

function DungeonNPC:Born()
	Puppet.Born(self)

	self.skillManager:StartTick()
	
	local npcScheme = GetConfig("common_npc") 
	local _CreateTask = function()
		local npcId = self.data.Para1 / 1

		if not npcScheme.NPC[npcId] then
			print("error!!! not found npc id=" .. npcId)
			self.taskData = CreateTask(data)
			return 
		end
		self.npcConfig = table.copy(npcScheme.NPC[npcId])
		local npcFuncList = self.npcConfig.Function
		if #npcFuncList ~= 1 then
			error('error dungeon npc func type')
		end
		local npcFunc = npcScheme.NPCfunction[npcFuncList[1]]
		if npcFunc.function1 == 5 then
			self.taskData = CreateEscortTask(self.data.Para2)
		elseif npcFunc.function1 == 6 then 
			self.taskData = CreateDefendTask()
		else
			error('error dungeon npc func type')
		end
	end

	if GRunOnClient then
		self:SetControl(false)
	else
		self:SetControl(true)
	end

	local _Create = function()
		self.patrolData = CreatePatrolData(self)
		if self.taskData.taskType == NPCTask.Escort then
		    self.stateManager:AddState(StateType.ePatrol, NPCPatrolState.CreateEscortPatrolState(scene, 'patrol', StateType.ePatrol))
		    self.stateManager:AddState(StateType.eAttack, CreateNPCAttackState(scene, 'attack', StateType.eAttack))
	    	self.stateManager:AddState(StateType.eGoto, CreateGotoState(scene, 'goto', StateType.eGoto))
	    elseif self.taskData.taskType == NPCTask.Defend then
		    self.stateManager:AddState(StateType.ePatrol, NPCPatrolState.CreateDefendPatrolState(scene, 'patrol', StateType.ePatrol))	    	
		else
			self.stateManager:AddState(StateType.ePatrol, CreatePatrolState(scene, 'patrol', StateType.ePatrol))
	    	self.stateManager:AddState(StateType.eGoto, CreateGotoState(scene, 'goto', StateType.eGoto))
		end
		self.stateManager:AddState(StateType.eCharm, CreateCharmState(scene, 'charm', StateType.eCharm))
	   	self.stateManager:AddState(StateType.eFear, CreateFearState(scene, 'fear', StateType.eFear))
		self.stateManager:GotoState(StateType.ePatrol)
		self.summoned = {}
		if self.data.monsterSetting ~= nil then
			-- 技能
			local slot = 0
			local skillids = self.data.monsterSetting.SkillID
			for i, v in ipairs(skillids) do
				if growSkillTable.Skill[v] then
					self.skillManager:AddSkill(slot, tostring(v), 1)
					slot = slot + 1
				end
			end
			self.summoned = self.data.monsterSetting.summoned or {}
			self:CreateDefaultBuffs(self.data.monsterSetting.BuffID)

			local monsterType = self.data.monsterSetting.Type
			self.LeaveRadius, self.AttackRadius = self:getRadius(monsterType)
			--仇恨管理
			self.hatredManager = CreateHatredManager(self, self.LeaveRadius, self.AttackRadius, self.data.monsterSetting.AttackType)
		else
			print('monsterSetting data is nil monsterid=' .. self.data.MonsterID)
		end
		self.stateManager:StartTick()
		self:CalcProperty()
	end 

	_CreateTask()
	_Create()		
	self.eventManager.Fire('OnBorn')
end

function DungeonNPC:SetLevel(level)
	Puppet.SetLevel(self, level)

	if not GRunOnClient then
		local property = self:GetEntityManager().getMonsterPropery(
		{
			Level = self.level,
			Power = self.data.Power,
			Type  = self.data.Type,	
		}, EntityType.Monster)

		table.update(self.baseProperty, property)
		table.update(self.property, property)
		self:SetHp(self.hp_max())
		self:SetMp(self.mp_max())
	end
	self:NeedCalcProperty()
end

function DungeonNPC:OnHpChanged(hp)	
	Puppet.OnHpChanged(self, hp)
end

function DungeonNPC:OnReceiveBroadcastUnitMsg(event, data)
	if GRunOnClient then
		if event == 'Goto' then
			self.behavior.chatBar.PushChat(uiText(1135105), 2)	
		elseif event == 'Fight' then
			self.behavior.chatBar.PushChat(uiText(1135104), 2)	
		elseif event == 'NewBoss' then
			self.behavior.chatBar.PushChat(uiText(1135106), 2)	
		end
	end	
end

function DungeonNPC:GetClientNeedInfo()
	local info = table.copy(self.data)
    info.posX = nil
    info.posY = nil
    info.posZ = nil
   	info.monsterSetting = nil
	info.property = nil 
	info.Scale = math.ceil(info.Scale*100)
	info.Para2 = info.Para2 --math.ceil(info.Para2*100)
	info.entity_type = self.entityType
	local sync_data = self:GetSyncAttribute()
    table.update(info, sync_data)
    info.buffs = self.skillManager:GetPublicBuffInfo()
	return msg_pack.pack(info)
end

return DungeonNPC
