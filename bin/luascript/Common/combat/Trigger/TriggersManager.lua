---------------------------------------------------
-- auth： zhangzeng
-- date： 2016/9/8
-- desc： 加载触发器
---------------------------------------------------
local Vector3 = Vector3
local const = require "Common/constant"
require "Common/basic/Event"
local CreateAreaTrigger = require "Common/combat/Trigger/AreaTrigger"
local CreateTimerTrigger = require "Common/combat/Trigger/TimerTrigger"
local CreateNumsTrigger = require "Common/combat/Trigger/NumsTrigger"
local CreateDatasTrigger = require "Common/combat/Trigger/DatasTrigger"
local CreateUnitSetTrigger = require "Common/combat/Trigger/UnitSetTrigger"
local AreaTriggerManager = require "Common/combat/Trigger/AreaTriggerManager"
local CreateTimePointTrigger = require "Common/combat/Trigger/TimePointTrigger"

TriggerType = {
	Monster = 1, 
	Player = 2,
	All = 3,
	NPC = 4,
};

local trigger;
local triggerType = 16;                                                  --触发器类型

--[[  本类用到数据data结构的，方便查看内容
local data = {            
            ID = 501001,
            Type = 1,
            Name = 5000001,
            DesignName = "出生点",
            ModelID  = 10002,
            Scale = 100.0,
            MonsterID = 0,
            DropID = "0",
            Para1 = "0",
            Para2 = 0.0,
            PosX = 0.0,
            PosY = 0.0,
            PosZ = 0.0,
            ForwardX = 0.0,
            ForwardY = 0.0,
            ForwardZ = 0.0,
            LimitedRadius = 0.0,
            IsTrigger = 0,
            TriggerTypeID = 0,
            TrggerPara1 = 0,
            TrggerPara2 = "0",
            EventResponse = "0",
            }
]]

local SceneObject = require "Common/basic/SceneObject2"
local TriggersManager = ExtendClass(SceneObject)

function TriggersManager:__ctor(scene)
    self.scheme = nil
	self.triggers = {}
	
	self.AreaTriggerManager = AreaTriggerManager(scene)
end

function TriggersManager:OnGameBegin(scheme)
    self:Release()
    
    self.scheme = scheme
	if (not self.scheme) then
		error("not found dungeon setting name=" .. name)
	end
    
    self:ReadTriggers()
    self.AreaTriggerManager:StartTick()
end
	
function TriggersManager:FindTriggersObject(id)
	for k, v in pairs(self.triggers) do
	
		if (tonumber(v.data.ID) == tonumber(id)) then
			
			return v, k
		end
	end
end
    
function TriggersManager:TriggerCommont(eventResponse)                         --触发器消息回调

    local eventResponseValues = string.split(eventResponse, '|')
    --local commontCreateDic = {[6] = self.CreateTrigger, [7] = self.CreateMonster, [8] = self.CreateBarrier, [10] = self.CreateWildPet }		
	
    local items = {}
    for k, v in pairs(eventResponseValues) do
		local spe = string.sub(v, 1, 1)
		if (spe == "!") then   	
			local value = string.sub(v, string.find(v, "%w+"))   	--销毁id为v的object	
			local target = self:GetEntityManager().QueryPuppet(
			function(v)
				if v.data.ElementID == tonumber(value) then
					return true
				end
				return false
			end
			)
			if target then
				self:GetEntityManager().DestroyPuppet(target.uid)
			end
			
			local object,i = self:FindTriggersObject(value)			--触发器
			if object then
				object:Destroy()
				table.remove(self.triggers, i)
			end
		else
			local data = string.split(v, '=')
			local rate = data[2]
			if rate == nil then
				rate = 100
			end
			
			local randomValue = math.random(100)
			if randomValue > tonumber(rate) then --没有达到触发概况
				return
			end
			
			local sceneValues = self.scheme[tonumber(data[1])]
			--sceneValues的数据结构跟data的相同
			--[[
			local callback = commontCreateDic[sceneValues.Type]
        
			if (callback) then
        
				--print("callback commontCreateDic")
				--print(sceneValues.Type)
				callback(sceneValues)
        
			end
			]]
			
			local item = self:CreateItems(sceneValues)
			table.insert( items, item)
		end
        
    end

    return items
    
end

function TriggersManager:CreateItems(data)

	if data == nil then
		return 
	end
	local commontCreateDic = {
		[11] = self.OnBorn, 
		[2] = self.CreateDungeonNPC, 
		[16] = self.CreateTrigger, 
		[3] = self.CreateMonster, 
		[23] = self.CreateMonsterCamp,
		[24] = self.CreateMonster,
		[25] = self.CreateMonsterCamp,
		[26] = self.CreateMonsterCamp,
		[27] = self.CreateMonsterCamp,
		[28] = self.CreateMonsterCamp,
		[18] = self.CreateBarrier, 
		[4] = self.CreateWildPet,
		[13] = self.CreateConveyTool,
		[22] = self.CreateTrick,
 	}
	local callback = commontCreateDic[data.Type]

    if (callback) then
	
		return callback(self, data)
	end
end
	
function TriggersManager:OnBorn(data)	

end

function TriggersManager:CreateBarrier(data)
	if not GRunOnClient then
		local mData = table.copy(data)
		return self:GetEntityManager().CreateSceneBarrier(mData)
	end
end

function TriggersManager:CreateTrick(data)
	if not GRunOnClient then
		local mData = table.copy(data)
    	return self:GetEntityManager().CreateTrick(mData)
	end
end

function TriggersManager:CreateConveyTool(data)
	if not GRunOnClient then
		local sceneType = self:GetSceneType()
		if self:GetSceneType() == const.SCENE_TYPE.FACTION then --帮派领地特殊处理
			local scene = scene_manager.find_scene(self:GetSceneID())
			if scene.country then
				if scene.country ~= data.Camp then
					return
				end
			end
		end

		local mData = table.copy(data)
    	return self:GetEntityManager().CreateSceneConvey(mData)
	end
end

function TriggersManager:CreateMonster(data)  
	if not GRunOnClient then  
		local mData = table.copy(data)
	    return self:GetEntityManager().CreateScenePuppet(mData, EntityType.Monster)
	end
end

function TriggersManager:CreateMonsterCamp(data)  
	if not GRunOnClient then  
		local mData = table.copy(data)
	    return self:GetEntityManager().CreateScenePuppet(mData, EntityType.MonsterCamp)
	end
end

function TriggersManager:CreateDungeonNPC(data)
	if not GRunOnClient then
		local mData = table.copy(data)
	    return self:GetEntityManager().CreateScenePuppet(mData, EntityType.NPC)
	end
end

function TriggersManager:CreateWildPet(data)
	if not GRunOnClient then
		local mData = table.copy(data)
		return self:GetEntityManager().CreateScenePuppet(mData, EntityType.WildPet)
	end
end

function TriggersManager:CreateTimerTrigger(data)                              --创建时间触发器
	if not GRunOnClient then
		local timerTrigger = CreateTimerTrigger(self.scene, data, self.TriggerCommont)
		timerTrigger:Start()
		return timerTrigger
	end
end

function TriggersManager:CreateAreaTrigger(data)                               --创建区域触发器
    if not GRunOnClient then
		local areaTrigger = CreateAreaTrigger(self.scene, data, self.TriggerCommont)
		areaTrigger:Start()
		return areaTrigger
	end
end

function TriggersManager:CreateNumsTrigger(data) 
	if not GRunOnClient then							--创建数量触发器
		local numsTrigger = CreateNumsTrigger(self.scene, data, self.TriggerCommont)
		numsTrigger:Start()
		return numsTrigger
	end
end

function TriggersManager:CreateDatasTrigger(data)
	if not GRunOnClient then                              --创建数据触发器
		local datasTrigger = CreateDatasTrigger(self.scene, data, self.TriggerCommont)
		datasTrigger:Start()
		return datasTrigger
	end
end

function TriggersManager:CreateUnitSetTrigger(data)
	if not GRunOnClient then
		local trigger = CreateUnitSetTrigger(self.scene, data, self.TriggerCommont)
		trigger:Start()
		return trigger
	end
end

function TriggersManager:CreateTimePointTrigger(data)
	if not GRunOnClient then
		local trigger = CreateTimePointTrigger(self.scene, data, self.TriggerCommont)
		trigger:Start()
		return trigger
	end
end

function TriggersManager:CreateTrigger(data)                                   --创建触发器

    local triggerTypeID = data.TriggerTypeID
    local triggerDic = {self.CreateTimerTrigger--[[创建时间触发器]], self.CreateAreaTrigger--[[创建区域触发器]],
                        self.CreateNumsTrigger--[[创建数量触发器]], self.CreateDatasTrigger--[[创建数据触发器]],
                    	self.CreateUnitSetTrigger--[[创建单位集合触发器]], self.CreateTimePointTrigger--[[创建时刻点触发器]]}
    
    local callback = triggerDic[triggerTypeID]
    if (callback) then
			
		local ret = callback(self, data)
		if (ret) then
		
			table.insert(self.triggers, ret)
		end
    end
end

function TriggersManager:ReadTriggers()
		
    for k, v in pairs(self.scheme) do
		if (v.IsTrigger == 0) then   --不需要触发
    
			if (v.Type == triggerType) then        --触发器
                
				--v的数据结构跟data的相同
				self:CreateTrigger(v) 
			else
				self:CreateItems(v)
			end
		end
    end
end

function TriggersManager:Release()
	for k, v in pairs(self.triggers) do
	
		v:Destroy()
	end
	self.triggers = {}
	self.AreaTriggerManager:Destroy()
end

return TriggersManager