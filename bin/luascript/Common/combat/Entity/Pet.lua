---------------------------------------------------
-- auth： 张增
-- date： 2016/9/18
-- desc： pet,逻辑层
---------------------------------------------------
local Vector3 = Vector3

local CreatePetBehavior = require "Logic/Entity/Behavior/PetBehavior"
local CreatePetAttackState = require "Common/combat/State/Pet/PetAttackState"
local CreatePetFollowState = require "Common/combat/State/Pet/PetFollowState"
local CreateCharmState = require "Common/combat/State/Skill/CharmState"
local CreateFearState = require "Common/combat/State/Skill/FearState"
local constant = require "Common/constant"
local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end

local function isHeroPet(owner_id)
	if GRunOnClient then
		return SceneManager.GetEntityManager().hero and SceneManager.GetEntityManager().hero.uid == owner_id
	else
		return false
	end
end

local function getOwner(scene, data)
	-- pet owner ---
	local entity_mgr = scene:GetEntityManager()
	local owner = entity_mgr.GetPuppet(data.owner_id)
	if not owner then
		print('not found pet.owner uid=' .. data.owner_id)
	end
	return owner
end

local Puppet = require "Common/combat/Entity/Puppet"
local Pet = ExtendClass(Puppet)

function Pet:__ctor(scene, data, event_delegate)
	local petOwner = getOwner(scene, data)
	if petOwner and self:IsHeroPet() then
		data.posX = petOwner:GetPosition().x
		data.posY = petOwner:GetPosition().y
		data.posZ = petOwner:GetPosition().z
		self.camp_type = petOwner.camp_type
	end

	self.entityType = EntityType.Pet
	self.owner = petOwner
    self.level = self.data.pet_level
	self.index = self.data.fight_index or 1
	self.name = self:GetName(GetConfig('growing_pet').Attribute[data.pet_id])

	self.resuTime = 0
	self.deadTime = 0
end

function Pet:bindUI()
	-- 绑定UI
	if GRunOnClient then
		-- 是否是英雄的pet
		if isHeroPet(self.data.owner_id) and self.index and self.index > 0 then
			-- self:SetNavMesh(self.owner:GetNavMesh())
			if UIManager.GetCtrl(ViewAssets.MainLandUI).isLoaded then
				UIManager.GetCtrl(ViewAssets.MainLandUI).petGroupUI.bindPet(self)
			end
		end
	end
end

function Pet:Born()	
	Puppet.Born(self)
	self.behavior = CreatePetBehavior(self)
	--local modelId = GetConfig('growing_pet').Attribute[self.data.pet_id].ModelID   -- 根据pet_id,从宠物养成表中获取宠物modelId
    --self.behavior:BindEffectByModelId(modelId)
	-- 技能
	local attackLength = GetConfig('growing_pet').Attribute[self.data.pet_id].Attack
	self.skillManager:AddSkill(SlotIndex.Slot_Attack, tostring(attackLength), 1)

	self:UpdatePetSkill(self.data) 		--增加宠物主动技能
	self.skillManager:StartTick()
	
	if GRunOnClient and self.owner then
		self:SetControl(self.owner:IsControl())
		self:SetSyncPosition(self.owner:GetSyncPosition())
	else
		self:SetControl(false)
		self:SetSyncPosition(false)
	end
	
	if self:IsHeroPet() then
	    self:SetState()
		self:SetPosition(self:CalculatePosition())
	end
	self:CalcProperty()

	self.eventManager.Fire('OnBorn')



	self:bindUI()
end

function Pet:SetState()
	self.stateManager:AddState(StateType.eFollow, CreatePetFollowState(scene, 'follow', StateType.eFollow))
	self.stateManager:AddState(StateType.eAttack, CreatePetAttackState(scene, 'attack', StateType.eAttack))
	self.stateManager:AddState(StateType.eCharm, CreateCharmState(scene, 'charm', StateType.eCharm))
	self.stateManager:AddState(StateType.eFear, CreateFearState(scene, 'fear', StateType.eFear))
	self.stateManager:GotoState(StateType.eFollow)
	self.stateManager:StartTick()
end
	
function Pet:UpdatePetSkill(data)   	--跟新宠物主动技能
	
	local skillLevel
	local skillID
	local skillInfo = data.skill_info
	for k, v in pairs(skillInfo) do
	
		local skillType = v[3]
		if skillType == 1 then  --宠物主动技能，有且只有一个
		
			skillLevel = v[2]
			skillID = v[1]
			break
		end
	end
	
	self.skillManager:AddSkill(SlotIndex.Slot_Skill1, tostring(skillID), skillLevel or 1)
end

function Pet:CalculatePosition(herPos)	
	if not self.owner or not self:IsHeroPet() then
		return
	end
	
	if not herPos then
		herPos = self.owner:GetPosition()
	end
    local dirFlag = -1
    if self.index == 1 then    --dir left    
        dirFlag = -1
    else  --dir right   
        dirFlag = 1
    end        
    local nVect3 = Vector3.New(dirFlag * (0.666667) * herPos.z, 0, 0)
    local lVector3 = nVect3 + Vector3.New(0, 0, herPos.z)
    local rVector3 = Vector3.New(dirFlag, 0, 0) + Vector3.New(0, 0, 1.5)
    local distanceVect3 = lVector3 - rVector3

    local petPos = distanceVect3 + Vector3.New(herPos.x + (0 - dirFlag) * (0.666667) * herPos.z, 0, 0)
    petPos = self.owner:GetRotation() * (petPos - herPos)
    petPos = petPos + herPos 
    petPos.y = herPos.y --之前计算不考虑y坐标，现在把y修正为英雄的y值
    return petPos
end

function Pet:OnBeTarget(attacker)	
	if not attacker or attacker:IsDied() or attacker:IsDestroy() then		
		return
	end
end

	-- 是否属于当前客户端的英雄
function Pet:IsHeroPet()
	return isHeroPet(self.data.owner_id)
end


function Pet:Resurrect(data)
	self.behavior = CreatePetBehavior(self)		
	self.skillManager:StartTick()
	
	if self:IsHeroPet() then
		self.stateManager:GotoState(StateType.eFollow)
		self.stateManager:StartTick()
		self:SetPosition(self:CalculatePosition())
	end
	self:CalcProperty()

	self:bindUI()

	data.posX = nil
	data.posY = nil
	data.posZ = nil
	Puppet.Resurrect(self, data)
end

function Pet:OnBesoul(killer)
	Puppet.OnBesoul(self, killer)
end

function Pet:IsEnemy(unit)
	if self.owner then
		return self.owner:IsEnemy(unit)
	end
	return false
end

function Pet:IsAlly(unit)
	if self.owner then
		return self.owner:IsAlly(unit)
	end
	return false
end

function Pet:tryEscapeFightState()
	local res = Puppet.tryEscapeFightState(self)
	if res == false then
		return false
	end

	if self.owner and self.owner.fightState == FightState.Fight then
		return false
	else
    	return true
    end
end

function Pet:startFightStateTimer(source)
	Puppet.startFightStateTimer(self, source)
	if source and source.entityType == EntityType.Dummy then
		if self.owner then
			self.owner:startFightStateTimer(source)
		end
	end
end

function Pet:OnAutoTakeMedicine()  --自动吃药
	if self:IsDied() or self:IsDestroy() then
		return 
	end
	if not self.behavior  or GRunOnClient == false  or self:IsHeroPet() == false or SceneManager.currentSceneType == constant.SCENE_TYPE.ARENA then
		return
	end

	local hp_max = self.hp_max()
	if hp_max == 0 then
		return
	end

	local hpRadio = self.hp / hp_max --自动加血
	if GlobalManager.AutoPetHealthSupple and self.hp > 0 and hpRadio < GlobalManager.PetHealthSuppleThreshold/100 then
		BagManager.UseRecoveryDrug(GlobalManager.PetHealthSuppleDurgID)
	end
	
end

function Pet:ReduceHp(num, attacker, event_type)
	Puppet.ReduceHp(self, num, attacker, event_type)
	self:OnAutoTakeMedicine()
end

function Pet:ReduceMp(num, attacker)
	Puppet.ReduceMp(self, num, attacker)
	self:OnAutoTakeMedicine()
end


function Pet:GetClientNeedInfo()
	local info = {}
    info.entity_type = self.entityType
    info.entity_id = self.data.entity_id
    info.owner_id = self.data.owner_id
    info.pet_id = self.data.pet_id
    info.pet_appearance = self.data.pet_appearance
    info.pet_level = self.data.pet_level
    info.fight_index = self.data.fight_index
    info.skill_info = self.data.skill_info
    local sync_data = self:GetSyncAttribute()
    table.update(info, sync_data)
    info.buffs = self.skillManager:GetPublicBuffInfo()
	return msg_pack.pack(info)
end

function Pet:EnterAOIScene(pos)
	Puppet.EnterAOIScene(self, pos)
	if self.owner.aoi_proxy and self.aoi_proxy then
		_add_to_insight(self.owner.aoi_proxy,self.aoi_proxy)
	end
end

function Pet:LeaveAOIScene()
	if self.owner.aoi_proxy and self.aoi_proxy then
		_remove_from_insight(self.owner.aoi_proxy,self.aoi_proxy)
	end
    Puppet.LeaveAOIScene(self)
end
return Pet

