---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/26
-- desc： dummy,逻辑层
---------------------------------------------------

local CreateDummyBehavior = require "Logic/Entity/Behavior/DummyBehavior"
local CreateCharmState = require "Common/combat/State/Skill/CharmState"
local CreateFearState = require "Common/combat/State/Skill/FearState"
local CreateDummyAttackState = require "Common/combat/State/Dummy/DummyAttackState"
local CreateDummyDelegate = require "Logic/Entity/Delegate/DummyDelegate"
if GRunOnClient then
require "Logic/LowFly/LowFlyManager"
end
local const = require "Common/constant"

local common_base_fight = GetConfig("common_fight_base")
local PlayerEscapeTime = GetConfig("common_fight_base").Parameter[59].Value

local Puppet = require "Common/combat/Entity/Puppet"
local Dummy = ExtendClass(Puppet)

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end

function Dummy:__ctor(scene, data, event_delegate)
	if event_delegate == nil then
		if self.event_delegate then
			self.event_delegate:Destroy()
		end
		self.event_delegate = CreateDummyDelegate()
		self.event_delegate:SetOwner(self)
	end

	self.fightState = FightState.Normal

	self.entityType = EntityType.Dummy 
	if data.country == const.COUNTRY_ID.jiuli then
		self.camp_type = const.CAMP_TYPE.JIULI
	else
		self.camp_type = const.CAMP_TYPE.YANHUANG
	end
	self.isOnFly = false

	self.appearance_1 = data.appearance_1
	self.appearance_2 = data.appearance_2
	self.appearance_3 = data.appearance_3
end

function Dummy:GetName()
    return self.name
end

function Dummy:SetAppearance(index, value)
	self['appearance_'..index] = value
	self.eventManager.Fire('OnCurrentAttributeChanged')
end
	
function Dummy:SetFly(b)
	self.isOnFly = b
end
function Dummy:GetFly()
	return self.isOnFly 
end
	
function Dummy:CreateBehavior()
	return CreateDummyBehavior(self)
end

function Dummy:Born()		 
	Puppet.Born(self)
	
	self.name = self.data.actor_name 
	self.behavior = self:CreateBehavior()
	
    
	self.skillManager:StartTick()

	local config = GetConfig("growing_skill")
	local tmp1 = config.SkillMoves[self.data.vocation*1000]
	if tmp1 then
		local tmp2 = tmp1.SkillID[1]
		self.skillManager:AddSkill(SlotIndex.Slot_Attack, tostring(tmp2), 1)
	else
		self.skillManager:AddSkill(SlotIndex.Slot_Attack, '101', 1)
	end

	self.skillManager:AddSkill(SlotIndex.Slot_Skill5, '999', 5)
	self:RefreshSkills()

	self:CalcProperty()

    self.stateManager:AddState(StateType.eAttack, CreateDummyAttackState(scene, 'attack', StateType.eAttack))
    self.stateManager:AddState(StateType.eCharm, CreateCharmState(scene, 'charm', StateType.eCharm))
    self.stateManager:AddState(StateType.eFear, CreateFearState(scene, 'fear', StateType.eFear))
	self.stateManager:StartTick()

    if GRunOnClient then
   		-- 初始化pk信息
		PKManager.requestGetPKInfo(self.uid)
	end


	--self.hp = self.data.hp or self.base_hp_max()
	--self.mp = self.data.mp or self.base_mp_max()


	if GRunOnClient then
		self.lowFlyManager = CreateLowFlyManager(self, scene)
		self.behavior:SetOnFall(self.lowFlyManager.OnFall) 
		self.behavior:SetOnColliderHit(self.lowFlyManager.ColliderHit) 
	end

	self:SetControl(false)
	self.eventManager.Fire('OnBorn')

	-- 死亡状态
	if self.hp <= 0 then
		self.isDied = true
		self:StopWorking()
		self:Besoul(nil)
	end
end 

function Dummy:UpdatePkInfo(pkdata)
	if GRunOnClient then
		if SceneManager.currentSceneType == const.SCENE_TYPE.ARENA and self.uid ~= MyHeroManager.heroData.entity_id then -- 竞技场一律红
			self.behavior:SetNameColor(LuaUIUtil.DummyNameColor.Red)
		else
			local color = pkdata.pkColor
			if pkdata.isAttackHero then
				color = PKColor.Darkgreen
			end
			
			if color == PKColor.Green then
				self.behavior:SetNameColor(LuaUIUtil.DummyNameColor.Green)
			elseif color == PKColor.Yellow then
				self.behavior:SetNameColor(LuaUIUtil.DummyNameColor.Yellow)
			elseif color == PKColor.Red then
				self.behavior:SetNameColor(LuaUIUtil.DummyNameColor.Red)
			elseif color == PKColor.Darkgreen then
				self.behavior:SetNameColor(LuaUIUtil.DummyNameColor.Darkgreen)
			end
		end
	end
end

	-- 挂机
function Dummy:StartHangup()
	self:SetControl(true)	
	self.stateManager:GotoState(StateType.eAttack)
	
end
function Dummy:StopHangup()
	self:SetControl(false)
	self.stateManager:Rollback()	
end

function Dummy:OnTakeDamage(damage, attacker, spell_name, event_type)		
	Puppet.OnTakeDamage(self, damage, attacker, spell_name, event_type)
	
	if not self.target or self.target:IsDied() or self.target:IsDestroy() then
		self.target = attacker
	end		
end

function Dummy:CanMove()
	if GRunOnClient then
		if self.lowFlyManager.IsShowLocus() then
			return false
		end
	end
	return Puppet.CanMove(self)
end
	
function Dummy:OnBeTarget(attacker)
	Puppet.OnBeTarget(self, attacker)

	if not attacker or attacker:IsDied() or attacker:IsDestroy() then		
		return
	end
	if not self.target or self.target:IsDied() or self.target:IsDestroy() then
		self.target = attacker
	end
end

function Dummy:tryEscapeFightState()
	local res = Puppet.tryEscapeFightState(self)
	if res == false then
		return false
	end

	if self.pvp_start_fight_time then
		local pass_time = self:GetOSTime() - self.pvp_start_fight_time
		if pass_time < PlayerEscapeTime then
			return false
		end
	end 

	if self:GetEntityManager().IsInAnyHatredList(self.uid) == true then
        return false
    end

    local pets = self:GetPets()
    for _, pet in pairs(pets) do
    	if self:GetEntityManager().IsInAnyHatredList(pet.uid) == true then
            return  false
        end
    end

    return true
end

function Dummy:startFightStateTimer(source)
	if source == nil then return end
	if source.entityType == EntityType.Dummy then
		self.pvp_start_fight_time = self:GetOSTime()
	end
	Puppet.startFightStateTimer(self, source)
end

function Dummy:OnFightStateChanged()
	if not self.behavior then
		return
	end
	if self.fightState == FightState.Normal then
		self.behavior:SetDefaultAnimation('NormalStandby')
		if self.behavior:GetCurrentAnim() == 'BattleStandby' then
			self.behavior:UpdateBehavior('NormalStandby')
		end
	else
		self.behavior:SetDefaultAnimation('BattleStandby')
		if self.behavior:GetCurrentAnim() == 'NormalStandby' then
			self.behavior:UpdateBehavior('BattleStandby')
		end
	end	
end

function Dummy:RefreshSkills()
	if self.data.skill_plan then
		local skills = self.data.skill_plan[self.data.cur_plan]
		if skills == nil then
			skills = {}
		end 
		for i = 1, 4 do 
			if skills[i] then
				self.skillManager:AddSkill(i, tostring(skills[i]), self.data.skill_level[i])
			else
				self.skillManager:RemoveSkill(i)
			end
		end
	end
end

function Dummy:Resurrect(data)
	self:SetHp(self.hp_max())
	self:SetMp(self.mp_max())
	self.skillManager:StartTick()
	self:CalcProperty()

	Puppet.Resurrect(self, data)
end
	
function Dummy:OnBesoul(killer)
	if self.behavior then
		if GRunOnClient and SceneManager.currentFightType == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then -- 排位竞技场时
	    	self:GetEntityManager().DestroyPuppet(self.uid)
	    else
			self.behavior:SetDefaultAnimation('NormalStandby')
			self.behavior:SetModel(self.behavior.soulPrefab, 1)	
			local speed = common_base_fight.Parameter[41].Value
			self.behavior:SetSpeed(speed)
			self.commandManager.Start()
		end
	end
end

function Dummy:OnResurrect()
	if self.behavior then
		self.behavior:SetModel(self.behavior.defaultPrefab, self.behavior.defaultScale)	
		self.behavior:createBar()
		self.behavior:SetSpeed(self.move_speed())
		self:StopMove()
	end		
end

function Dummy:IsEnemy(unit)
	if not GRunOnClient then
		if  unit.entityType == EntityType.Dummy then
			if self.data.server_object:is_attackable(unit.uid) then
				return true
			end
		elseif unit.entityType == EntityType.Pet then
			if unit.owner and self.data.server_object:is_attackable(unit.owner.uid) then
				return true
			end
		end
	end

	return Puppet.IsEnemy(self, unit)
end

function Dummy:IsAlly(unit)
	if not GRunOnClient then
		if unit.entityType == EntityType.Dummy then
			if self.data.server_object:is_attackable(unit.uid) then
				return false
			end
		elseif unit.entityType == EntityType.Pet then
			if unit.owner and self.data.server_object:is_attackable(unit.owner.uid) then
				return false
			end
		end
	end

	return Puppet.IsAlly(self, unit)
end

function Dummy:GetPets()
	return self:GetEntityManager().QueryPuppets(function(p)
		if p.entityType == EntityType.Pet and p.data.owner_id == self.uid then
			return true
		end
		return false
	end)
end

function Dummy:GetClientNeedInfo()
	local data = {}
    data.actor_id = self.data.actor_id
    data.actor_name = self.data.actor_name
    data.level = self.data.level
    data.vocation = self.data.vocation
    data.country = self.data.country
    data.sex = self.data.sex
    data.entity_type = self.entityType
    data.entity_id = self.data.entity_id
    data.team_id = self.data.team_id
    data.scene_id = self.data.scene_id
    data.faction_id = self.data.faction_id
    local sync_data = self:GetSyncAttribute()
    table.update(data, sync_data)
    data.buffs = self.skillManager:GetPublicBuffInfo()
	return msg_pack.pack(data)
end

function Dummy:SetDaddy(flag)
	self.this_is_daddy = flag
end

function Dummy:OnDied(killer)
    Puppet.OnDied(self, killer)
    if GRunOnClient then
	    if SceneManager.currentFightType == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
	        Game.SetGameSpeed(2, 0.2)
	    end
	end
end

return Dummy
