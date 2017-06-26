---------------------------------------------------
-- auth： 张增
-- date： 2016/9/23
-- desc： 未被捕获的pet,逻辑层
---------------------------------------------------
local CreateWildPetBehavior = require "Logic/Entity/Behavior/WildPetBehavior"
local CreatePetPatrolState = require "Common/combat/State/WildPet/PetPatrolState"
local CreateIdleState = require "Common/combat/State/IdleState"
local GrowingPet = GetConfig("growing_pet")

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end

local Puppet = require "Common/combat/Entity/Puppet"
local WildPet = ExtendClass(Puppet)

function WildPet:__ctor(scene, data, event_delegate)
	if data == nil then
		return
	end
	self.entityType = EntityType.WildPet 
	if data.Para1 == '' or not data.Para1 then
		_error('Para1 is nil MonsterID=' .. data.MonsterID)
        return
	end
	data.wildPetAttr = GrowingPet["Attribute"][data.Para1/1] 
	data.WildPetId = data.Para1/1
	
	if not data.wildPetAttr or not data.WildPetId then
		_error('data.wildPetAttr or not data.WildPetId')
	end
	self.name = self:GetName(data)
end

function WildPet:Born()
	Puppet.Born(self)
	-- 属性		
	self.behavior = CreateWildPetBehavior(self)

	self.patrolData = CreatePatrolData(self)
	
	if GRunOnClient then
		self:SetControl(false)
	else
		self:SetControl(true)
	end
	-- 状态
    self.stateManager:AddState(StateType.ePatrol, CreatePetPatrolState(scene, 'patrol', StateType.ePatrol))
	self.stateManager:AddState(StateType.eIdle, CreateIdleState(scene, 'idle', StateType.eIdle))
	self.stateManager:GotoState(StateType.ePatrol)

	
	self.stateManager:StartTick()
	self:CalcProperty()

	self.eventManager.Fire('OnBorn')
end 

function WildPet:EnterScene()
	Puppet.EnterScene(self)

	-- 服务器 自动消失
	if not GRunOnClient then
		if self.data.wildPetAttr.Time and self.data.wildPetAttr.Time ~= 0 then
			self:GetTimer().Delay(self.data.wildPetAttr.Time, function()
				self:GetEntityManager().DestroyPuppet(self.uid)
			end)
		end
	end
end

function WildPet:GetBornPosition()
	if not GRunOnClient then
		if self.data.Para2 ~=nil and self.data.Para2 ~= '0' and self.data.Para2 ~= '' and self.random_generated == nil then
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

function WildPet:GetClientNeedInfo()
	local info = table.copy(self.data)
    info.posX = nil
    info.posY = nil
    info.posZ = nil
   	info.monsterSetting = nil
   	info.wildPetAttr = nil
	info.property = nil 
	info.Scale = math.ceil(info.Scale*100)
	info.Para2 = info.Para2
	info.entity_type = self.entityType
	local sync_data = self:GetSyncAttribute()
    table.update(info, sync_data)
	return msg_pack.pack(info)
end

return WildPet
