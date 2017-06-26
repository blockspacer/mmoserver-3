---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/13
-- desc： 单位的事件delegate
---------------------------------------------------


local SyncManager = require "Common/SyncManager"

local get_entity = require("helper/delegate_common").get_entity


local EntityDelegate = require "Common/combat/Entity/Delegate/EntityDelegate"
local Delegate = ExtendClass(EntityDelegate)

function Delegate:__ctor()

end

function Delegate:OnHpChanged(hp)
	local entity = get_entity(self, self.owner.uid)
	if entity ~= nil and entity.on_hp_changed ~= nil then
		entity:on_hp_changed(hp)
	end
end

function Delegate:OnPlaySkillAnimation(animation_name)
	
end

function Delegate:OnTakeDamage(damage, attacker, skill_id, event_type)
	SyncManager.SC_OnTakeDamage(self.owner, damage, attacker, skill_id, event_type)
	if attacker and attacker.data.server_object then
		attacker.data.server_object:on_attack_entity(self.owner.uid, damage)
	end
end

function Delegate:OnAddHp(num, source)
	SyncManager.SC_OnAddHp(self.owner, num, source)
	if source and source.data.server_object then
		source.data.server_object:on_treat_entity(self.owner.uid, num)
	end
	
end

function Delegate:OnAddMp(num, source)
	SyncManager.SC_OnAddMp(self.owner, num, source)
end

function Delegate:OnReduceMp(num, attacker)
	SyncManager.SC_OnReduceMp(self.owner, num, attacker)
end

function Delegate:OnBorn()
end

function Delegate:OnDied(killer)
	if killer and self.owner.data.server_object then
		self.owner.data.server_object:entity_die(killer.uid)
	end

	SyncManager.SC_OnDied(self.owner, killer)
end

function Delegate:OnDestroy()
	scene_manager.destroy_entity(self.owner:GetSceneID(), self.owner.uid) 
end

function Delegate:OnNeedChangeEntityInfo()
	-- 更新单位的entity_info信息
    --self.owner.data.server_object:update_entityinfo()
end

function Delegate:OnResurrect(data)
	SyncManager.SC_OnResurrect(self.owner, data)
end

function Delegate:OnCurrentAttributeChanged()
	local data = {}
	
	local flag = false

	for _,v in pairs(SyncAttribute) do
		local value = nil
		if self.owner[v] ~= nil then
			if type(self.owner[v]) ~= 'function' then
				value = self.owner[v]
			else
				value = self.owner[v]()
			end
			if self['old_'..v] ~= value then
				if self['old_'..v] ~= nil then
					data[v] = value
					flag = true
				end
				self['old_'..v] = value
			end
		end
		
		
	end

	if flag then
	    SyncManager.SC_CurrentAttribute(self.owner, data)
	    self.owner:UpdateAOIInfo()
	end

	return flag
        
end

function Delegate:OnSpurTo(dir, speed, btime, time, atime, visible, bspeed, aspeed)
	SyncManager.SC_OnSpurTo(self.owner, dir, speed, btime, time, atime, visible, bspeed, aspeed)
end


return Delegate
