---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/13
-- desc： 单位的事件delegate
---------------------------------------------------

require "Common/basic/LuaObject"

local EntityDelegate = ExtendClass()

function EntityDelegate:__ctor()

end

function EntityDelegate:SetOwner(owner)
	self.owner = owner
	self:AddListeners()
end

function EntityDelegate:AddListeners()
    self.owner.eventManager.event.AddListener('OnHpChanged', self.OnHpChanged, self)
	self.owner.eventManager.event.AddListener('OnCastSkill', self.OnCastSkill, self)
	self.owner.eventManager.event.AddListener('OnFightStateChanged', self.OnFightStateChanged, self)
	self.owner.eventManager.event.AddListener('OnTakeDamage', self.OnTakeDamage, self)
	self.owner.eventManager.event.AddListener('OnCauseDamage', self.OnCauseDamage, self)
	self.owner.eventManager.event.AddListener('OnAddHp', self.OnAddHp, self)
	self.owner.eventManager.event.AddListener('OnAddMp', self.OnAddMp, self)
	self.owner.eventManager.event.AddListener('OnReduceHp', self.OnReduceHp, self)
	self.owner.eventManager.event.AddListener('OnReduceMp', self.OnReduceMp, self)
	self.owner.eventManager.event.AddListener('OnDied', self.OnDied, self)
	self.owner.eventManager.event.AddListener('OnDestroy', self.OnDestroy, self)
	self.owner.eventManager.event.AddListener('OnResurrect', self.OnResurrect, self)
	self.owner.eventManager.event.AddListener('OnCurrentAttributeChanged', self.OnCurrentAttributeChanged, self)
	self.owner.eventManager.event.AddListener('OnBorn', self.OnBorn, self)
	self.owner.eventManager.event.AddListener('OnHatredChanged', self.OnHatredChanged, self)
	self.owner.eventManager.event.AddListener('OnEnterScene', self.OnEnterScene, self)
	self.owner.eventManager.event.AddListener('OnSpurTo', self.OnSpurTo, self)
end

function EntityDelegate:Destroy()
	self.owner.eventManager.event.RemoveListener('OnHpChanged', self.OnHpChanged, self)
	self.owner.eventManager.event.RemoveListener('OnCastSkill', self.OnCastSkill, self)
	self.owner.eventManager.event.RemoveListener('OnFightStateChanged', self.OnFightStateChanged, self)
	self.owner.eventManager.event.RemoveListener('OnTakeDamage', self.OnTakeDamage, self)
	self.owner.eventManager.event.RemoveListener('OnCauseDamage', self.OnCauseDamage, self)
	self.owner.eventManager.event.RemoveListener('OnAddHp', self.OnAddHp, self)
	self.owner.eventManager.event.RemoveListener('OnAddMp', self.OnAddMp, self)
	self.owner.eventManager.event.RemoveListener('OnReduceHp', self.OnReduceHp, self)
	self.owner.eventManager.event.RemoveListener('OnReduceMp', self.OnReduceMp, self)
	self.owner.eventManager.event.RemoveListener('OnDied', self.OnDied, self)
	self.owner.eventManager.event.RemoveListener('OnDestroy', self.OnDestroy, self)
	self.owner.eventManager.event.RemoveListener('OnResurrect', self.OnResurrect, self)
	self.owner.eventManager.event.RemoveListener('OnCurrentAttributeChanged', self.OnCurrentAttributeChanged, self)
	self.owner.eventManager.event.RemoveListener('OnBorn', self.OnBorn, self)
	self.owner.eventManager.event.RemoveListener('OnHatredChanged', self.OnHatredChanged, self)
	self.owner.eventManager.event.RemoveListener('OnEnterScene', self.OnEnterScene, self)
	self.owner.eventManager.event.RemoveListener('OnSpurTo', self.OnSpurTo, self)
	self.owner = nil
end

function EntityDelegate:OnHpChanged(hp)
end

function EntityDelegate:OnCastSkill(animation_name)
end

function EntityDelegate:OnFightStateChanged()
end

function EntityDelegate:OnTakeDamage(damage, attacker, skill_id, event_type)
end

function EntityDelegate:OnCauseDamage(damage, victim, skill_id, event_type)
end

function EntityDelegate:OnAddHp(hp, source)
end

function EntityDelegate:OnAddMp(num, source)
end

function EntityDelegate:OnReduceHp(num, attacker, event_type)
end

function EntityDelegate:OnReduceMp(num, attacker)
end

function EntityDelegate:OnDied(killer)
end

function EntityDelegate:OnAddStatus(status)
end

function EntityDelegate:OnRemoveStatus(status)
end

function EntityDelegate:OnDestroy()
end

function EntityDelegate:OnResurrect(data)
end

function EntityDelegate:OnCurrentAttributeChanged()
end

function EntityDelegate:OnBorn()
end

function EntityDelegate:OnEnterScene()
end

function EntityDelegate:OnHatredChanged()
end

function EntityDelegate:OnSpurTo(dir, speed, btime, time, atime, visible, bspeed, aspeed)
end

return EntityDelegate