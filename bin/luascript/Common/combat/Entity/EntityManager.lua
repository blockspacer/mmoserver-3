---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/24
-- desc： entity管理
---------------------------------------------------
local Vector3 = Vector3
local const = require "Common/constant"

MemListener = require "Common/basic/memoryListener"

require "Common/basic/SceneObject"

local CreateHero = require "Common/combat/Entity/Hero"
local CreateDummy = require "Common/combat/Entity/Dummy"
local CreateNPC = require "Common/combat/Entity/NPC"
local CreateDungeonNPC = require "Common/combat/Entity/DungeonNPC"
local CreateMonster = require "Common/combat/Entity/Monster"
local CreateMonsterCamp = require "Common/combat/Entity/MonsterCamp"
local CreatePet = require "Common/combat/Entity/Pet"
local CreateWildPet = require "Common/combat/Entity/WildPet"
local CreateSummon = require "Common/combat/Entity/Summon"
local CreateDrop = require "Common/combat/Entity/Drop"
local CreateConveyTool = require "Common/combat/Entity/ConveyTool"
local CreateBullet = require "Common/combat/Entity/Bullet"
local CreateEmptyGO = require "Common/combat/Entity/EmptyGO"
local CreateRushMonster = require "Common/combat/Entity/RushMonster"
local CreateTrick = require "Common/combat/Entity/Trick"
local CreateBarrier = require "Common/combat/Entity/Barrier"
local CreateTransportFleet = require "Common/combat/Entity/TransportFleet"
local CreateTransport = require "Common/combat/Entity/Transport"
local CreateTransportGuard = require "Common/combat/Entity/TransportGuard"

local IDManager 
if not GRunOnClient then
	IDManager =  require "idmanager"
end

local flog
if not GRunOnClient then
	flog = require "basic/log"
end

EntityType = {
	Hero = 1, 
	Dummy = 2,
	Monster = 4,
	NPC = 8,
	Pet = 16,
	WildPet = math.pow(2, 5),
	Summon = math.pow(2, 6), 	-- 召唤物
	Drop = math.pow(2, 7),		-- 掉落物
	SceneObj = math.pow(2, 8), 	-- 场景元素
	Bullet = math.pow(2, 9), 	-- 子弹
	EmptyGO = math.pow(2, 10), -- 空对象
	Trick = math.pow(2, 11), -- 机关
	ConveyTool = math.pow(2, 12), --传送阵
	Barrier = math.pow(2, 13), --屏障
	MonsterCamp = math.pow(2, 14), -- 阵营怪物
	Transport = math.pow(2, 15), --运输车
	TransportFleet = math.pow(2, 16),  --运输车队
	TransportGuard = math.pow(2, 17),  --运输车守卫npc
};

-- 战斗状态
FightState = {
	Normal = 1,
	Fight = 2,
}

EntitySource = {
	Default = 1,
	AOI = 2,
}

local scheme = GetConfig("common_fight_base")
local GrowingPet = GetConfig("growing_pet")
local PvpCountryWar = GetConfig("pvp_country_war")

local function CreateEntityManager(scene)
	local self = CreateSceneObject(scene)

	self.hero = nil

	local killedNumDic = {} --被杀死的生物统计
	local puppetDic = {}
	local diedPuppetDic = {} -- 死亡列表, 注:列表单位只保存了data, uid, entityType见OnpuppetDead函数
	local puppetProxy = {}	--以proxy_id为key的map
	
	local destroyExist = function(uid)	
		if puppetDic[uid] then
			self.DestroyPuppet(uid)
		end
	end

	local insertToDict = function(unit)
		unit:Born()
		unit:EnterScene()
		puppetDic[unit.uid] = unit
		if unit.aoi_proxy then 
			puppetProxy[unit.aoi_proxy] = unit
		end 
		MemListener.add(unit, (unit.name or 'noname'))
	end

if GRunOnClient then
	self.CreateHero = function(data) 
		if self.hero then
			self.DestroyPuppet(self.hero.uid)
			self.hero = nil
		end
		local hero = CreateHero(self.scene, data, nil)
		insertToDict(hero)     
		self.hero = hero
		
		self.hero:RefreshSkills()

		-- self.GetEntityManager().hero:SetNavMesh(true)
--[[
		-- 轻功用
		hero.behavior:SetOnFall(hero.lowFlyManager.OnFall) 
		hero.behavior:SetOnColliderHit(hero.lowFlyManager.ColliderHit) 
]]
		--UIManager.GetCtrl(ViewAssets.MainLandUI).InitAllSkill()
		
		-- 宠物不受aoi约束，与英雄同时创建
		-- if data.pet_list then
		-- 	for k, v in pairs(data.pet_list)do
		-- 		if v.fight_index and v.fight_index > 0 then
		-- 			local pet = self.CreatePet(v)
		-- 		end
		-- 	end
		-- end
		return self.hero
	end
end

	self.CreateDummy = function(data)
		destroyExist(data.entity_id)

		local dummy = CreateDummy(self.scene, data, nil)
		insertToDict(dummy)
		return dummy
	end

	self.CreateNPC = function(data)
		destroyExist(data.entity_id)

		local npc = CreateNPC(self.scene, data, nil)
		insertToDict(npc)
		return npc
	end

	self.CreateDungeonNPC = function(data)
		destroyExist(data.entity_id)

		local npc = CreateDungeonNPC(self.scene, data, nil)
		insertToDict(npc)
		return npc
	end

	self.CreateMonster = function(data)
		destroyExist(data.entity_id)

		local monster = CreateMonster(self.scene, data, nil)
		-- local monster = CreateRushMonster(self.scene, data, nil)
		insertToDict(monster)
		return monster
	end

	self.CreateMonsterCamp = function(data)
		destroyExist(data.entity_id)

		local monster = CreateMonsterCamp(self.scene, data, nil)
		insertToDict(monster)
		return monster
	end

	self.CreateWildPet = function(data)		
		destroyExist(data.entity_id)

		local wildPet = CreateWildPet(self.scene, data, nil)
		insertToDict(wildPet)
		return wildPet
	end

	self.CreateSummon = function(data)
		destroyExist(data.entity_id)

		local t = CreateSummon(self.scene, data)
		insertToDict(t)
		return t
	end

	self.CreateDrop = function(data)
		destroyExist(data.entity_id)
		local drop = CreateDrop(self.scene, data)
		insertToDict(drop)
		return drop
	end

	self.CreatePet = function(data)	
		destroyExist(data.entity_id)

		local pet = CreatePet(self.scene, data, nil)
		insertToDict(pet)

		return pet
	end

	self.CreateBullet = function(data)
		destroyExist(data.entity_id)

		local bullet = CreateBullet(self.scene, data, nil)
		insertToDict(bullet)

		return bullet
	end

	self.CreateEmptyGO = function(data)
		destroyExist(data.entity_id)

		local go = CreateEmptyGO(self.scene, data)
		insertToDict(go)

		return go
	end

	self.CreateEffectObj = function(posX, posY, posZ, resName, rootName, recyle, pos, angle, scale, detach, lossyScale)
        local entity_id = self.GenerateEntityUID()
        local go = self.CreateEmptyGO({
            entity_id = entity_id,
            posX = posX,
            posY = posY,
            posZ = posZ,
        })
        go:AddEffect(resName, rootName, recyle, pos, angle, scale, detach, lossyScale)
        self:GetTimer().Delay(recyle,
        	function()
            	self.DestroyPuppet(entity_id)
        	end)
	end

	self.CreateEffectOnServer = function(posX, posY, posZ, resName, speed)
		local puppetData = {
            entity_id = IDManager.get_valid_uid(),
			posX = posX or 0,
            posY = posY or 0,
            posZ = posZ or 0,
            res = 'Toy/empty',
            scale = 1,
            effect = resName,
            speed = speed,
        };
		return self.CreateSummon(puppetData)
	end
	
	self.CreateBarrier = function(data)
		destroyExist(data.entity_id)
		
		local go = CreateBarrier(self.scene, data)
		insertToDict(go)
		return go
	end

	self.CreateUnitByEntityType = function(data, entityType)
		if entityType == EntityType.Bullet then
			return self.CreateBullet(data)
		end
	end
	
	self.getMonsterPropery = function(monsterSetting, entityType)	
		local key = monsterSetting.Level .. "_" .. monsterSetting.Power .. "_" .. monsterSetting.Type

		local speed = 0
		if entityType == EntityType.Monster or
			entityType == EntityType.WildPet then
			speed = commonFightBase.Parameter[28].Value
		elseif entityType == EntityType.NPC then
			speed = commonFightBase.Parameter[30].Value
		elseif entityType == EntityType.Transport or 
			   entityType == EntityType.TransportGuard then
			speed = PvpCountryWar.Parameter[12].Value[1]
		end

		if scheme.Attribute[key] then
			local config = scheme.Attribute[key]
	    	local property = 
	        {
	            [1] = config.PhysicAttack,
	            [2] = config.MagicAttack,
	            [3] = config.PhysicDefence,
	            [4] = config.MagicDefence,
	            [5] = config.Hp,
	            [6] = config.Hit,
	            [7] = config.Crit,
	            [8] = config.Miss,
	            [9] = config.ResistCrit,
	            [10] = config.Block,
	            [11] = config.BreakUp,
	            [12] = config.Puncture,
	            [13] = config.Guardian,
	            [14] = speed,
	        }
	        return property
	    else
	    	error("not found Attribute: key =" .. key)
	    	return {}
	    end
	end
	
	-- 根据副本记录生成一个屏障
	self.CreateSceneBarrier = function(data)
		local data = {
			entity_id = IDManager.get_valid_uid(),
			posX = data.PosX or 0,
            posY = data.PosY or 0,
            posZ = data.PosZ or 0,
			ForwardX = data.ForwardX or 0,
			ForwardY = data.ForwardY or 0,
			ForwardZ = data.ForwardZ or 0,
			Para1 = data.Para1,
			Para2 = data.Para2,
			ModelID = data.ModelID or 0,
			ElementID = data.ID or 0,
			sceneType = data.Type,
		}
		self.CreateBarrier(data)
	end
	
	-- 根据副本记录生成一个对象
	self.CreateScenePuppet = function(data, entityType)
		local monsterSetting = self.GetMonsterSetting(data.MonsterID)

		local faction_id 
		if not GRunOnClient then
			local scene = scene_manager.find_scene(self.GetSceneID())
			faction_id = scene.faction_id
		end
        local puppetData = {
            entity_id = IDManager.get_valid_uid(),
			posX = data.PosX or 0,
            posY = data.PosY or 0,
            posZ = data.PosZ or 0,
            MonsterID = data.MonsterID or 0,
            ModelID = data.ModelID or 0,
            ElementID = data.ID or 0,
            DropID = data.DropID or 0,
            Name = data.Name or 0,
            Name1 = data.Name1 or '',
            Scale = data.Scale or 1,
            faction_id = faction_id,
            Para1 = data.Para1,
            Para2 = data.Para2,
            LimitedRadius = data.LimitedRadius,
            sceneType = data.Type,
            property = self.getMonsterPropery(monsterSetting, entityType),
            level = monsterSetting.Level,
			Power = monsterSetting.Power,
			Type = monsterSetting.Type,
			monsterSetting = monsterSetting,
			AttackType = monsterSetting.AttackType,
			Camp = data.Camp or 0,
        };
        if entityType == EntityType.Monster then
        	return self.CreateMonster(puppetData)
        elseif entityType == EntityType.MonsterCamp then
        	return self.CreateMonsterCamp(puppetData)
		elseif entityType == EntityType.Transport then
			puppetData.TransporterID = data.TransporterID
			return self.CreateTransport(puppetData)
		elseif entityType == EntityType.TransportGuard then
			puppetData.TransporterID = data.TransporterID
			return self.CreateTransportGuard(puppetData)
        elseif entityType == EntityType.WildPet then
			return self.CreateWildPet(puppetData)
		elseif entityType == EntityType.NPC then
			if GRunOnClient then
				return self.CreateDungeonNPC(puppetData)
			else
				return scene_manager.create_dungeon_npc(self.GetSceneID(), puppetData)
			end
		end
	end

	self.CreateSceneBullet = function(data)
		local unit = self.GetPuppet(data.owner_id)
		if unit == nil or unit:IsDied() or unit:IsDestroy() then
			return nil
		end
        data.entity_id = self.GenerateEntityUID()
        local hook_point = MathHelper.GetForwardVector(
			unit, Vector3.New(data.relativePosX, data.relativePosY, data.relativePosZ))
        data.posX = hook_point.x
        data.posY = hook_point.y
        data.posZ = hook_point.z
        return self.CreateBullet(data)
	end

	self.CreateSceneNPC = function(sceneNPCTable)
		if GRunOnClient then
	        for k,v in pairs(sceneNPCTable) do
	            if v.Type == 2 then
	                local npcdata = table.copy(v)
	                npcdata.posX = npcdata.PosX
	                npcdata.posY = npcdata.PosY
	                npcdata.posZ = npcdata.PosZ
	                npcdata.entity_id = self.GenerateEntityUID()
	                npcdata.property = {
			            [5] = 10,
			        }
	                self.CreateNPC(npcdata)
	            end
	        end
	    end
    end
	
	self.CreateConveyTool = function(data) --创建传送阵
		destroyExist(data.entity_id)
		
		local go = CreateConveyTool(self.scene, data, nil)
		insertToDict(go)
		return go
	end
	
	self.CreateSceneConvey = function(data)   --通过场景数据创建传送阵
		
		local npcdata = table.copy(data)
		npcdata.entity_id = IDManager.get_valid_uid()
	    npcdata.posX = npcdata.PosX
        npcdata.posY = npcdata.PosY
        npcdata.posZ = npcdata.PosZ
		npcdata.ElementID = npcdata.ID or 0,
		self.CreateConveyTool(npcdata)
	end
		
	self.CreateTrick = function(data)
		if data.entity_id then
			destroyExist(data.entity_id)
		else
			data.entity_id = IDManager.get_valid_uid()
		end
	    data.posX = data.PosX
        data.posY = data.PosY
        data.posZ = data.PosZ
		data.ElementID = data.ID or 0
        
		local go = CreateTrick(self.scene, data)
		insertToDict(go)

		return go
	end
	
	self.CreateTransportFleet = function(data)
		destroyExist(data.entity_id)
		
		local go = CreateTransportFleet(self.scene, data)
		insertToDict(go)
		return go
	end
	
	self.CreateTransport = function(data)
		destroyExist(data.entity_id)
		
		local go = CreateTransport(self.scene, data)
		insertToDict(go)
		return go
	end
	
	self.CreateTransportGuard = function(data)
		destroyExist(data.entity_id)
		
		local go = CreateTransportGuard(self.scene, data)
		insertToDict(go)
		return go
	end

	--self.CreateSceneChuanSongzhen = function(sceneID)
	
		--local config = GetConfig("common_scene")
        --local sceneTable = config[config.MainScene[sceneID].SceneSetting]
        --for k,v in pairs(sceneTable) do
            --if v.Type == 13 then
  
				--local chuanSongZhen = ResourceManager.CreateEffect('Common/eff_common@chuansongmen')
				--local pos = Vector3.New(v.PosX, v.PosY, v.PosZ)
				--chuanSongZhen.transform.position = pos
            --end
        --end
	--end
	self.ClearRefrence = function(puppet)
		for k, v in pairs(puppetDic) do
			if v.target == puppet then
				v.target = nil
			end
			if v.attacker == puppet then
				v.attacker = nil
			end
		end
	end
    -- 有单位死亡
	self.OnPuppetDied = function(uid)
		local puppet = self.GetPuppet(uid)
		if not puppet then
			return
		end

		if self.isOnFightScene() then -- 如果是在战场景, 则将死亡的单位记录到死亡列表里
			diedPuppetDic[uid] = {
				data = table.copy(puppet.data),
				uid = uid,
				entityType = puppet.entityType,
			}
		end

		if not killedNumDic[puppet.entityType] then
			killedNumDic[puppet.entityType] = 0
		end
		killedNumDic[puppet.entityType] = killedNumDic[puppet.entityType] + 1
		
		if GRunOnClient then
	        if TargetManager.GetTarget() == puppet then
	            TargetManager.ClearTarget()
	        end
	    end
		self.ClearRefrence(puppet)
	end
	
	-- 复活单位
	self.ResurrectPuppet = function(uid, data)
		local p = puppetDic[uid] 
		if not p then
			print("error!!! nor found puppet uid=" .. uid)
			return
		end
		p:Resurrect(data)
	end

	-- 销毁单位
	self.DestroyPuppet = function(entityUID)
		local puppet = self.GetPuppet(entityUID)
		if puppet then
			if puppet.aoi_proxy then
				puppetProxy[puppet.aoi_proxy] = nil
			end	
			if puppet.behavior then 
				puppet:Destroy()
			else
				print('该单位已经销毁')
			end
			puppetDic[entityUID] = nil
			self.ClearRefrence(puppet)
		end
       
		if GRunOnClient then
	        if TargetManager.GetTarget() == puppet then
	            TargetManager.ClearTarget()
	        end
	        if self.hero == puppet then
	        	self.hero = nil
	        end
	    end
	end

	self.DestroyAll = function()
		for k, v in pairs(puppetDic) do
			if v.behavior then
				v:Destroy()
			else
				print('该单位已经销毁')
			end
		end
		puppetDic = {}
		diedPuppetDic = {}
		killedNumDic = {}
        self.hero = nil	
	end

	self.GetPuppet = function(entityUID)
		return puppetDic[entityUID]
	end
	
	--获取某生物类型的数量
	self.GetNums = function(entityType)		
		local num = 0
		for k, v in pairs(puppetDic) do		
			if v.entityType == entityType and not v:IsDied() then			
				num = num + 1
			end
		end		
		return num
	end

	self.GetKilledNums = function(entityType)
		if killedNumDic[entityType] then
			return killedNumDic[entityType]
		end
		return 0
	end

	-- 查看某单位是否死了
	self.IsPuppetDead = function(elementID)
		if self.isOnFightScene() then 
			for k, v in pairs(diedPuppetDic) do
				if v.data.ElementID == elementID then
					return true
				end
			end
			return false
		else
			error('IsPuppetDead()接口 只在战斗场景可用')
		end		
	end

	local function getEntityInAOI(scene_id, x, z)
		if GRunOnClient then
			return puppetDic
		end
		local ids = _get_entities_in_aoi( scene_id, x, z, 20)
		local units = {}
		for _, id in pairs(ids) do
			unit = puppetProxy[id]
			if unit then
				units[unit.uid] = unit
			end
		end

        return units
	end

	self.QueryDeadPuppetAsArray = function(selector)
		local deads = {}		
		for k, v in pairs(diedPuppetDic) do
			if selector(v) then
				table.insert(deads, v)
			end
		end
		return deads
	end
	-- 全局查询单个
	self.AOIQueryPuppet = function(scene_id, x, z, selector)
		local aoi_units = getEntityInAOI(scene_id, x, z)
		if aoi_units == nil then
			return 
		end
		for k, v in pairs(aoi_units) do
			if selector(v) then
				return v
			end
		end
		return nil
	end

		-- 查询多个
	self.AOIQueryPuppets = function(scene_id, x, z, selector)
		local aoi_units = getEntityInAOI(scene_id, x, z)
		if aoi_units == nil then
			return {}
		end
		local puppets = {}
		for k, v in pairs(aoi_units) do
			if selector(v) then
				puppets[k]= v
			end
		end
	   return puppets
	end

	-- 查询单个
	self.QueryPuppet = function(selector)
		for k, v in pairs(puppetDic) do
			if selector(v) then
				return v
			end
		end
		return nil
	end

	-- 查询多个
	self.QueryPuppets = function(selector)
		local puppets = {}
		for k, v in pairs(puppetDic) do
			if selector(v) then
				puppets[k]= v
			end
		end
	   return puppets
	end
	self.QueryPuppetsAsArray = function(selector)
		local puppets = {}
		for k, v in pairs(puppetDic) do
			if selector(v) then
				table.insert(puppets, v)
			end
		end
	   return puppets
	end

	local lastUID = 2147483647
	self.GenerateEntityUID = function()
		lastUID = lastUID + 1
		return tostring(lastUID)
	end

	self.isOnFightScene = function()
		local sceneType = self.GetSceneType()
		if sceneType == const.SCENE_TYPE.WILD or sceneType == const.SCENE_TYPE.CITY or sceneType == const.SCENE_TYPE.FACTION then
			return false
		else
			return true
		end
	end

	self.Init = function()
	end

    self.SetAllEntityEnabled = function(enabled)
        for k, v in pairs(puppetDic) do
			if v then
                if v.entityType == EntityType.Hero or 
	                v.entityType == EntityType.Dummy or 
	                v.entityType == EntityType.Monster or 
	                v.entityType == EntityType.NPC or 
	                v.entityType == EntityType.Pet or 
	                v.entityType == EntityType.WildPet then
					v:SetEnabled(enabled)
				end
			end
		end
	end
	self.SetEntityEnabled = function(entity_id,enabled)
		if puppetDic[entity_id] ~= nil then
			puppetDic[entity_id]:SetEnabled(enabled)
		end
	end

	self.GetEntityEnabled = function(entity_id)
		if puppetDic[entity_id] ~= nil then
			return puppetDic[entity_id]:GetEnabled()
		end
	end

	self.SetAllEntityAttackStatus = function(status)
		for k, v in pairs(puppetDic) do
			if v then
                if v.entityType == EntityType.Hero or
	                v.entityType == EntityType.Dummy or
	                v.entityType == EntityType.Monster or
	                v.entityType == EntityType.NPC or
	                v.entityType == EntityType.Pet or
	                v.entityType == EntityType.WildPet then
					v:SetAttackStatus(status)
				end
			end
		end
	end

	self.SetEntityAttackStatus = function(entity_id,status)
		if puppetDic[entity_id] ~= nil then
			puppetDic[entity_id]:SetAttackStatus(status)
		end
	end

	self.GetEntityAttackStatus = function(entity_id)
		if puppetDic[entity_id] ~= nil then
			return puppetDic[entity_id]:GetAttackStatus()
		end
		return true
	end

	self.UpdateCureHatred = function(cure,curer)
		for k, v in pairs(puppetDic) do
			if v ~= nil and v.entityType == EntityType.Monster then
				v:UpdateCureHatred(cure,curer)
			end
		end
	end

	--是否在任意仇恨列表
	self.IsInAnyHatredList = function(uid)
		for k, v in pairs(puppetDic) do
			if  v.IsInHatredList and  v:IsInHatredList(uid) == true then
				return true
			end
		end
		return false
	end

	self.Init()
	return self
end

return CreateEntityManager