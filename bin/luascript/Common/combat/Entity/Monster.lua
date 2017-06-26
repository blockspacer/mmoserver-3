---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/26
-- desc： dummy,逻辑层
---------------------------------------------------
local constant = require "Common/constant"
local name_to_attrib_id = constant.PROPERTY_NAME_TO_INDEX
local CreateMonsterBehavior = require "Logic/Entity/Behavior/MonsterBehavior"
local CreateMonsterAttackState = require "Common/combat/State/Monster/MonsterAttackState"
local CreateMonsterPatrolState = require "Common/combat/State/Monster/MonsterPatrolState"
local CreateCharmState = require "Common/combat/State/Skill/CharmState"
local CreateFearState = require "Common/combat/State/Skill/FearState"
local CreateHatredManager = require "Common/combat/Entity/HatredManager"
local CreateDummyAttackState = require "Common/combat/State/Dummy/DummyAttackState" -- 用于竞技场npc
local CreateMonsterDelegate = require "Logic/Entity/Delegate/MonsterDelegate"
require "Common/combat/Entity/Drop"

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end

local fightbaseTable = nil 
local growSkillTable = nil 
local parameterTable = nil
fightbaseTable = GetConfig("common_fight_base")

growSkillTable = GetConfig("growing_skill")
parameterTable = GetConfig('common_parameter_formula')
local Puppet = require "Common/combat/Entity/Puppet"
local Monster = ExtendClass(Puppet)

function Monster:__ctor(scene, data, event_delegate)
	if event_delegate == nil then
		if self.event_delegate then
			self.event_delegate:Destroy()
		end
		self.event_delegate = CreateMonsterDelegate()
		self.event_delegate:SetOwner(self)
	end


	self.entityType = EntityType.Monster
	self.camp_type = data.Camp

	self.LeaveRadius = 0	-- 脱离半径
	self.AttackRadius = 0
	self.name = self:GetName(data)
	self.anger_value = self.data.anger_value or 0
	self.max_anger_value = parameterTable.Parameter[46].Parameter
end

-- 设置行为
function Monster:SetState()
	self.stateManager:AddState(StateType.eAttack, CreateMonsterAttackState(scene, 'attack', StateType.eAttack))
	self.stateManager:AddState(StateType.ePatrol, CreateMonsterPatrolState(scene, 'patrol', StateType.ePatrol))
	self.stateManager:AddState(StateType.eCharm, CreateCharmState(scene, 'charm', StateType.eCharm))
   	self.stateManager:AddState(StateType.eFear, CreateFearState(scene, 'fear', StateType.eFear))
	self.stateManager:GotoState(StateType.ePatrol)
	self.stateManager:StartTick()
end

-- 启动怪物挂机，目前只用于竞技场
function Monster:StartHangup()
	--flog("tmlDebug","Monster:StartHangup")
	self.stateManager:RemoveState(StateType.eAttack)
    self.stateManager:AddState(StateType.eAttack, CreateDummyAttackState(scene, 'attack', StateType.eAttack))
	self:SetControl(true)	
	self.stateManager:GotoState(StateType.eAttack)	
end

-- 怒气值
function Monster:SetAngerValue(value)
	self.anger_value = value
	self.eventManager.Fire('OnCurrentAttributeChanged')
end
function Monster:getRadius(monsterType)
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

function Monster:CreateBehavior()
	return CreateMonsterBehavior(self)
end

function Monster:Born() 	
	Puppet.Born(self)

	self.data.monsterSetting = self:GetMonsterSetting(self.data.MonsterID)
	-- 属性		
	self.patrolData = CreatePatrolData(self)
	if self.patrolData.type == PatrolType.A then
		self.canMove = false
	end

	self.behavior = self:CreateBehavior(self)

	if GRunOnClient then
		self:SetControl(false)
	else
		self:SetControl(true)
	end
	
	self:SetState()

	self.summoned = {}
	-- 技能		
	if self.data.monsterSetting ~= nil then
		-- 技能
		local slot = 0
		local skillids = self.data.monsterSetting.SkillID
		for i, v in ipairs(skillids) do
			if growSkillTable.Skill[v] then
				self.skillManager:AddSkill(slot, tostring(v), 1)
				slot = slot + 1
				-- local logicID = growSkillTable.Skill[v].logicID
				-- if logicID == 1 then -- 普攻
				-- else 	-- 技能
				-- 	self.skillManager:AddSkill(slot, tostring(v), 1)
				-- 	slot = slot + 1
				-- 	-- self.skillManager.skills[slot].common_cd = 1
				-- end
			end
		end
		self.summoned = self.data.monsterSetting.summoned or {}
		self:CreateDefaultBuffs(self.data.monsterSetting.BuffID)


		local monsterType = self.data.monsterSetting.Type
		self.LeaveRadius, self.AttackRadius = self:getRadius(monsterType)
		--仇恨管理
		self.hatredManager = CreateHatredManager(self,self.LeaveRadius,self.AttackRadius,self.data.monsterSetting.AttackType)
	else
		print('monsterSetting data is nil monsterid=' .. self.data.MonsterID)
	end

	self.skillManager:StartTick()




	self:CalcProperty()

	if self:GetElementSceneType() == constant.ENTITY_TYPE_COUNTRY_ARCHER_TOWER then
		self.canMove = false
	end

	-- if self.source == EntitySource.Default then
 --    	self.enabled = false
 --    	self.canBeattack = false
	-- 	self.canBeselect = false
 --    	self:GetTimer().Delay(3, function()
 --    		self.enabled = true
 --        	self.canBeattack = true
	-- 		self.canBeselect = true
 --    	end)
 --    end    
	self.eventManager.Fire('OnBorn')


end

function Monster:GetMonsterType()
	return self.data.monsterSetting.Type
end

function Monster:GetElementSceneType()
	return self.data.sceneType
end


function Monster:HatredChanged()
	Puppet.HatredChanged(self)
    if GRunOnClient then
        if self.data.monsterSetting.AttackType == 0 and self.behavior and self.behavior.nameBar then
            if self:IsInHatredList(MyHeroManager.heroData.entity_id) then
                self.behavior.nameBar.UpdateName('#f93954')
            else
                self.behavior.nameBar.UpdateName('#FFA400')
            end
        end
        if self:IsInHatredList(MyHeroManager.heroData.entity_id) then
            self.behavior:ShowBar()
        end
    end
end

function Monster:OnDied(killer)
	Puppet.OnDied(self, killer)
end

function Monster:tryEscapeFightState(pass_time)
	if self:IsHatredListEmpty() then
		return true
	else
		return false
	end
end

function Monster:GetBornPosition()
	if not GRunOnClient then
		if self.data.Para2~=nil and self.data.Para2 ~= '0' and self.data.Para2 ~= '' and self.random_generated == nil then
			self.random_generated = true
			local new_pos = GetRandomBornPos(
				self:GetCombatScene(), 
				Vector3.New(self.data.posX, self.data.posY, self.data.posZ),
				tonumber(self.data.Para2))
			self.data.posX = new_pos.x
			self.data.posY = new_pos.y
			self.data.posZ = new_pos.z
		end
	end
	return Puppet.GetBornPosition(self)
end

function Monster:GetClientNeedInfo()
	local info = table.copy(self.data)
    info.posX = nil
    info.posY = nil
    info.posZ = nil
   	info.monsterSetting = nil
	info.property = nil 
	info.Scale = math.ceil(info.Scale*100)
	info.Para2 = info.Para2
	if info.Para1 and info.Para1 ~= '' then
		info.configID = tonumber(info.Para1)
	end
	info.entity_type = self.entityType
	local sync_data = self:GetSyncAttribute()
    table.update(info, sync_data)
    info.buffs = self.skillManager:GetPublicBuffInfo()
	return msg_pack.pack(info)
end

function Monster:SetLevel(level)
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

function Monster:OnFightStateChanged()
	if not self.behavior then
		return
	end
	if self.fightState == FightState.Normal then
		if not GRunOnClient and self.hp > 0 then
			self:SetHp(self.hp_max())
			self:SetMp(self.mp_max())
			self.skillManager:ClearBuff()
		end
	end	
end

return Monster
