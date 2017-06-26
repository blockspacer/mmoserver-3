---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/3/13
-- desc： Toy
---------------------------------------------------
local Const = require "Common/constant"
local INDEX = Const.PROPERTY_NAME_TO_INDEX
local NAME = Const.PROPERTY_INDEX_TO_NAME

local scene_func
local flog
local broadcast_to_aoi

if not GRunOnClient then
	scene_func = require "scene/scene_func"
	flog = require "basic/log"
	broadcast_to_aoi = require("basic/net").broadcast_to_aoi
end

local SceneObject = require "Common/basic/SceneObject2"
local BaseObject = ExtendClass(SceneObject)
-- 物体，移动不受navmesh约束
function BaseObject:__ctor(scene)
end

function BaseObject:Born()
end

function BaseObject:EnterScene()
end

function BaseObject:OnDestroy()
	self:DestroyAOIProxy()
end

function BaseObject:GetClientNeedInfo()
	return nil
end

function BaseObject:CreateAOIProxy()
    if not GRunOnClient then
 
 	    if self.aoi_proxy ~= nil then
            self:DestroyAOIProxy()
        end

        local session_id = 0
        if self.data.server_object then
            session_id = self.data.server_object.session_id or self.data.server_object.client_session_id
            session_id = session_id or 0
        end


	    self.aoi_proxy = scene_func.create_aoi_proxy(
		    self.uid,
		    self.entityType,
		    self:GetClientNeedInfo(),
		    session_id,
		    self.data.property[INDEX.move_speed],
		    Const.ENTITY_VIEW_RADIUS)

	    if self.aoi_proxy == nil or self.aoi_proxy == 0 then
            flog("error", "player aoi_proxy is nil,create_aoi_proxy is unsuccessful")
            if self.aoi_proxy == 0 then
                self.aoi_proxy = nil
                assert(false)
            end
        end
        --print('Create proxy, in secne, uid', self.aoi_proxy,self:GetSceneID(), self.uid)
        local pos = self:GetBornPosition()
        self:EnterAOIScene(pos)
    end
end

function BaseObject:EnterAOIScene(pos)
    local res = scene_func.enter_aoi_scene(self.aoi_proxy,self:GetSceneID(),pos.x,pos.y,pos.z)
    if res == false then
        flog("error","enter_aoi_scene error, proxy_id="..self.aoi_proxy.." secneid="..self:GetSceneID())
        assert(false)
    end
end

function BaseObject:LeaveAOIScene()
    local res = scene_func.leave_aoi_scene(self.aoi_proxy,self:GetSceneID())
    if res == false then
        flog("error","enter_aoi_scene error, proxy_id="..self.aoi_proxy.." secneid="..self:GetSceneID())
        assert(false)
    end
end

function BaseObject:DestroyAOIProxy()
    if not GRunOnClient then
	    if self.aoi_proxy == nil then
            return
        end
        self:LeaveAOIScene()
        flog("info","destroy_aoi_proxy,entity type:"..self.entityType..",entity id:"..self.uid)
        scene_func.destroy_aoi_proxy(self.aoi_proxy)
        self.aoi_proxy = nil
    end
end

function BaseObject:UpdateAOIInfo()
    if self.aoi_proxy ~= nil then
	   scene_func.update_entity_info(self.aoi_proxy,self:GetClientNeedInfo())
    end
end

function BaseObject:BroadcastToAoi(msgid,msg)
    if self.aoi_proxy == nil then
        return
    end
    broadcast_to_aoi(self.aoi_proxy,msgid,msg, 0)
end

function BaseObject:BroadcastToAoiIncludeSelf(msgid, msg)
    if self.aoi_proxy == nil then
        return
    end
    broadcast_to_aoi(self.aoi_proxy, msgid, msg, 1)
end

function BaseObject:BroadcastUnitMsg(event, data)
    if not GRunOnClient then
        SyncManager.SC_BroadcastUnitMsg(self, event, data)
    end
end

function BaseObject:OnReceiveBroadcastUnitMsg(event, data)
end

return BaseObject
