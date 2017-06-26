--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/7 0007
-- Time: 14:41
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local msg_pack = require "basic/message_pack"
local flog = require "basic/log"
local _get_now_time_second = _get_now_time_second

local params = {}
local imp_pet_aoi = {}
imp_pet_aoi.__index = imp_pet_aoi

setmetatable(imp_pet_aoi, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_pet_aoi.__params = params

function imp_pet_aoi.__ctor(self)
    self.aoi_proxy = nil
    self.scene = nil
    self.scene_id = nil
    self.posX = nil
    self.posY = nil
    self.posZ = nil
    self.entity_info = {}
end

function imp_pet_aoi.imp_pet_aoi_init_from_dict(self,dict)
end

function imp_pet_aoi.imp_pet_aoi_write_to_dict(self,dict)
end

function imp_pet_aoi.imp_pet_aoi_write_to_sync_dict(self,dict)
end

function imp_pet_aoi.get_entityinfo(self)
    return msg_pack.pack(self.entity_info)
end

function imp_pet_aoi.enter_scene(self,owner)
    flog("tmlDebug","pet enter scene!")
    --local owner = onlineuser.get_user(self.owner_id)
    if owner == nil then
        flog("tmlDebug","pet enter scene,owner is nil!")
        return
    end

    local scene = owner:get_scene()
    if scene == nil then
        flog("tmlDebug","pet enter scene,owner's scene is nil!")
        return
    end
    if owner:get_aoi_scene_id() == nil then
        flog("tmlDebug","pet enter scene,owner's scene_id is nil!")
        return
    end
    local owner_puppet = owner:get_puppet()
    if owner_puppet == nil then
        flog("tmlDebug","pet enter scene,owner is not in scene!")
        return
    end
    if owner_puppet:IsDied() then
        flog("tmlDebug","pet enter scene,owner is die!")
        return
    end
    self.posX,self.posY,self.posZ = owner:get_pos()
    self:enter_aoi_scene(owner:get_aoi_scene_id())
end

function imp_pet_aoi.enter_aoi_scene(self,scene_id)
    local rebirth_time = self:get_rebirth_time()
    if rebirth_time ~= nil and rebirth_time > _get_now_time_second() then
        flog("tmlDebug","pet is die!!!")
        return 0
    end

    if self.scene ~= nil then
        self:leave_scene()
        self.scene = nil
    end

    local scene = scene_manager.find_scene(scene_id)
    if scene ~= nil then
        --宠物遗留在场景里？
        local pet_puppet = scene:get_entity_manager().GetPuppet(self.entity_id)
        if pet_puppet ~= nil then
            scene:remove_pet(self.entity_id)
        end
        self.scene_id = scene_id
        scene:add_pet(self)
        self.scene = scene
    end
    return 0
end

function imp_pet_aoi.leave_scene(self)
    if self.scene == nil then
        return
    end
    self:leave_aoi_scene()
end

function imp_pet_aoi.leave_aoi_scene(self)
    if self.scene ~= nil then
        self.scene:remove_pet(self.entity_id)
        self.scene = nil
    end
    return 0
end


function imp_pet_aoi.leave_scene_by_id(self,scene_id)
    local scene = scene_manager.find_scene(scene_id)
    if scene == nil then
        return
    end
    local entity = scene:get_entity(self.entity_id)
    if entity ~= nil then
        scene:remove_pet(self.entity_id)
    else
        --宠物遗留在场景里？
        local pet_puppet = scene:get_entity_manager().GetPuppet(self.entity_id)
        if pet_puppet ~= nil then
            scene:remove_pet(self.entity_id)
        end
    end
end

function imp_pet_aoi.get_info_to_scene(self)
    local data = {}
    data.entity_id = self.entity_id
    data.posX = self.posX
    data.posY = self.posY
    data.posZ = self.posZ
    data.pet_level = self.pet_level
    data.scene_id = self.scene_id
    self:imp_pet_write_to_sync_dict(data)
    self:imp_property_write_to_sync_dict(data)
    data.server_object = self
    return data
end

return imp_pet_aoi

