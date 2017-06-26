---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/26
-- desc： hero,逻辑层
---------------------------------------------------
local log = require "basic/log"
local Vector3 = Vector3

local CreateHeroBehavior = require "Logic/Entity/Behavior/HeroBehavior"
local SkillManager = require "Common/combat/Skill/SkillManager"
local common_base_fight = GetConfig("common_fight_base")
local constant = require "Common/constant"
local uitext = GetConfig("common_char_chinese").UIText
local CreateHookAttackState = require "Common/combat/State/HookHero/HookAttackState" 
local CreateHookPatrolState= require "Common/combat/State/HookHero/HookPatrolState"
local CreateeWildHookState = require "Common/combat/State/HookHero/WildHookState"
local CreateeArenaHookState = require "Common/combat/State/HookHero/ArenaHookState"
local CreateKillMonster = require "Common/combat/State/Hero/KillMonsterState"
local Dummy = require "Common/combat/Entity/Dummy"
local Hero = ExtendClass(Dummy)

function Hero:__ctor(scene, data, event_delegate)
	self.entityType = EntityType.Hero 

	self.isShowLowHpEffect = false
	self.isShowBehitEffect = false

	self.conveyTimer = nil
	self.CamTime2 = nil
	self.locateTimer = nil
	self.useStealthyTimer = nil
    self.totalTime = commonFightBase.Parameter[46].Value/1000
	self.OperateStatus = constant.HERO_OPERATION_STATUS.None
end

function Hero:CreateBehavior()
	return CreateHeroBehavior(self)
end

function Hero:Born()
	self.stateManager:AddState(StateType.eHookAttack, CreateHookAttackState(scene, 'HookAttack', StateType.eHookAttack))
	self.stateManager:AddState(StateType.eHookPatrol, CreateHookPatrolState(scene, 'HookPatrol', StateType.eHookPatrol))
	self.stateManager:AddState(StateType.eWildHook, CreateeWildHookState(scene, 'eWildHook', StateType.eWildHook))
	self.stateManager:AddState(StateType.eArenaHook, CreateeArenaHookState(scene, 'eArenaHook', StateType.eArenaHook))
	self.stateManager:AddState(StateType.eKillMonster, CreateKillMonster(scene, 'eKillMonster', StateType.eKillMonster))
	Dummy.Born(self)
	self:SetControl(true)
	if SceneManager.isTestModel == true then -- 单人副本和测试场景不上传位置
		self:SetSyncPosition(false)
	else
		self:SetSyncPosition(true)
	end
	self:StartTick()
	self.commandManager.cmdCapacity = 2

	if GlobalManager.isHook then
	   local hookCombat = require "Logic/OnHookCombat"
	   hookCombat.SetHook(true)
	end

	local ctrl = UIManager.GetCtrl(ViewAssets.Resurrection)
	if ctrl.isLoaded then
		ctrl.isLock = false
		ctrl.close()
	end
	CameraManager.CameraController.target_ = self.behavior.transform
	CameraManager.CameraController:Reset()
end

function Hero:showBehitEffect()
	if self.isShowBehitEffect then
		return
	end
	self.behavior:CastCameraEffect('BeHitEffect', 0)
	self.isShowBehitEffect = true
end

function Hero:stopBehitEffect()
	if not self.isShowBehitEffect then
		return
	end
	self.behavior:RemoveCameraEffect('BeHitEffect')
	self.isShowBehitEffect = false
end
	
	
function Hero:showLowHPEffect(s)
	if self.isShowLowHpEffect then
		return
	end
	self:stopBehitEffect()
	self.behavior:CastCameraEffect('BeHitEffect', 2.5)
	self.isShowLowHpEffect = true
end

function Hero:stopLowHPEffect()
	if not self.isShowLowHpEffect then
		return
	end
	self.behavior:RemoveCameraEffect('BeHitEffect')
	self.isShowLowHpEffect = false
end

function Hero:IsLowHp()
	return (self.hp/self.base_hp_max()) < (common_base_fight.Parameter[19].Value/100)
end
	
function Hero:OnBehitStateChanged()
	Dummy.OnBehitStateChanged(self)
	if self:IsOnBeHit() then
		if not self:IsLowHp() then
			if not SceneManager.IsOnFightServer() and 
				self.attacker and 
				(self.attacker.entityType == EntityType.Dummy or self.attacker.entityType == EntityType.Pet) then
				self:showBehitEffect()
			end
		end
	else
		self:stopBehitEffect()
	end
end

function Hero:OnHpChanged(hp)	
	Dummy.OnHpChanged(self, hp)
	-- if self.attacker and (self.attacker.entityType == EntityType.Dummy or self.attacker.entityType == EntityType.Pet) then
		if not self:IsDied() and self:IsLowHp() then
			self:showLowHPEffect()
		else
			self:stopLowHPEffect()
		end
	-- end
end

function Hero:OnTakeDamage(damage, attacker, spell_name, event_type)		
	Dummy.OnTakeDamage(self, damage, attacker, spell_name, event_type)
	
	if not TargetManager.GetCurrentTarget() or TargetManager.GetCurrentTarget():IsDied() then
		if self.target and not self.target:IsDied() then
			TargetManager.SetTarget(self.target)
		end
	end
    
    if attacker and attacker.behavior then
    	attacker.behavior:ShowBar()
    end
end



function Hero:OnMove()	
	Dummy.OnMove(self)
	self:StopLocate()
	self:StopUseStealthy()
	self:StopSwitchLine()
end
    
function Hero:OnCastSkill(animation_name)
    Dummy.OnCastSkill(self, animation_name)
	self:StopLocate()
	self:StopUseStealthy()
	self:StopSwitchLine()
end

local ConveyType = {
	ConveyScene = 1,		--切场景
	ConveyRandom = 2,		--本场景随机传送
	ConveyBanner = 3,		--导标旗
}
function Hero:_Convey(type, param, callback)
	if type ~= ConveyType.ConveyScene and type ~= ConveyType.ConveyRandom and type ~= ConveyType.ConveyBanner then
		return
	end
	if type == ConveyType.ConveyScene then
		self.totalTime = commonFightBase.Parameter[46].Value/1000
	elseif type == ConveyType.ConveyRandom or type == ConveyType.ConveyBanner then
		local item_config = GetConfig("common_item").Item[BagManager.items[param].id]
		if item_config == nil then
			return
		end
		self.totalTime = tonumber(item_config.Para2)
	end
    
    local SendConvey = function()
        self:StopConvey()
		if type == ConveyType.ConveyScene then
			if param == SceneManager.currentSceneId then return end
			SceneManager.RequestEnterSceneWithMini(param, callback)
		elseif type == ConveyType.ConveyRandom then
			MessageManager.RequestLua(MSG.CS_MESSAGE_LUA_ITEM_USE, {item_pos=param,count=1})
		elseif type == ConveyType.ConveyBanner then
			local data = {}
			data.func_name = 'on_user_transport_banner'
			data.item_pos = param
			MessageManager.RequestLua(constant.CS_MESSAGE_LUA_GAME_RPC, data)
		end
    end
    
    local recoveryPos = Vector3.zero
    local Recovery = function()
        --SceneManager.conveyDelay = false
        UIManager.HideFullMask()
        if SceneManager.conveyCallBack then
            SceneManager.conveyCallBack()
            return
        end
        Game.SetCanSyncMsg(true)
        self.behavior.transform.position = recoveryPos
        -- self.behavior.transform:GetComponent('NavMeshAgent').enabled = true
        self.behavior:StopBehavior('soar')
        self.heroTween = nil
    end
    
	local CamH = function()
		self.behavior:CastCameraEffect('MotionBlurEffect', 2.2)
		CameraManager.CameraController:GetFarestPoint()
	end
	local HeroH = function()
        UIManager.HideProcessBar()
        UIManager.ShowFullMask()
        --SceneManager.conveyDelay = true
        Game.SetCanSyncMsg(false)
        SendConvey()
        
		recoveryPos = self.behavior.transform.position
        -- self.behavior.transform:GetComponent('NavMeshAgent').enabled = false
		local Pos = Vector3.New(recoveryPos.x,recoveryPos.y+25,recoveryPos.z)
		Pos = Pos + UnityEngine.Camera.main.transform.forward.normalized*1.6
		self.heroTween = BETween.position(self.behavior.transform.gameObject,1.5,Pos)
        self.heroTween.method = BETweenMethod.easeOut
        self.heroTween.onFinish = Recovery
        self.behavior:UpdateBehavior('soar')
	end
    self.behavior:UpdateBehavior('spell_loop')
	self.OperateStatus = constant.HERO_OPERATION_STATUS.Conveying
    UIManager.ShowProcessBarByTime(self.totalTime,'传送中...')
    if self.conveyTimer then
    	self:GetTimer().Remove(self.conveyTimer)
	end
	local same_scene = false
	if type == ConveyType.ConveyRandom then
		same_scene = true
	elseif type == ConveyType.ConveyBanner then
		local itemdata = BagManager.items[param]
		if itemdata ~= nil and itemdata.location ~= nil and itemdata.location.scene_id == SceneManager.GetCurServerSceneId() then
			same_scene = true
		end
	end
	if same_scene == true then
		self.conveyTimer = self:GetTimer().Delay(self.totalTime, SendConvey, self)
	else
		self.CamTime2 = self:GetTimer().Delay(self.totalTime+0.2, CamH, self)
		self.conveyTimer = self:GetTimer().Delay(self.totalTime, HeroH, self)
	end
end
function Hero:Convey(id, callback)
    self:StopMoveImmediately()
	if self:CheckOperationStatus(constant.HERO_OPERATION_STATUS.None) == false then
		self:ShowOperationStatus()
		return
	end
	self:_Convey(ConveyType.ConveyScene, id, callback)

end
    
function Hero:StopConvey()
    if self.conveyTimer then
		BagManager.lock = false
    	self:GetTimer().Remove(self.conveyTimer) 
    	self.conveyTimer = nil 
    	self:GetTimer().Remove(self.CamTime2) 
        self.CamTime2 = nil
		self.behavior:RemoveCameraEffect('MotionBlurEffect')
        self.behavior:StopBehavior('spell_loop')
    end
    if self.heroTween then
        GameObject.Destroy(self.heroTween)
    end
    UIManager.HideProcessBar()
    UIManager.HideFullMask()
	if self.OperateStatus == constant.HERO_OPERATION_STATUS.Conveying then
		self.OperateStatus = constant.HERO_OPERATION_STATUS.None
	end
end

function Hero:ConveyRandom(pos)
	self:_Convey(ConveyType.ConveyRandom,pos)
end

function Hero:ConveyBanner(pos)
	self:_Convey(ConveyType.ConveyBanner,pos)
end

function Hero:StartSwitchLine(lineid)
    self:StopMoveImmediately()
	UIManager.UnloadView(ViewAssets.SwitchChannelUI)
	UIManager.UnloadView(ViewAssets.SceneMapUI)
	UIManager.ShowProcessBarByTime(3, '切换分线中..', function()
		SceneLineManager.ChangeGameLine(lineid)
	end)		
    self.behavior:UpdateBehavior('spell_loop')
end
function Hero:StopSwitchLine()
	UIManager.HideProcessBar()
    self.behavior:StopBehavior('spell_loop')
end

function Hero:LocatePosition(pos,item_id)
	local item_config = GetConfig("common_item").Item[BagManager.items[pos].id]
	if item_config == nil or item_config.Type ~= constant.TYPE_NIL_TRANSPORT_BANNER then
		return
	end
	self.totalTime = tonumber(item_config.Para1)
    local SendLocate = function()
        self:StopLocate()
		local data = {}
		data.func_name = 'on_user_nil_transport_banner'
		data.item_pos = pos
		data.item_id = item_id
		local position = self:GetPosition()
		if position ~= nil then
			data.posX = position.x
			data.posY = position.y
			data.posZ = position.z
			data.scene_id = SceneManager.GetCurServerSceneId()
		end
		MessageManager.RequestLua(constant.CS_MESSAGE_LUA_GAME_RPC, data)
    end
    self.behavior:UpdateBehavior('spell_loop')
    --Timer.Delay(1,function() self.behavior:UpdateBehavior('spell_loop') end)
    UIManager.ShowProcessBarByTime(self.totalTime,uitext[1101052].NR)
    self:StopLocate()
	self.OperateStatus = constant.HERO_OPERATION_STATUS.Locating
    self.locateTimer = self:GetTimer().Delay(self.totalTime, SendLocate, self)
end

function Hero:StopLocate()
	if self.locateTimer ~= nil then
		BagManager.lock = false
		self:RemoveLocateTimer()
		self.behavior:RemoveCameraEffect('MotionBlurEffect')
		UIManager.HideProcessBar()
	end
	if self.OperateStatus == constant.HERO_OPERATION_STATUS.Locating then
		self.OperateStatus = constant.HERO_OPERATION_STATUS.None
	end
end

function Hero:RemoveLocateTimer()
	if self.locateTimer ~= nil then
		self:GetTimer().Remove(self.locateTimer)
		self.locateTimer = nil
	end
end

function Hero:UseStealthyCharacter(pos,item_id)
	local item_config = GetConfig("common_item").Item[BagManager.items[pos].id]
	if item_config == nil or item_config.Type ~= constant.TYPE_STEALTHY_CHARACTER then
		return
	end
	self.totalTime = tonumber(item_config.Para2)
    local SendStealthy = function()
        self:StopUseStealthy()
		MessageManager.RequestLua(MSG.CS_MESSAGE_LUA_ITEM_USE, {item_pos=pos,count=1,item_id=item_id})
    end
    self.behavior:UpdateBehavior('spell_loop')
	UIManager.ShowProcessBarByTime(self.totalTime,uitext[1101053].NR)
    self:StopUseStealthy()
	self.OperateStatus = constant.HERO_OPERATION_STATUS.Stealthying
    self.useStealthyTimer = self:GetTimer().Delay(self.totalTime, SendStealthy, self)
end

function Hero:RemoveUseStealthyTimer()
	if self.useStealthyTimer ~= nil then
		self:GetTimer().Remove(self.useStealthyTimer)
		self.useStealthyTimer = nil
	end
end

function Hero:StopUseStealthy()
	if self.useStealthyTimer ~= nil then
		BagManager.lock = false
		self:RemoveUseStealthyTimer()
		self.behavior:RemoveCameraEffect('MotionBlurEffect')
		UIManager.HideProcessBar()
	end
	if self.OperateStatus == constant.HERO_OPERATION_STATUS.Stealthying then
		self.OperateStatus = constant.HERO_OPERATION_STATUS.None
	end
end

function Hero:CheckOperationStatus(status)
	if self.OperateStatus == status then
		return true
	end
	return false
end

function Hero:ShowOperationStatus()
	if self.OperateStatus == constant.HERO_OPERATION_STATUS.Conveying then
		UIManager.ShowNotice(uitext[1101051].NR)
	elseif self.OperateStatus == constant.HERO_OPERATION_STATUS.Locating then
		UIManager.ShowNotice(uitext[1101052].NR)
	elseif self.OperateStatus == constant.HERO_OPERATION_STATUS.Stealthying then
		UIManager.ShowNotice(uitext[1101053].NR)
	end
end



function Hero:Tick()
	self:OnAutoTakeMedicine()

end

function Hero:StartTick()
	if self.tick_timer then
		self:StopTick()
	end
	self.tick_timer = self:GetTimer().Repeat(0.6, self.Tick, self)
end

function Hero:StopTick()
	if self.tick_timer then
		self:GetTimer().Remove(self.tick_timer)
	end
	self.tick_timer = nil
end
   
function Hero:OnLevelUp()
	self.behavior:OnLevelUp()
end
function Hero:OnDestroy()
    TargetManager.ClearTarget()
    self:StopConvey()
	self:StopLocate()
	self:StopUseStealthy()
	self:StopTick()
	if GRunOnClient and self.lowFlyManager then
		self.lowFlyManager.OnDestroy()
	end
	Dummy.OnDestroy(self)
end

function Hero:OnDied(killer)
	Dummy.OnDied(self, killer)
	self.behavior:CastCameraEffect('DeathEffect', 0.2)
	self:stopBehitEffect()
	self:stopLowHPEffect()
    self:StopConvey()
end
	
function Hero:OnResurrect()
	Dummy.OnResurrect(self)		
	self.behavior:RemoveCameraEffect('DeathEffect')
	if self.behavior then
		CameraManager.CameraController.target_ = self.behavior.transform
		self.behavior:SetPosition(Vector3.New(self.data.posX/100, self.data.posY/100, self.data.posZ/100))
	end
end

local ProgressBarStatus = {
		Charm = 1,
		Petrifaction = 1,
		Fear = 1,
		Dizzy = 1,
	}
function Hero:OnAddStatus(status, buff)
	if ProgressBarStatus[status] then
		UIManager.PushView(ViewAssets.BuffProgressBarUI,function(c) c.UpdateBar(status, buff.remain_time) end)
	end
end

function Hero:OnRemoveStatus(status, buff)
	if ProgressBarStatus[status] then
		UIManager.UnloadView(ViewAssets.BuffProgressBarUI)
	end
end

-- 当被玩家点地,或用摇杆,或从UI界面点击技能时触发
function Hero:OnControl(type)
	if GlobalManager.isHook == true then
		local hookCombat = require "Logic/OnHookCombat"
		hookCombat.ManualCancelHook()
    end

    if type ~= 'charge' then 	--打断施法
        self:StopConvey()
	end
    self:StopKillMonster()
	if type == 'move' then 			-- 点地移动
		if (ArrestPetInstance) then    --如果正在抓宠，取消抓宠		
			ArrestPetInstance.CancelCapture()
		end
	elseif type == 'drag_move' then -- 摇杆移动
	elseif type == 'skill' then 	-- 点击技能按钮, 包括普攻
	elseif type == 'fly' then 		-- 点击轻功按钮
	elseif type == 'switch' then 	-- 点击切怪按钮
    elseif type == 'charge' then 	-- 施法
        if GlobalManager.isHook == true then
		   local hookCombat = require "Logic/OnHookCombat"
		   hookCombat.SetHook(false)
        end
    end
end

function Hero:RefreshSkills()
	if MyHeroManager.heroData.skill_plan then
		local skills = MyHeroManager.heroData.skill_plan[MyHeroManager.heroData.cur_plan]
		if skills == nil then
			skills = {}
		end 
		for i = 1, 4 do 
			if skills[i] then
				self.skillManager:AddSkill(i, tostring(skills[i]), MyHeroManager.heroData.skill_level[i])
			else
				self.skillManager:RemoveSkill(i)
			end
		end
	end
	UIManager.GetCtrl(ViewAssets.MainLandUI).UpdateSkill()
end

local function findUnitOfThisScene(unitSceneId)
	local target = SceneManager.GetEntityManager().QueryPuppet(function(v)
		if v.data.ID and v.data.ID == unitSceneId then
			return true
		end
		if v.data.ElementID and v.data.ElementID == unitSceneId then
			return true
		end
		return false
	end)
	return target
end

-- 走到本场景某个单位旁边
local function moveToUnitOfThisScene(uid, unitSceneId, distance, callback)
	local unit = SceneManager.GetEntityManager().GetPuppet(uid)
	if not unit or unit:IsDied() or unit:IsDestroy() then
    	error('hero is nil or died or destroy')
    end

	local curSceneData = SceneManager.GetCurSceneData()
	local scenesetting = curSceneData.SceneSetting
	local rootScheme = SceneManager.GetCurBigScheme()
	local sceneScheme = rootScheme[scenesetting]
	local objcfg = sceneScheme[unitSceneId/1]
	if not objcfg then
		error("没有找到scene object id=" .. unitSceneId)
		return
	end

	local pos = Vector3.New(objcfg.PosX, objcfg.PosY, objcfg.PosZ)
	if not Vector3.InDistance(unit:GetPosition(), pos, distance) then
	    unit:Moveto(pos, distance, function()
	    	if callback then
	    		local target = findUnitOfThisScene(unitSceneId)
		    	callback(target)
		    end
	    end)
	else
		if callback then
	    	local target = findUnitOfThisScene(unitSceneId)
			callback(target)
		end
	end
end	
-- 找某个npc, dis为找到时与npc的距离, 如果不在当前场景,则先切场景
function Hero:moveToUnit(unitSceneId, sceneType, sceneId, distance, callback)
	distance = distance or 1
	if not sceneType then
		sceneType = SceneManager.currentSceneType
	end
	if not sceneId then
		sceneId = SceneManager.currentSceneId
	end

	local uid = self.uid
	if (sceneType == constant.SCENE_TYPE.WILD or sceneType == constant.SCENE_TYPE.CITY) and 
	   (SceneManager.currentSceneType == constant.SCENE_TYPE.WILD or SceneManager.currentSceneType == constant.SCENE_TYPE.CITY) then
		if sceneId == SceneManager.currentSceneId then -- 在相同的场景, 直接走过去
			moveToUnitOfThisScene(uid, unitSceneId, distance, callback)
		else -- 不同的场景, 先切场景
			self:Convey(sceneId, function()
				moveToUnitOfThisScene(uid, unitSceneId, distance, callback)
			end)
		end
	else
		error("暂时未实现去副本/竞技场和主城/野外的传送 scenetype=" .. sceneType)
	end
end
-- 进入某个场景
function Hero:moveToScene(sceneType, sceneId, callback)
	if not sceneType then
		sceneType = SceneManager.currentSceneType
	end
	if not sceneId then
		error('Hero:moveToScene sceneid is nil ')
	end

	if (sceneType == constant.SCENE_TYPE.WILD or sceneType == constant.SCENE_TYPE.CITY) and 
	   (SceneManager.currentSceneType == constant.SCENE_TYPE.WILD or SceneManager.currentSceneType == constant.SCENE_TYPE.CITY) then
		if sceneId == SceneManager.currentSceneId then -- 在相同的场景, 直接走过去
			if callback then
				callback()
			end
		else -- 不同的场景, 先切场景
			self:Convey(sceneId, function()
				if callback then
					callback()
				end
			end)
		end
	else
		error("暂时未实现去副本/竞技场和主城/野外的传送 scenetype=" .. sceneType)
	end
end

function Hero:OnAutoTakeMedicine()  --自动吃药
	if self:IsDied() or self:IsDestroy() then
		return 
	end
	local hp_max = self.hp_max()
	local mp_max = self.mp_max()
	if not self.behavior  or GRunOnClient == false or SceneManager.currentSceneType == constant.SCENE_TYPE.ARENA then
		return
	end
	if hp_max == 0 or mp_max == 0 then
		error(" Hero:OnAutoTakeMedicine: hp_max == 0 or mp_max == 0")
		return
	end
	local hpRadio = self.hp / hp_max --自动加血
	if GlobalManager.AutoHealthSupple and self.hp > 0 and hpRadio < GlobalManager.HealthSuppleThreshold/100 then
		BagManager.UseRecoveryDrug(GlobalManager.HealthSuppleDurgID)
	end

	local mpRadio = self.mp / mp_max
	if GlobalManager.AutoMagicSupple and self.hp > 0 and mpRadio < GlobalManager.MagicSuppleThreshold/100 then
		BagManager.UseRecoveryDrug(GlobalManager.MagicSuppleDurgID)
	end
	
end

function Hero:ReduceHp(num, attacker, event_type)
	Dummy.ReduceHp(self, num, attacker, event_type)

end

function Hero:ReduceMp(num, attacker)
	Dummy.ReduceMp(self, num, attacker)

end

-- 注:一定要是已经切到该怪物所在的场景,才调用
function Hero:StartKillMonster(unitSceneId, taskData)
	self:StopKillMonster()
	moveToUnitOfThisScene(self.uid, unitSceneId, 2, function()
		self.stateManager:StartTick()
		self.stateManager:GotoState(StateType.eKillMonster, taskData)
	end)
end
function Hero:StopKillMonster()
	if self.stateManager.currentState.stateType == StateType.eKillMonster then
		self.stateManager:StopTick()
	end
end
function Hero:StopMove()
    local DestinationEffect = require "Logic/Effect/DestinationEffect"
    DestinationEffect.HideEffect()
	Dummy.StopMove(self)
end

function Hero:StopMoveImmediately()
    local DestinationEffect = require "Logic/Effect/DestinationEffect"
    DestinationEffect.HideEffect()
	Dummy.StopMoveImmediately(self)
end

function Hero:Moveto(pos, stopDistance, onArrived, ...)
    local DestinationEffect = require "Logic/Effect/DestinationEffect"
    DestinationEffect.HideEffect()
	Dummy.Moveto(self,pos, stopDistance, onArrived, ...)
    self:StopConvey()
end	
function Hero:MoveDir(direction)
    local DestinationEffect = require "Logic/Effect/DestinationEffect"
    DestinationEffect.HideEffect()
	Dummy.MoveDir(self,direction)
end
return Hero
