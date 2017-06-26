---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/26
-- desc： 基类
---------------------------------------------------
local Vector3 = Vector3
local floor = require'math'.floor
local pairs = pairs
local find = require'string'.find
local GRunOnClient = GRunOnClient

local scene_func
local flog
local broadcast_to_aoi

if not GRunOnClient then
	scene_func = require "scene/scene_func"
	flog = require "basic/log"
	broadcast_to_aoi = require("basic/net").broadcast_to_aoi
end

require "Common/basic/SceneObject"
local CreateStateManager = require "Common/combat/State/StateManager"
require "Common/combat/Skill/CommandManager"
local StatusManager = require "Common/combat/Skill/StatusManager"
local SkillManager = require "Common/combat/Skill/SkillManager"
local CreateEventManager = require "Common/combat/Entity/EventManager"
local Const = require "Common/constant"
local INDEX = Const.PROPERTY_NAME_TO_INDEX
local NAME = Const.PROPERTY_INDEX_TO_NAME
local CreateDelegate = require "Logic/Entity/Delegate/Delegate"

local function CalcProperty(owner)


	if not owner.need_calc_property then
		return 
	end

	owner.need_calc_property = false


	for k,v in pairs(INDEX) do
		if k ~= "fly_power" then
			-- 只有服务器 模式才动态计算
			if not GRunOnClient then
			owner[k](owner['base_'..k]())

				if owner.skillManager then
					--处理技能和装备的 累加属性, Percent 就累乘
					for _, skill in pairs(owner.skillManager.skills) do 
						if skill[k] then
							owner[k](owner[k]() + skill[k])
						end
					end
					-- 处理 buff的 累加属性, Percent 就累乘
					for _, buff in pairs(owner.skillManager.buffs) do 
						if buff[k] then
							owner[k](owner[k]() + buff[k])
						end
					end		
				end	

				-- 处理 技能和装备的 百分比属性
				for _, skill in pairs(owner.skillManager.skills) do 
					if skill[k..'Percent'] then
						owner[k](owner[k]() * skill[k..'Percent'])
					end
				end
				-- 处理 buff的 百分比属性
				for _, buff in pairs(owner.skillManager.buffs) do 
					if buff[k..'Percent'] then
						owner[k](owner[k]() * buff[k..'Percent'])
					end
				end
			end
		end
	end

	for k,v in pairs(owner.buffData) do
		if not find(k,'Percent') then
			owner.buffData[k] = 0
			for _, skill in pairs(owner.skillManager.skills) do 
				if skill[k] then
					owner.buffData[k] = owner.buffData[k] + skill[k]
				end
			end
			for _, buff in pairs(owner.skillManager.buffs) do 
				if buff[k] then
					owner.buffData[k] = owner.buffData[k] + buff[k]
				end
			end
		else
			owner.buffData[k] = 1
			for _, skill in pairs(owner.skillManager.skills) do 
				if skill[k] then
					owner.buffData[k] = owner.buffData[k] * skill[k]
				end
			end
			for _, buff in pairs(owner.skillManager.buffs) do 
				if buff[k] then
					owner.buffData[k] = owner.buffData[k] * buff[k]
				end
			end
		end
	end

	-- 这两个要取整
	if owner.move_speed() then
		owner.move_speed(floor(owner.move_speed()))
		owner:SetSpeed(owner.move_speed())
	end
	owner.hp_max(floor(owner.hp_max()))
	
	if owner.entityType == EntityType.Hero then
		--print('Hero speed', owner.move_speed())
	end

	owner.eventManager.Fire('OnCurrentAttributeChanged')
end

function CreateBuffData()
	local self = {}
	-- 移动速度影响百分比(比如减速20%的话，这里就应该是0.8)
    --self.move_speedPercent = 1

    -- 基础伤害增加、减少
    self.BasicDamagePlusPercent = 1
    self.BasicDamageMinusPercent = 1
    -- 元素伤害增加、减少
    self.ElementDamagePlusPercent = 1
    self.ElementDamageMinusPercent = 1
    -- 伤害增加、减少
    self.DamagePlusPercent = 1
    self.DamageMinusPercent = 1
    -- 额外伤害增加
    self.ExtraDamagePlus = 0
    -- 额外伤害减少
    self.ExtraDamageMinus = 0
    return self
end

SyncAttribute = {
	'hp',
	'mp',
	'hp_max',
	'mp_max',
	'move_speed',
	'name',
	'is_stealthy',
	'team_id',
	'faction_id',
	'level',
	'anger_value',
	'appearance_1',
	'appearance_2',
	'appearance_3',
	'canAttack',
	'canBeattack',
	'canBeselect',
	'camp_type'
}

ImmortalAttribute = {
	'hp',
	'mp',
	'is_stealthy',
}


local BaseObject = require "Common/combat/Entity/BaseObject"
local CommonPuppet = ExtendClass(BaseObject)

function CommonPuppet:__ctor(scene, data, event_delegate)
	self.source = data.source or EntitySource.Default -- 默认创建，非AOI
	self.data = data
	self.enabled = true -- 是否可以行走，释放技能
	self.canAttack = true
	self.canBeattack = true
	self.canBeselect = true
	self.canMove = true

	self.buffData = CreateBuffData()
	self.baseProperty = data.property
	self.property = table.copy(data.property)

	self.team_id = data.team_id
	self.faction_id = data.faction_id
	self.level = data.level

	self.uid = data.entity_id
	self.icon = '' -- 头像图片

	self.behavior = nil

	self.entityType = nil

	self.target = nil		-- 自己盯上的目标
	self.attacker = nil 	-- 盯上自己的目标

	self.stateManager = CreateStateManager(scene, self)	
	self.skillManager = SkillManager(scene, self)
	self.statusManager = StatusManager(self)
	self.commandManager = CreateCommandManager(self, scene)
	self.eventManager = CreateEventManager(self)
	self.event_delegate = event_delegate or CreateDelegate()
	self.event_delegate:SetOwner(self)

	self.isDied = false
	self.isDestroy = false
	self.isOnBehit = false

	self.approachTimer = nil
	self.approachCallback = nil
	self.approachArgs = nil

	self.fightStateTimer = nil
	self.behitTimer = nil
	self.propertyTimer = nil

	self.hatredManager = nil
	self.ApproachDistance = 0   -- 与主角的距离

	self.onMovetoCallback = nil
	self.destionation = nil
	self.movetoTimer = nil
	self.movetoArgs = nil
	self.stopDistance = 0.5

	self.need_calc_property = true
end

function CommonPuppet:Born()

	-- 补全属性字段
	for i, v in pairs(INDEX) do
		if not self.baseProperty[v] then
			self.baseProperty[v] = 0
		end
	end
	-- 初始化属性字段，根据constant的property定义属性方法
	for i, v in pairs(self.baseProperty) do
		local field = NAME[i]
		if not field then
			error("error !!! not found field name index=" .. i)
		else
			self['base_' .. field] = function(value)
				if value then
					self.baseProperty[i] = value
				else
					if GRunOnClient then
						return self.baseProperty[i]
					else
                        -- 服务器的monster可能server_object里面也没有属性的，还是得读 baseProperty[i]
                        if self.data.server_object and self.data.server_object[field] then
							return self.data.server_object[field]
						else
							return self.baseProperty[i]
						end
					end
				end
			end
			self[field] = function(value)
				if value then
					self.property[i] = value
				else
					return self.property[i]
				end
			end
		end
	end

	-- 普通单位 置满，Dummy自己特殊处理
	self.hp = self.data.hp or self.base_hp_max()
	self.mp = self.data.mp or self.base_mp_max()
	
	--self:SetHp(self.base_hp_max())
	self.fly_power(self.base_fly_power())
	self.isDied = false
	self.isDestroy = false
end

function CommonPuppet:EnterScene()
	if self.data.buffs then
		for _, buff_info in pairs(self.data.buffs) do
            local flag = true
			if not GRunOnClient and buff_info.end_time then
				local end_time = buff_info.end_time / 1000
				local now_time = _get_now_time_second()
                buff_info.remain_time = (end_time - now_time) * 1000
                if buff_info.remain_time <= 0 then 
                    flag = false
                end
			end

            if flag then
			    local buff = self.skillManager:AddBuff(buff_info.buff_id)
			    if buff then
				    buff.remain_time = buff_info.remain_time / 1000
				    buff.count = buff_info.count
			    end
            end
		end
	end

	if not GRunOnClient then
		self:CreateAOIProxy()
	end

	self.eventManager.Fire('OnEnterScene')
end
	
function CommonPuppet:SetName(name)
	self.name = name
	if self.data.actor_name ~= nil then
		self.data.actor_name = name
	end
	self.eventManager.Fire('OnCurrentAttributeChanged')
end

function CommonPuppet:SetTeamId(id)
	self.team_id = id
	self.data.team_id = id
	self.eventManager.Fire('OnCurrentAttributeChanged')
end

function CommonPuppet:SetLevel(level)
	self.level = level
	self.data.level = level
	self.eventManager.Fire('OnCurrentAttributeChanged')
end

function CommonPuppet:SetCampType(type)
	self.camp_type = type
	self.eventManager.Fire('OnCurrentAttributeChanged')
end

function CommonPuppet:GetName(data)
    local text = GetConfig("common_char_chinese")    
    if data.Name and data.Name ~= 0 then
        return (text.TableText[data.Name] and text.TableText[data.Name].NR) or ''
    end
    local str = data.Name1
    if str == '0' or str == '' or str == nil then
        return ''
    end
    return str
end

function CommonPuppet:GetBornPosition()
	return Vector3.New(self.data.posX, self.data.posY, self.data.posZ)
end

function CommonPuppet:SetBornPosition(pos)
	self.data.posX = pos.x
	self.data.posY = pos.y
	self.data.posZ = pos.z
end
    
function CommonPuppet:GetTarget()
	local target = self.target
	if target and (target:IsDied() or target:IsDestroy()) then
		target = nil
		self.target = nil
	end
	return target
end

function CommonPuppet:GetAttacker()
	local attacker = self.attacker
	if attacker and (attacker:IsDied() or attacker:IsDestroy()) then
		attacker = nil
		self.attacker = nil
	end
	return attacker
end
	
	-- 获取当前位置
function CommonPuppet:GetPosition()		
	if self.behavior then
		return self.behavior:GetPosition()
	else
		return self:GetBornPosition()
	end
end

function CommonPuppet:GetPartPosition(name)
	return self.behavior:GetPartPosition(name)
end

function CommonPuppet:SetPosition(pos)
	self.commandManager.Excute(CreateSetPositionCommand(self, pos))
	-- self.behavior:SetPosition(pos)
end

function CommonPuppet:GetRotation()
	return self.behavior:GetRotation()
end

function CommonPuppet:SetRotation(rotation)
	self.commandManager.Excute(CreateRotateCommand(self, rotation))
	-- self.behavior:SetRotation(rotation)
end
function CommonPuppet:SetRadius(r)
	self.behavior:SetRadius(r)
end
function CommonPuppet:GetRadius()
	return self.behavior:GetRadius()
end
function CommonPuppet:SetSpeed(speed)
	self.move_speed(floor(speed))
	self.behavior:SetSpeed(speed)
end	
function CommonPuppet:GetSpeed(speed)
	return behavior:GetSpeed()
end
function CommonPuppet:LookAt(pos)
	self.behavior:LookAt(pos)
end
function CommonPuppet:SpurtTo(dir, speed, btime, time, atime, visible, bspeed, aspeed)
	self.behavior:SpurtTo(dir, speed, btime, time, atime, visible, bspeed, aspeed)
	self.eventManager.Fire('OnSpurTo', dir, speed, btime, time, atime, visible, bspeed, aspeed)
end
function CommonPuppet:CanMove()
	if self.skillManager:IsOnCommonCD() then
		return false
	end
	if self.skillManager:IsLimitMove() then
		return false
	end
	return self.canMove
end
function CommonPuppet:startListenMoveto()
	if not self.onMovetoCallback then
		return
	end
	if not self.stopDistance then
		self.stopDistance = 0.5
	end
	self.movetoTimer = self:GetTimer().Repeat(0.3, function()
		if not self.onMovetoCallback or not self.destionation then
			self:stopListerMoveto()
			return
		end
		if Vector3.InDistance(self:GetPosition(), self.destionation, self.stopDistance) then
			self.onMovetoCallback(unpack(self.movetoArgs))
			self:stopListerMoveto()
			self:StopMoveImmediately()
		end		
		if not self:isMoving() then
			self:stopListerMoveto()
		end
	end)
end
function CommonPuppet:stopListerMoveto()
	self.onMovetoCallback = nil
	self.destionation = nil
	if self.movetoTimer then
		self:GetTimer().Remove(self.movetoTimer)
	end
	self.movetoTimer = nil
	self.movetoArgs = {}
	self.stopDistance = nil
end
-- 移动到pos
function CommonPuppet:Moveto(pos, stopDistance, onArrived, ...)
	self.commandManager.Excute(CreateMovePosCommand(self, pos, stopDistance, onArrived, {...}))
end	
function CommonPuppet:MoveDir(direction)
	self.commandManager.Excute(CreateMoveDirCommand(self, direction))
end
function CommonPuppet:StopMove()
	self.commandManager.Excute(CreateStopMoveCommand(self))
end
function CommonPuppet:StopMoveImmediately()
	-- self.commandManager.Clear()
	self:StopApproachTarget()
	self:stopListerMoveto()
	if self.behavior then
		self.behavior:StopMove()
	end
end
function CommonPuppet:StopAt(pos, rotation)
	self.commandManager.Excute(CreateStopMoveSyncCommand(self, pos, rotation))
end
-- 同步服务端移动
function CommonPuppet:UpdateMoveto(pos, speed, rotation, delaytime)
	self.commandManager.Excute(CreateMoveSyncCommand(self, pos, speed, rotation, delaytime))
    -- self.behavior:UpdateMoveto(pos, rotation, speed, time)
end

function CommonPuppet:isMoving()
	return self.behavior:IsMoving()
end
	
function CommonPuppet:SetControl(b)
	self.is_control = b
end	
function CommonPuppet:IsControl()
    return self.is_control
end
-- function CommonPuppet:SetNavMesh(b)
-- 	self.behavior:SetNavMesh(b)
-- end
-- function CommonPuppet:GetNavMesh()
-- 	return self.behavior:GetNavMesh()
-- end
-- 是否同步位置
function CommonPuppet:SetSyncPosition(b)
	self.behavior:SetSyncPosition(b)
end
function CommonPuppet:GetSyncPosition()
	return self.behavior:GetSyncPosition()
end

	
	
function CommonPuppet:StartApproachTarget(target, distance, callback, ...)
	self.target = target
	if not self:CanMove() then
		return
	end
	self.approachCallback = callback
	self.approachArgs = {...}
	if self:IsOnApproachTarget(target) then
		return
	end
	distance = distance - 0.1
	self.approachTimer = self:GetTimer().Repeat(0.3, function()
		if not target or target:IsDied() or target:IsDestroy() then
			self:StopApproachTarget()
			return
		end
		if Vector3.InDistance(self:GetPosition(), target:GetPosition(), distance) then
			if self.approachCallback then
				self.approachCallback(unpack(self.approachArgs))
			end
			self:StopApproachTarget()
		else
			self:Moveto(target:GetPosition())
		end			
	end)
end
function CommonPuppet:StopApproachTarget()
	if self.approachTimer then
		self:GetTimer().Remove(self.approachTimer)
		self.approachTimer = nil
		self:StopMoveImmediately()
	end
	self.approachCallback = nil
	self.approachArgs = nil
end
function CommonPuppet:IsOnApproachTarget(target)
	return (self.approachTimer ~= nil and target == self.target)
end

function CommonPuppet:IsDied()
	return self.isDied
end
function CommonPuppet:IsDestroy()
	return self.isDestroy
end

function CommonPuppet:IsAlive()
	local alive = not self:IsDied() and not self:IsDestroy() 
	return alive
end

-- 能否发动技能
function CommonPuppet:CanCastSkill(slot_id, enemy)
	if not self.skillManager then
		return false
	end
	return self.skillManager:CanCast(slot_id, enemy) 
end

function CommonPuppet:CastSkillToSky(slot_id)		
	self.commandManager.Excute(CreateSkillToSkyCommand(self, slot_id))
end
	-- 发动技能 
function CommonPuppet:CastSkill(slot_id, enemy)
	if self.entityType == EntityType.Monster then
		flog("tmlDebug","canAttack "..tostring(self.canAttack))
	end
	return self.commandManager.Excute(CreateSkillCommand(self, slot_id, enemy))		
end

	-- 如果距过远的话先靠近再施法　
function CommonPuppet:ApproachAndCastSkill(slot_id, enemy)
	self.target = enemy
	if enemy then
		self:LookAt(enemy:GetPosition())
		self.target:BeTarget(self)
	end
	if self.skillManager:IsInCastRange(slot_id, enemy) then
        self:StopApproachTarget()
        self:CastSkill(slot_id, enemy) 
    else
    	local skillDis = self.skillManager.skills[slot_id].cast_distance
        self:StartApproachTarget(enemy, skillDis, function()
        	self:ApproachAndCastSkill(slot_id, enemy) 
        end)
	end
end

-- 一般单位可以到了时间直接逃脱，宠物和 dummy不能，有特殊条件
function CommonPuppet:tryEscapeFightState()
	return true
end
function CommonPuppet:stopFightStateTimer()
	if self.fightStateTimer then
		self:GetTimer().Remove(self.fightStateTimer)
	end
	self.fightStateTimer = nil
end
-- source 是该单位进入 战斗状态的 单位来源
function CommonPuppet:startFightStateTimer(source)
	self:stopFightStateTimer()
	self:FightStateChanged(FightState.Fight)

	self.fightStateTimer = self:GetTimer().Repeat(1, function()
		if self:tryEscapeFightState() then
			self:FightStateChanged(FightState.Normal)
			self:stopFightStateTimer()
		end
	end)
end

	
function CommonPuppet:stopBehitTimer()
	if self.behitTimer then
		self:GetTimer().Remove(self.behitTimer) 
	end
	self.behitTimer = nil
	self.isOnBehit = false
end
function CommonPuppet:startBehitTimer()
	self:stopBehitTimer()
	self.isOnBehit = true
	self.eventManager.Fire('OnBehitStateChanged', self.isOnBehit)
	local behitTime = GetConfig("common_fight_base").Parameter[53].Value/100
	self.behitTimer = self:GetTimer().Delay(behitTime, function()
		self.isOnBehit = false
		self.eventManager.Fire('OnBehitStateChanged', self.isOnBehit)
	end)
end
function CommonPuppet:IsOnBeHit()
	return self.isOnBehit
end

	-- 初始化好之后进行调用，装备什么都有了之后
	
function CommonPuppet:NeedCalcProperty()
	self.need_calc_property = true
end

function CommonPuppet:ImmediateCalcProperty()
	self.need_calc_property = true
	CalcProperty(self)
end

function CommonPuppet:CalcProperty()
	CalcProperty(self)
	if self.propertyTimer then
		self:StopCalcProperty()
	end
	self.propertyTimer = self:GetTimer().Repeat(0.1, CalcProperty, self)
end
function CommonPuppet:StopCalcProperty()
	if self.propertyTimer then
		self:GetTimer().Remove(self.propertyTimer)
	end
	self.propertyTimer = nil
end
function CommonPuppet:SetCurrentAnimationSpeed(speed)
    self.behavior:SetCurrentAnimationSpeed(speed)
end

function CommonPuppet:SetAnimationSpeed(animation, speed)
	self.behavior:SetAnimationSpeed(animation, speed)
end

function CommonPuppet:AddStatus(status, buff)
	self.statusManager:AddStatus(status, buff)
end

function CommonPuppet:OnAddStatus(status, buff)
end

function CommonPuppet:RemoveStatus(status, buff)
	self.statusManager:RemoveStatus(status, buff)
end

function CommonPuppet:OnRemoveStatus(status, buff)
end

function CommonPuppet:HasStatus(status)
	return self.statusManager:HasStatus(status)
end

function CommonPuppet:AddEffect(resName, rootName, recyle, pos, angle, scale, detach, lossyScale)
	if rootName == '0' or rootName == '' then
		rootName = nil
	end
	if self.behavior then
		self.behavior:AddEffect(resName, rootName, recyle, pos, angle, scale, detach, lossyScale)
	end
end

	-- 移除特效
function CommonPuppet:RemoveEffect(res)
	if self.behavior then
		self.behavior:RemoveEffect(res)
	end
end

	-- 添加石化等特效
function CommonPuppet:CastEffect(effect_name)
	self.behavior:CastEffect(effect_name)
end

	-- 删除石化等特效
function CommonPuppet:RevertEffect()
	self.behavior:RevertEffect()
end

function CommonPuppet:SetEnabled(enabled)
	self.enabled = enabled
end

function CommonPuppet:GetEnabled()
	return self.enabled
end
--TODO需要通知，下发给客户端，和entityInfo
function CommonPuppet:SetAttackStatus(status)
	self.canAttack = status
end

function CommonPuppet:GetAttackStatus()
	return self.canAttack
end

-- 停止一切动作
function CommonPuppet:StopWorking(is_destroy)
	is_destroy = is_destroy or false
	self.commandManager.Clear()
	self:StopMoveImmediately()	
    if self.behavior then
	    if is_destroy then
	    	self:SetCurrentAnimationSpeed(1)
		    self:RevertEffect()
		    self.behavior:RemoveAllEffect()
		end
    end    
	self.skillManager:StopWorking()
	self.stateManager:StopTick()
	self.commandManager.Stop()
	self:StopCalcProperty()
	self:StopApproachTarget()
	self:stopListerMoveto()
	self:stopFightStateTimer()
	self:stopBehitTimer()
	self:FightStateChanged(FightState.Normal)
end

function CommonPuppet:IsEnemy(unit)
	-- 如果在帮派场景的话，进行特殊判断
	if self:GetSceneType() == Const.SCENE_TYPE.FACTION then
		if self.faction_id == nil then 
			return false
		end
		if unit.faction_id == nil then
			return false
		end
		if self.faction_id ~= unit.faction_id then
			return true
		end
		return false
	end

	if self.camp_type == nil or self.camp_type == Const.CAMP_TYPE.NEUTRAL then
		return false
	end

	if unit.camp_type == nil or unit.camp_type == Const.CAMP_TYPE.NEUTRAL then
		return false
	end

	if self.camp_type == Const.CAMP_TYPE.CAMP and unit.camp_type ~= Const.CAMP_TYPE.NONE then
		return false
	end

	if unit.camp_type == Const.CAMP_TYPE.CAMP and self.camp_type ~= Const.CAMP_TYPE.NONE then
		return false
	end

	if self.camp_type ~= unit.camp_type then
		return true
	end

	return false
end

function CommonPuppet:IsAlly(unit)
	-- 如果在帮派场景的话，进行特殊判断
	if self:GetSceneType() == Const.SCENE_TYPE.FACTION then
		if self.faction_id == nil then 
			return false
		end
		if unit.faction_id == nil then
			return false
		end
		if self.faction_id == unit.faction_id then
			return true
		end
		return false
	end

	if self.camp_type == nil or self.camp_type == Const.CAMP_TYPE.NEUTRAL then
		return false
	end

	if unit.camp_type == nil or unit.camp_type == Const.CAMP_TYPE.NEUTRAL then
		return false
	end

	if self.camp_type == Const.CAMP_TYPE.CAMP and unit.camp_type == Const.CAMP_TYPE.NONE then
		return false
	end

	if unit.camp_type == Const.CAMP_TYPE.CAMP and self.camp_type == Const.CAMP_TYPE.NONE then
		return false
	end

	if self.camp_type == unit.camp_type then
		return true
	end

	return false
end

function CommonPuppet:SetHp(hp)
	if not hp then 
		return
	end
	self.hp = math.max(0, floor(hp))
	self.hp = math.min(self.hp, self.hp_max())
	self.data.current_hp = self.hp
	self.eventManager.Fire('OnHpChanged', self.hp)
	self.eventManager.Fire('OnCurrentAttributeChanged')
end

function CommonPuppet:SetMp(mp)
	if not mp then 
		return
	end
	self.mp = math.max(0, floor(mp))
	self.mp = math.min(self.mp, self.mp_max())
	self.eventManager.Fire('OnCurrentAttributeChanged')
end

function CommonPuppet:TakeDamage(damage, attacker, skill_id, event_type)
	if self:IsDied() or self:IsDestroy() then
		return
	end
	if attacker ~= nil then
		attacker:startFightStateTimer(self)
	end
	self:startFightStateTimer(attacker)
	self:startBehitTimer()
	self.eventManager.Fire('OnTakeDamage', damage, attacker, skill_id, event_type)
	self:ReduceHp(damage, attacker, event_type)

	if attacker ~= nil then
		attacker:CauseDamage(damage, self, skill_id, event_type)
	end
end

-- 主要是发消息
function CommonPuppet:CauseDamage(damage, victim, skill_id, event_type)
	self.eventManager.Fire('OnCauseDamage', damage, victim, skill_id, event_type)
	self:AddHatredValue(victim.uid,1)
end

--被嘲讽
function CommonPuppet:LampoonStart(uid,value)
	if self.hatredManager == nil then
		return
	end
	local max_hatred = self:GetMaxHatredValue()
	self:SetEntityHatred(uid,max_hatred + value)
	self.hatredManager:SetLampoon(uid,true)
end

--被嘲讽结束
function CommonPuppet:LampoonOver(uid)
	if self.hatredManager == nil then
		return
	end
	self.hatredManager:SetLampoon(uid,false)
end

--直接设置仇恨值
function CommonPuppet:SetEntityHatred(uid,value)
	if self.hatredManager == nil then
		return
	end
	self.hatredManager:SetEntityHatred(uid,value)
end

--获取最大仇恨值
function CommonPuppet:GetMaxHatredValue()
	if self.hatredManager == nil then
		return 0
	end
	return self.hatredManager:GetMaxHatredValue()
end

--设置仇恨对象隐身
function CommonPuppet:SetHatredEntityStealthy(uid)
	if self.hatredManager == nil then
		return
	end
	self.hatredManager:SetHatredEntityStealthy(uid)
end

--获取对某对象仇恨值
function CommonPuppet:GetEntityHatredValue(uid)
	if self.hatredManager == nil then
		return 0
	end
	return self.hatredManager:GetEntityHatredValue(uid)
end

function CommonPuppet:HatredChanged()
	self.eventManager.Fire('OnHatredChanged')
end

--伤害仇恨值
function CommonPuppet:UpdateDamageHatred(damage,attacker)
	if self.hatredManager == nil then
		return
	end
	self.hatredManager:UpdateDamageHatred(damage,attacker)
end
--治疗仇恨值
function CommonPuppet:UpdateCureHatred(cure,curer)
	if self.hatredManager == nil then
		return
	end
	self.hatredManager:UpdateCureHatred(cure,curer)
end

--获取当前仇恨对象
function CommonPuppet:GetCurrentHatredEntity()
	if self.hatredManager == nil then
		return
	end
	return self.hatredManager:GetCurrentHatredEntity()
end

--是否在仇恨列表中
function CommonPuppet:IsInHatredList(uid)
	if self.hatredManager == nil then
		return false
	end
	return self.hatredManager:IsInHatredList(uid)
end

--仇恨列表是否为空
function CommonPuppet:IsHatredListEmpty()
	if self.hatredManager == nil then
		return true
	end
	return self.hatredManager:IsHatredListEmpty()
end

function CommonPuppet:AddHatredValue(uid,value)
	if self.hatredManager == nil then
		return true
	end
	return self.hatredManager:AddHatredValue(uid,value)
end

function CommonPuppet:GetHatredListUids()
	if self.hatredManager == nil then
		return {}
	end
	return self.hatredManager:GetHatredListUids()
end

function CommonPuppet:FightStateChanged(now_state)
	if self.fightState == now_state then
		return 
	end

	self.fightState = now_state
	self.eventManager.Fire('OnFightStateChanged')
end
	-- 加血，譬如 吸血、治疗等等都来自这里
function CommonPuppet:AddHp(hp, source)	
	if self.hp >= self.hp_max() then
		return 
	end
	self.eventManager.Fire('OnAddHp', hp, source)	
	self:SetHp(self.hp + hp)
end

function CommonPuppet:ReduceHp(num, attacker, event_type)
	if self:IsDied() or self:IsDestroy() then
		return
	end
	self.attacker = attacker
	self:SetHp(self.hp - num)

	self.eventManager.Fire('OnReduceHp', num, attacker, event_type)
	if self.hp <= 0 then
		self:Died(attacker) 
	end
end

function CommonPuppet:ReduceMp(num, attacker)
	if self:IsDied() or self:IsDestroy() then
		return
	end
	self.eventManager.Fire('OnReduceMp', num, attacker)
	self:SetMp(self.mp - num)
end

function CommonPuppet:AddMp(num, source)
	if self.mp >= self.mp_max() then
		return 
	end
	self.eventManager.Fire('OnAddMp', num, source)
	self:SetMp(self.mp + num)
end
	
function CommonPuppet:BeTarget(attacker)
	self.eventManager.Fire('OnBeTarget', attacker)
end

function CommonPuppet:Died(killer)
		
	self.eventManager.Fire('OnDied', killer)
end
	
function CommonPuppet:Besoul(killer)
	self.enabled = true
	self.eventManager.Fire('OnBesoul', killer)
end
function CommonPuppet:Resurrect(data)
	self.isDied = false
	self.eventManager.Fire('OnResurrect', data)
end
	
function CommonPuppet:ChangeModel(prefab, scale)--更换模型
	if self.behavior then
		self.behavior:SetModel(prefab, scale)
	end
end

function CommonPuppet:SetModelScale(scale)--更换模型缩放
	if self.behavior then
		self.behavior:SetScale(scale)
	end
end

function CommonPuppet:ResetModel()
	if self.behavior then
		self.behavior:ResetModel()
	end
end

function CommonPuppet:GetModelId()
	if self.behavior then
		return self.behavior:GetModelId()
	end
end

function CommonPuppet:GetModelScale()
	if self.behavior then
		return self.behavior:GetModelScale()
	end
end

function CommonPuppet:GetBodyActive()
	return self.behavior:GetBodyActive()
end

function CommonPuppet:SetBodyActive(b)
	self.behavior:SetBodyActive(b)
end
function CommonPuppet:GetPlayEffect()
    return self.behavior:GetPlayEffect()
end
function CommonPuppet:SetPlayEffect(b)
    self.behavior:SetPlayEffect(b)
end

function CommonPuppet:Destroy()
	self.enabled = false
	self:StopWorking(true)
	self.eventManager.Fire('OnDestroy')
end

function CommonPuppet:GetIdleTime()
	return self.commandManager.GetIdleTime()
end
function CommonPuppet:Clear()
	--self.data = nil
	self.buffData = nil
	--self.baseProperty = nil
	--self.property = nil
	self.target = nil		-- 自己盯上的目标
	self.attacker = nil 	-- 盯上自己的目标

	self.stateManager:Clear()
	self.stateManager = nil

	self.skillManager:Clear()
	self.skillManager = nil

	self.statusManager:Clear()
	self.statusManager = nil

	self.commandManager = nil
	-- self.eventManager.Clear()
	-- self.eventManager = nil

	self.event_delegate = nil

	self.approachTimer = nil
	self.approachCallback = nil
	self.approachArgs = nil

	self.fightStateTimer = nil
	self.behitTimer = nil
	self.propertyTimer = nil

	if self.hatredManager ~= nil then
		self.hatredManager:Destroy()
		self.hatredManager:Clear()
		self.hatredManager = nil
	end

	self.onMovetoCallback = nil
	self.destionation = nil
	self.movetoTimer = nil
	self.movetoArgs = nil
end
	---------------------------------------------------------------------
	------------------------------- event -------------------------------
	---------------------------------------------------------------------
function CommonPuppet:OnHpChanged(hp)
end



function CommonPuppet:OnTakeDamage(damage, attacker, skill_id, event_type)	
	if self.behavior then
		self.behavior:PlayHitEffect(attacker, skill_id, false, damage, event_type)
	end
	
	self:UpdateDamageHatred(damage, attacker)
end

function CommonPuppet:OnCastSkill(animation_name)
	self.behavior:UpdateBehavior(animation_name)		
end

function CommonPuppet:OnFightStateChanged()			
end
function CommonPuppet:OnBehitStateChanged()
end

function CommonPuppet:OnMove(posOrDir)		
end

function CommonPuppet:OnAddHp(hp, source)
	if hp > 0 then
		self:GetEntityManager().UpdateCureHatred(hp,source)
		self.behavior:BehaveAddHp(hp)
	end
end


function CommonPuppet:OnAddMp(num, source)
	if num > 0 then
		self.behavior:BehaveAddMp(num)
	end
end

function CommonPuppet:OnReduceHp(num, attacker, event_type)		
	self.behavior:BehaveBehit(num, event_type) 
end
	-- 拉到仇恨
function CommonPuppet:OnBeTarget(attacker)
		
end
function CommonPuppet:OnDied(killer)		
    self.isDied = true		
    self.enabled = false

	if self.hatredManager ~= nil then
		self.hatredManager:ClearAllHatred()
	end
	self:StopWorking()
	self:GetEntityManager().OnPuppetDied(self.uid, killer)
	self.behavior:BebaveDie(
		function()
			self:Besoul(killer)
		end)
end
	-- 变成灵魂体事件
function CommonPuppet:OnBesoul(killer)
	self:GetEntityManager().DestroyPuppet(self.uid)
end
	-- 单位复活事件
function CommonPuppet:OnResurrect(data)
		
end
function CommonPuppet:OnBorn()
	if self.hp <= 0 then
		self:Died(nil)
	end
end

function CommonPuppet:OnChangeModel(prefab, scale)--更换模型
end

function CommonPuppet:OnDestroy()
    BaseObject.OnDestroy(self)
	if self.behavior then
        self.behavior:Destroy()
		self.behavior = nil
	end
	self:Clear()
	self.isDestroy = true
end

function CommonPuppet:GetSyncAttribute()

	local data = {}
	data.property = {}
	for _, name in pairs(SyncAttribute) do
		if self[name] ~= nil then
			if INDEX[name] ~= nil then
				if type(self[name]) == 'function' then
                    local value = self[name]()
					data.property[INDEX[name]] = value
				else
					data.property[INDEX[name]] = self[name]
				end
			else
				data[name] = self[name]
			end
		end

	end
    return data
end

function CommonPuppet:GetImmortalAttribute()

	local data = {}

	for _, name in pairs(ImmortalAttribute) do
		if self[name] ~= nil then
			data[name] = self[name]
		end
	end
    return data
end

return CommonPuppet