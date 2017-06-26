---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/1/11
-- desc： 技能召唤物
---------------------------------------------------

local CreateBulletBehavior = require "Logic/Entity/Behavior/BulletBehavior"

local Toy = require "Common/combat/Entity/Toy"
local Bullet = ExtendClass(Toy)

local config = GetConfig("growing_skill")
-- 子弹
function Bullet:__ctor(scene, data)
	self.entityType = EntityType.Bullet
	self.owner = self:GetEntityManager().GetPuppet(data.owner_id)

	self.is_trigger = false
end

function Bullet:Born()
	Toy.Born(self)
	self.behavior = CreateBulletBehavior(self)

	self:SetSpeed((self.data.speed or 5) * 100)
end

function Bullet:Fire(target, callback, ...)
	if not target or target:IsDied() or target:IsDestroy() then
		self:GetEntityManager().DestroyPuppet(self.uid)
		return 
	end
	self.hit_callback = callback
	self.target = target
	self.hit_params = {...}

	self:StartApproachTarget2D(target, 1.5, self.OnHit, self)
end

function Bullet:FireToPosition(pos, callback, ...)
	pos.y = self:GetPosition().y
	self:StartApproachPosition(pos, 1.5, self.OnHit, self)
	self.hit_callback = callback
	self.hit_params = {...}
end

function Bullet:OnHit()
	if self.is_trigger then
		return 
	end
	self.is_trigger = true
	if self.hit_callback then
		self.hit_callback(unpack(self.hit_params))
	end
	local skill_id = self.data.skill_id
	self:GetEntityManager().DestroyPuppet(self.uid)
	self.hit_callback = nil 

	if self.target and self.target.behavior then
		self.target.behavior:PlayHitEffect(self.owner, skill_id, true, 0)
	end
end

return Bullet
