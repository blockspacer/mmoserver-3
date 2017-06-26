---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/13
-- desc： 单位的事件delegate
---------------------------------------------------

local Delegate = require "Logic/Entity/Delegate/Delegate"
local DummyDelegate = ExtendClass(Delegate)

function DummyDelegate:__ctor()

end

function DummyDelegate:OnTakeDamage(damage, attacker, skill_id, event_type)
	Delegate.OnTakeDamage(self, damage, attacker, skill_id, event_type)
end

function DummyDelegate:OnDied(killer)
	Delegate.OnDied(self, killer)
end

function DummyDelegate:OnFightStateChanged()
	if self.owner.fightState == FightState.Fight then
		self.owner.data.server_object:set_player_fight_state(true)
	else
		self.owner.data.server_object:set_player_fight_state(false)
	end
end

function DummyDelegate:OnCurrentAttributeChanged()
	local flag = Delegate.OnCurrentAttributeChanged(self)
	if flag then
		if self.owner.data.server_object and self.owner.data.server_object.set_immortal_data then
			self.owner.data.server_object:set_immortal_data(self.owner:GetImmortalAttribute())
		end
	end

	return flag
        
end

return DummyDelegate

