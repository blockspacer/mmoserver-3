---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： SkillManager
---------------------------------------------------
local Vector3 = Vector3

require "Common/basic/LuaObject"
require "Common/basic/TickObject"
require "Common/basic/Timer"
local BuffManager = require "Common/combat/Skill/BuffManager"
require "Common/combat/Skill/SkillConst"
require "Common/combat/Skill/SkillAPI"
require "Common/combat/Skill/SkillUp"
local Const = require "Common/constant"
local SyncManager = require "Common/SyncManager"
-- 技能库，动态加载
SkillLib = {}
SkillEffectLib = {}


local SkillManager = ExtendClass(BuffManager)

function SkillManager:__ctor(scene, owner)
	self.skills = {}
	self.skilleffects = {}
	-- 所有者
	self.owner = owner
	self.common_cd_left = 0

	self.xuli_time = 0
	self.xuli_time_left = 0

	self.slot_cd_left = {}
end

-- 添加技能
function SkillManager:AddSkill(slot_id, skill_id, level, no_enter_cd)
	if skill_id == nil or skill_id == '' or skill_id == '0' then
		return nil
	end
    local config = GetConfig("growing_skill")
	local skill_data = config.Skill[tonumber(skill_id)]
	if skill_data == nil then
		print(skill_id, ' encounter error')
		return 
	end
	local skill_type = tostring(skill_data.logicID)
	local skill_effect_type = tostring(skill_data.EffectClass)
	require("Common/combat/Skill/SkillEffects/"..skill_effect_type)
	SkillAPI.RequireSkill(skill_type)

    if self.skills[slot_id] ~= nil then
    	if self.skills[slot_id].skill_id == skill_id then
    		return 
    	end
    	self:RemoveSkill(slot_id)
    end

    self.skills[slot_id] = SkillLib[skill_type](self.scene, skill_id, {owner = self.owner, level=level, slot_id = slot_id})
    self.skills[slot_id]:OnAdd()

    self.skilleffects[slot_id] = 
    	SkillEffectLib[skill_effect_type](self.scene, skill_id, {owner = self.owner, skill = self.skills[slot_id], slot_id = slot_id})
    self.skilleffects[slot_id]:OnAdd()

    -- 如果是替换，就得进入CD
    if self.slot_cd_left[slot_id] and no_enter_cd ~= true then
    	self.skills[slot_id].cd_left = math.min(self.slot_cd_left[slot_id], self.skills[slot_id].cd) 
    end

end

function SkillManager:IsFillCondition(slot_id)
	if self:HasSkill(slot_id) then
		return self.skills[slot_id]:IsFillCondition()
	else
		return false
	end
end

-- 删除技能
function SkillManager:RemoveSkill(slot_id)
	if self.skills[slot_id] then
		if self.slot_cd_left[slot_id] then
			self.slot_cd_left[slot_id] = math.max(self.skills[slot_id].cd_left, self.slot_cd_left[slot_id])
		else
			self.slot_cd_left[slot_id] = self.skills[slot_id].cd_left
		end
		self.skills[slot_id]:OnRemove()
   	 	self.skills[slot_id] = nil
   	end
   	if self.skilleffects[slot_id] then
    	self.skilleffects[slot_id]:OnRemove()
    	self.skilleffects[slot_id] = nil
    end
end

-- 这个槽位的技能是否存在
function SkillManager:HasSkill(slot_id)
	return self.skills[slot_id] ~= nil;
end

-- 根据Skill_id来刷新
function SkillManager:RefreshBySkillID(skill_id)
	--print('尝试刷新CD', skill_id, type(skill_id)) 
	for _, skill in pairs(self.skills) do
		--print('skill:', skill.skill_id)
		if skill.skill_id == skill_id then
			--print('skill: 刷新', skill.skill_id)
    		skill:RefreshCD()
    	end
	end
end

-- 是否限制了移动
function SkillManager:IsLimitMove()
	if self.owner:IsDestroy() or self.owner:IsDied() then
		return false
	end
	return 
		self.owner:HasStatus('Dizzy') or  
		self.owner:HasStatus('Lock') or 
		self.owner:HasStatus('Petrifaction') or 
		self.owner:HasStatus('BeatBack') or 
		self.owner:HasStatus('Digestion') or 
		self.owner:HasStatus('PullOver')
end

-- 是否限制了攻击, 连普攻都不能放
function SkillManager:IsLimitAttack()
	if self.owner:IsDestroy() or self.owner:IsDied() then
		return false
	end
	return 
		self.owner:HasStatus('Slience') or 
		self.owner:HasStatus('Dizzy') or 
		self.owner:HasStatus('Petrifaction') or 
		self.owner:HasStatus('BeatBack') or 
		self.owner:HasStatus('Fear') or
		self.owner:HasStatus('Digestion') or 
		self.owner:HasStatus('PullOver')
end

-- 是否限制了技能
function SkillManager:IsLimitSkill()
	return 
		self.owner:HasStatus('Charm')
end

-- 是否限制了 玩家控制
function SkillManager:IsLimitPlayerControl()
    if GRunOnClient and TeamManager.Following() then
        UIManager.ShowNotice('组队跟随状态下无法操作角色。请取消跟随状态')
        return true
    end
	return 
		self.owner:HasStatus('Charm') or 
		self.owner:HasStatus('Fear')
end

-- 技能是否可用
function SkillManager:IsSkillAvailable(slot_id)
	if not self:HasSkill(slot_id) then
		return false, Const.error_skill_no_skill
	elseif self.skills[slot_id].passive_skill == true then
		return false, Const.error_skill_passive_skill
	elseif self:IsLimitAttack() or (slot_id ~= SlotIndex.Slot_Attack and self:IsLimitSkill()) then
		return false, Const.error_skill_silence
	elseif self.skills[slot_id]:IsInCD() or self:IsOnCommonCD() then
	    return false, Const.error_skill_in_cd
	elseif self.skills[slot_id].NeedMp > self.owner.mp then
		return false, Const.error_skill_lack_mp
	else
		return true, Const.error_skill_cast_ok
	end

end

-- 判断是否可以释放技能
function SkillManager:CanCast(slot_id, target, location)
	    -- TODO 还要判断 人物状态(被禁锢等), 然后返回响应的错误码
    if self.owner:IsDied() or self.owner:IsDestroy() then
    	return Const.error_skill_owner_dead
    end

    local is_ok, code = self:IsSkillAvailable(slot_id)
    if not is_ok then
    	return code
    else
    	local distance = 0
	    	if self.skills[slot_id].cast_target_type == CastTargetType.CAST_TARGET_UNIT or 
	    		self.skills[slot_id].cast_target_type == CastTargetType.CAST_TARGET_ALLY then
	    		if target == nil then
	    			return Const.error_skill_no_target
	    		end
	    		if target:IsDied() or target:IsDestroy() then
	    			return Const.error_skill_target_dead
	    		end
	    		distance = Vector3.Distance2D(self.owner:GetPosition(), target:GetPosition())
	    	elseif self.skills[slot_id].cast_target_type == CastTargetType.CAST_TARGET_LOCATION then
	    		if location == nil then
	    			return Const.error_skill_no_location
	    		end
	    		distance = Vector3.Distance2D(self.owner:GetPosition(), location)
	    	end
	   	
	    	if distance > self.skills[slot_id].cast_distance then
	    		return Const.error_skill_too_far
	    	else
	    		return Const.error_skill_cast_ok
	    	end
    end
end

-- 释放技能
function SkillManager:CastSkill(slot_id, target, location)
	-- 判断当前技能能否释放
	local err_code = self:CanCast(slot_id, target, location)
	if err_code == Const.error_skill_cast_ok then
		self:CastSkillStart(slot_id, {target = target, location = location})
		SyncManager.CS_CastSkill(self.owner, slot_id, target.uid)
		return true
		--print("cast skill, slot_id = ", slot_id, " skill_id = ", self.skills[slot_id].skill_id)
	else
		return false
		-- print("Cant cast skill, slot_id = ", slot_id, " err_code = ", err_code)
	end
end

-- 朝天放技能  以后要删掉的
function SkillManager:CastSkillToSky(slot_id)
	local is_ok, code = self:IsSkillAvailable(slot_id)
	if is_ok then
		self:CastSkillStart(slot_id, {})
		SyncManager.CS_CastSkill(self.owner, slot_id)
	else
		print("Cant cast skill[", self.skills[slot_id].skill_id, '] code=', code)
	end
end

-- 打断当前技能
function SkillManager:BreakSkill()
	-- TODO 有可能会遇到别人打过来的眩晕技能
	if self.xuli_slot_id > 0 and self.skills[self.xuli_slot_id].can_break then
		SyncManager.SC_OnSkillBreak(self.owner)
		self.skills[self.xuli_slot_id]:BreakSkill()
		self.skilleffects[self.xuli_slot_id]:BreakSkill()
		self.xuli_slot_id = -1
	end
end

-- 前摇开始
function SkillManager:CastSkillStart(slot_id, data)
	--print('CastSkillStart: ', slot_id)
	SyncManager.SC_OnCastSkillStart(self.owner, slot_id, self.skills[slot_id].skill_id, data.target)
	self.skills[slot_id]:TryOnCastStart(data)
	self.skilleffects[slot_id]:OnCastStart(data)
	self.xuli_time = self.skills[slot_id].cast_start_time
	self.xuli_time_left = self.xuli_time
	self.xuli_slot_id = slot_id
	-- 是否瞬发
	if self.skills[slot_id].cast_start_time > 0.01 then
		self:GetTimer().Delay(self.skills[slot_id].cast_start_time, self.CastSkillChannel, self, slot_id, data)
	else
		self:CastSkillChannel(slot_id, data)
	end

end

-- 施法中
function SkillManager:CastSkillChannel(slot_id, data)
	if self.xuli_slot_id == -1 then
		return 
	end
	self.xuli_slot_id = -1
	self.skills[slot_id]:TryOnCastChannel(data)
	self.skilleffects[slot_id]:OnCastChannel(data)
	-- 是否瞬发
	if self.skills[slot_id].cast_channel_time > 0.01 then
		self:GetTimer().Delay(self.skills[slot_id].cast_channel_time, self.CastSkillFinish, self, slot_id, data)
	else
		self:CastSkillFinish(slot_id, data)
	end
end

-- 施法结束
function SkillManager:CastSkillFinish(slot_id, data)
	self.skills[slot_id]:TryOnCastFinish(data)
	self.skilleffects[slot_id]:OnCastFinish(data)
end
	
-- Tick
function SkillManager:Tick(interval)
	-- 调用父亲的Tick
	getmetatable(SkillManager).__index.Tick( self , interval)
	-- print("------- SkillManager Tick --------")
	for slot_id, skill in pairs(self.skills) do
		--print(slot_id, skill)
		skill:OnTick(interval)
	end
	--print('skillmanager tick. common_cd_left ', self.common_cd_left)
	--print("-------Buff OnTick---------")
    if self.common_cd_left >= 0.00001 then
    	self.common_cd_left = self.common_cd_left - interval
    end
    if self.xuli_time_left >= 0.00001 then
    	self.xuli_time_left = self.xuli_time_left - interval
    end

    for slot_id, v in pairs(self.slot_cd_left) do 
    	if self.slot_cd_left[slot_id] >= 0.00001 then
	    	self.slot_cd_left[slot_id] = self.slot_cd_left[slot_id] - interval
	    end
    end
end

-- skillmanager被销毁，一般就是这个单位被删除的时候
function SkillManager:OnDestroy()
	getmetatable(SkillManager).__index.OnDestroy( self )

	for _, skill in pairs(self.skills) do
    	skill:OnRemove()
	end
	self.skills = nil
	for _, skilleffect in pairs(self.skilleffects) do
    	skilleffect:OnRemove()
	end
	self.skilleffects = nil
end

function SkillManager:IsOnCommonCD()
	if self.common_cd_left > 0.00001 then
		return true
	else
		return false
	end
end

function SkillManager:ClearCommonCD()
	self.common_cd_left = 0
end

function SkillManager:IsInCastRange(slot_id, target)
	if not self:HasSkill(slot_id) then
		return false
	    else
	    	local distance = 0

    		if target == nil or target:IsDied() or target:IsDestroy() then
    			return false
    		end
    		-- 如果技能不需要目标
    		if self.skills[slot_id].cast_target_type ~= CastTargetType.CAST_TARGET_UNIT then
    			return true
    		end

    		distance = Vector3.Distance2D(self.owner:GetPosition(), target:GetPosition())
	   	
	    	if distance > (self.skills[slot_id].cast_distance - 0.1) then
	    		return false
	    	else
	    		return true
	    	end
	end
end

function SkillManager:GetSkillDistance(slot_id)
	if self:HasSkill(slot_id) then
		return self.skills[slot_id].cast_distance
	end
	return 0
end

function SkillManager:GetSkillInCastStart()
	for _, skill in pairs( self.skills ) do
		if skill.cur_skill_stage == SkillStage.SKILL_CAST_FINISH then
			return skill
		end
	end
	return nil
end

function SkillManager:StopWorking()
	self:ClearBuff()
	self:StopTick()
	self:ClearCommonCD()
end

function SkillManager:Clear()
	--[[self.skills = nil
	self.skilleffects = nil
	-- 所有者
	self.owner = nil
	self.slot_cd_left = nil]]
end

return SkillManager