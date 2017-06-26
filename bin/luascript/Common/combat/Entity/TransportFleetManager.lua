---------------------------------------------------
-- auth： zhangzeng
-- date： 2017/5/15
-- desc： TransportFleetManager,逻辑层
---------------------------------------------------
local TransportFleetManager = {}
local TransportFleetTable = {}
local commonScene = GetConfig("common_scene")

local flog
local IDManager 
if not GRunOnClient then
	IDManager =  require "idmanager"
	flog = require "basic/log"
end

function TransportFleetManager:__ctor(scene)
end

function TransportFleetManager:GetTransportFleetItems(id)
	local items = {}
	local transportFleet = TransportFleetTable[id]
	if transportFleet then
		local itemsDic = transportFleet.itemsDic
		for k, v in pairs(itemsDic) do
			table.insert(items, k)
		end
	end
	return items
end

function TransportFleetManager:GetTransportFleet(id)
	return TransportFleetTable[id]
end

function TransportFleetManager:CreateTransportFleet(scene, data)
	local id = data.TransporterID
	if TransportFleetTable[id] == nil then
		local transportFleetData = {}
		transportFleetData.TransporterID = data.TransporterID
		transportFleetData.Type = data.Type
		transportFleetData.LimitedRadius = data.LimitedRadius
		transportFleetData.entity_id = IDManager.get_valid_uid()
		local transportFleet = scene:get_entity_manager().CreateTransportFleet(transportFleetData)
		transportFleet:SetParent(self)
		TransportFleetTable[id] = transportFleet
	end
	TransportFleetTable[id]:AddItem(data)
end

function TransportFleetManager:AddTransportFleetItem(id)
	local ret = true
	local transporterData = commonScene.Transporter
	for _,v in pairs(transporterData) do
		if v.TransporterID == id then
			local scene = scene_manager.find_scene(v.MapID)
			if scene == nil then
				return false
			end
			self:CreateTransportFleet(scene, v)
		end
	end
	
	return ret
end

function TransportFleetManager:RemoveTransportFleetItem(data)
	if data.sceneType ~= 24 then
		return
	end
	
	local id = data.TransporterID
	if TransportFleetTable[id] then
		TransportFleetTable[id]:RemoveItem(data)
	end
end

function TransportFleetManager:DeleteTransportFleet(id, isAll)  -- isAll为true代表运输车到达终点，为false代表运输车被杀死
	local transportFleet = TransportFleetTable[id]
	if isAll then
		if transportFleet then
			transportFleet:GetEntityManager().DestroyPuppet(transportFleet.uid)
			TransportFleetTable[id] = nil
		end
	else
		
	end
end

function TransportFleetManager:Destroy()
	for k, v in pairs(TransportFleetTable) do
		v:GetEntityManager().DestroyPuppet(v)
	end
	TransportFleetTable = {}
end

return TransportFleetManager

