---------------------------------------------------
-- auth： zhangzeng
-- date： 2016/12/20
-- desc： 传送阵
---------------------------------------------------
--require "Common/basic/LuaObject"
local Vector3 = Vector3
local CreateConveyToolBehavior = require "Logic/Entity/Behavior/ConveyToolBehavior"
local BaseObject = require "Common/combat/Entity/BaseObject"
local ConveyTool = ExtendClass(BaseObject)
local uitext = GetConfig('common_char_chinese').UIText
local CreateEventManager = require "Common/combat/Entity/EventManager"

local msg_pack
if not GRunOnClient then
	msg_pack = require "basic/message_pack"
end

function ConveyTool:GetName(data)
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

function ConveyTool:__ctor(scene, data, event_delegate)
	self.eventManager = CreateEventManager(self)
	self.entityType = EntityType.ConveyTool
	self.data = data
	self.uid = data.entity_id
	self.timeInfo = nil
	
	if not GRunOnClient then
		self.create_proxy_flag = true
		self.data.property = {[14] = 0}
	end
end

function ConveyTool:Born()
	BaseObject.Born(self)
	if not GRunOnClient and self.create_proxy_flag then
		self:CreateAOIProxy()
	end

	self.behavior = CreateConveyToolBehavior(self)
end

function ConveyTool:EnterScene()
end

function ConveyTool:Convey()
	local OnNextScene = function(ID)

		local data = {}
		data.func_name = 'on_map_teleportation'
		data.item_id = ID
		MessageManager.RequestLua(SceneManager.GetRPCMSGCode(), data)      --请求传送
	end

	if self.timeInfo then

		self:GetTimer().Remove(self.timeInfo)
		self.timeInfo = nil
	end
	self.timeInfo = self:GetTimer().Delay(0.2, OnNextScene, self.data.ID)
end
	
function ConveyTool:OnConvey()
	if ArenaManager.IsOnMatching() then
		UIManager.ShowDialog(uitext[1135003].NR, uitext[1135004].NR, uitext[1135005].NR, nil, function()
			ArenaManager.RequestCancelMatchMixFight()
			self:Convey()
		end)
	else
		self:Convey()
	end
end

function ConveyTool:GetBornPosition()
	return Vector3.New(self.data.posX, self.data.posY, self.data.posZ)
end

function ConveyTool:GetPosition()
	return self.behavior:GetPosition()
end

function ConveyTool:GetClientNeedInfo()
	local data = {}
	data.entity_id = self.data.entity_id
	data.ModelID  = self.data.ModelID
	data.ElementID = self.data.ElementID
	data.ID = self.data.ID
	data.Name1 = self.data.Name1
	data.Name = self.data.Name
    data.entity_type = self.entityType
	return msg_pack.pack(data)
end
	
function ConveyTool:Destroy()
	if self.timeInfo then
		self:GetTimer().Remove(self.timeInfo)
		self.timeInfo = nil
	end	
	self.eventManager.Fire('OnDestroy')
end

function ConveyTool:OnDestroy()
	BaseObject.OnDestroy(self)
	self.behavior:Destroy()
	self.behavior = nil
end

return ConveyTool