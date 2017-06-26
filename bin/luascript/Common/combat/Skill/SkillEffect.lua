---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： SkillEffect
---------------------------------------------------
local Vector3 = Vector3
require "Common/basic/LuaObject"

local SceneObject = require "Common/basic/SceneObject2"
local SkillEffect = ExtendClass(SceneObject)

function SkillEffect:__ctor(scene, skill_id, data)
	-- skill_id 
	self.skill_id = skill_id
	-- 所有者
	self.owner = data.owner
	-- 对应的技能
	self.skill = data.skill
	-- 技能当前槽位
	self.slot_id = data.slot_id
	-- 其他数据读表
end

function SkillEffect:OnAdd()
	
end

function SkillEffect:OnRemove()

end

function SkillEffect:BreakSkill()
	if GRunOnClient then
		if self.owner.behavior then
			local tmp = self.owner.behavior:GetCurrentAnim()
			if tmp and string.find(tmp, 'skill') > 0 then
				self.owner.behavior:StopBehavior(tmp)
			end
		end
	end
end

function SkillEffect:OnCastStart(data)
	if self.skill.ShockID > 0 then
		SkillAPI.PlayShake( self.owner, self.skill.ShockID, self.skill.ShockTime)
	end

	if self.skill.Bullet == 0 then
		local target = data.target
		self:PlaySkillEffect(target)
    end

end

function SkillEffect:PlaySkillEffect(target)
	if GRunOnClient and target then
		local effects = SkillAPI.GetSkillEffectData(self.owner, self.default_animation)

        if effects then
            for _,eff in pairs(effects) do
                local function play()
                    target:AddEffect(eff.effectPath, nil, eff.duration, nil, nil, nil, true, true)
                end

                if eff.delayTime and eff.delayTime > 0.01 then
                    self.owner:GetTimer().Delay(eff.delayTime, play)
                else
                    play()
                end
            end
        end
	end
end

function SkillEffect:PlaySkillEffectOnLocation(location)
	if GRunOnClient and location then
		local effects = SkillAPI.GetSkillEffectData(self.owner, self.default_animation)

        if effects then
            for _,eff in pairs(effects) do
                local function play()
                	self:GetEntityManager().CreateEffectObj(
                		location.x, location.y, location.z,
                		eff.effectPath, nil, eff.duration, nil, nil, nil, true, true)
                    --target:AddEffect(eff.effectPath, nil, eff.duration, nil, nil, nil, true, true)
                end

                if eff.delayTime and eff.delayTime > 0.01 then
                    self.owner:GetTimer().Delay(eff.delayTime, play)
                else
                    play()
                end
            end
        end
	end
end

function SkillEffect:OnBulletHit(target)
	self.skill:Server_OnBulletHit(target) 
	self:PlaySkillEffect(target)

end

function SkillEffect:OnBulletHitLocation(location)
	self.skill:Server_OnBulletHitLocation(location) 
	self:PlaySkillEffectOnLocation(location)

end

function SkillEffect:FireBullet(target, position)
	local bullet_data = SkillAPI.GetBulletData(self.owner, self.default_animation)

	if bullet_data == nil then
		return 
	end

	local function Fire()
		bullet_data.owner_id = self.owner.uid
		bullet_data.skill_id = self.skill_id
		local bullet = self:GetEntityManager().CreateSceneBullet(bullet_data)
		if bullet then
			if target then
				bullet:Fire(target, self.OnBulletHit, self, target)
			elseif position then
				bullet:FireToPosition(position, self.OnBulletHitLocation, self, position)
			else
				local front = MathHelper.GetForward(self.owner, self.skill.cast_distance)
				bullet:FireToPosition(front, self.OnBulletHitLocation, self, front)
			end
		end
	end

	if bullet_data.startTime and bullet_data.startTime > 0.0001 then
		self:GetTimer().Delay(bullet_data.startTime, Fire)
	else
		Fire()
	end
end

function SkillEffect:OnCastChannel()
end

function SkillEffect:OnCastFinish()
end

function SkillEffect:CreateSkillRangeWarning(position)
	if GRunOnClient then
		if self.skill.area_type == EnumUnitsAreaType.Circle then
			ResourceManager.CreateEffect( "Common/eff_common@warning_circle",function(obj)
			self.range_effect = obj
			self.range_effect.transform:FindChild('0'):GetComponent('Animator').speed = 1.15 / self.skill.cast_start_time
			if position then
	    		self.range_effect.transform.localPosition = position
	    	else
	    		self.range_effect.transform.localPosition = self.owner:GetPosition()
	    	end
	    	self.range_effect.transform.localScale = Vector3.New(self.skill.area_radius / 4, 1, self.skill.area_radius / 4)
			end)
		end
	end
	
end

function SkillEffect:DestroySkillRange()
	if GRunOnClient then
		if self.range_effect then
	        RecycleObject(self.range_effect)
	        self.range_effect = nil
	    end
    end
end

return SkillEffect
