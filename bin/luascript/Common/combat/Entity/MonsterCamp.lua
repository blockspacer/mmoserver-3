---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/5/9
-- desc： 阵营怪物
---------------------------------------------------

local CreateMonsterCampBehavior = require "Logic/Entity/Behavior/MonsterCampBehavior"
local CreateMonsterCampDelegate = require "Logic/Entity/Delegate/MonsterCampDelegate"

--local flog = require "basic/log"

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end


local Monster = require "Common/combat/Entity/Monster"
local MonsterCamp = ExtendClass(Monster)

function MonsterCamp:__ctor(scene, data, event_delegate)
	if event_delegate == nil then
		if self.event_delegate then
			self.event_delegate:Destroy()
		end
		self.event_delegate = CreateMonsterCampDelegate()
		self.event_delegate:SetOwner(self)
	end
	
    self.configID = tonumber(data.Para1)
    self.modelId = data.ModelID
    self.sceneObjectID = data.ID

	self.entityType = EntityType.MonsterCamp
end

function MonsterCamp:CreateBehavior()
	return CreateMonsterCampBehavior(self)
end

function MonsterCamp:Born() 	
	Monster.Born(self)
end

function MonsterCamp:OnFightStateChanged()
	-- 不会满血
end

-- 不实际扣血
function MonsterCamp:ReduceHp(num, attacker, event_type)
	if self:IsDied() or self:IsDestroy() then
		return
	end
	self.attacker = attacker

	self.eventManager.Fire('OnReduceHp', num, attacker, event_type)
end

function MonsterCamp:AddHp(hp, source)	
end

function MonsterCamp:SetHp(hp)
    Monster.SetHp(self, hp)
end

-- 不能打 普通monster
function MonsterCamp:IsEnemy(unit)
	local res = Monster.IsEnemy(self, unit)

	if res == true then
		if unit.entityType == EntityType.Monster then
			res = false
		end
	end
	return res 
end

return MonsterCamp
