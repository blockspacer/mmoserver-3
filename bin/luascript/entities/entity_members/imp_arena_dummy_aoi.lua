--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/12 0012
-- Time: 19:35
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local entity_factory = require "entity_factory"

local params = {}
local imp_arena_dummy_aoi = {}
imp_arena_dummy_aoi.__index = imp_arena_dummy_aoi

setmetatable(imp_arena_dummy_aoi, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_arena_dummy_aoi.__params = params

function imp_arena_dummy_aoi.__ctor(self)
    self.aoi_proxy = nil
    self.scene = nil
    self.entity_info = {}
    self.arena_defend_pet_list = {}
end

function imp_arena_dummy_aoi.imp_aoi_init_from_dict(self,dict)
end

function imp_arena_dummy_aoi.imp_aoi_write_to_dict(self,dict)
end

function imp_arena_dummy_aoi.imp_aoi_write_to_sync_dict(self,dict)
end

function imp_arena_dummy_aoi.enter_aoi_scene(self)
    self.scene = arena_scene_manager.find_scene(self.scene_id)
    if self.scene ~= nil then
        self:set_arena_dummy_skill(self.arena_defend_skill)
        self.scene:add_arena_dummy(self)
        self:arena_pet_enter_scene()
    end
    return 0
end

function imp_arena_dummy_aoi.leave_aoi_scene(self)
    self:arena_pet_leave_scene()
    if self.scene ~= nil then
        self.scene:remove_arena_dummy(self.entity_id)
        self.scene = nil
    end
    return 0
end

function imp_arena_dummy_aoi.get_appearance_aoi_index(part_id)
    return part_id - 900
end

function imp_arena_dummy_aoi.get_info_to_scene(self)
    local data = {}
    data.entity_id = self.entity_id
    data.actor_name = self.actor_name
    data.posX = self.posX
    data.posY = self.posY
    data.posZ = self.posZ
    data.level = self.level
    data.vocation = self.vocation
    data.country = self.country
    data.sex = self.sex
    data.spritual = self.spritual
    data.scene_id = self.scene_id
    self:imp_property_write_to_sync_dict(data)
    self:imp_arena_dummy_skill_write_to_sync_dict(data)
    for index, value in pairs(self.appearance) do
        local aoi_index = self.get_appearance_aoi_index(index)
        data['appearance_'..aoi_index] = value
    end
    data.server_object = self
    return data
end

function imp_arena_dummy_aoi.arena_pet_enter_scene(self)
    local defend_pet = self:get_defend_pet()
    flog("tmlDebug","imp_arena_dummy_aoi.arena_pet_enter_scene defend_pet:"..table.serialize(defend_pet))
    for _,entity_id in pairs(defend_pet) do
        local pet_info = self:get_pet_info(entity_id)
        if pet_info ~= nil then
            local entity = entity_factory.create_entity(const.ENTITY_TYPE_PET)
            if entity ~=  nil then
                local new_entity_id = entity.entity_id
                entity:init_from_dict(pet_info)
                entity.entity_id = new_entity_id
                entity:set_owner_id(self.entity_id)
                table.insert(self.arena_defend_pet_list, entity)
                flog("tmlDebug","imp_arena_dummy_aoi.arena_pet_enter_scene entity_id:"..entity.entity_id)
                entity:enter_scene(self)
                local scene = self:get_scene()
                if scene ~= nil then
                    local pet_puppet = scene:get_entity_manager().GetPuppet(entity.entity_id)
                    if pet_puppet ~= nil then
                        pet_puppet:SetControl(true)
                        pet_puppet:SetState()
		                --pet_puppet:SetPosition(pet_puppet:CalculatePosition())
                        pet_puppet:SetAttackStatus(false)
                        pet_puppet:SetEnabled(false)
                    end
                end

            else
                flog("info", "Failed create arena pet ")
            end
        else
            flog("info", "can not find pet info, entity_id:"..entity_id)
        end
    end
end

function imp_arena_dummy_aoi.arena_pet_leave_scene(self)
    for _,v in pairs(self.arena_defend_pet_list) do
        v:leave_scene()
    end
end

function imp_arena_dummy_aoi.get_pos(self)
    local entity_manager = self:get_entity_manager()
    if entity_manager == nil then
        flog("warn", "imp_arena_dummy_aoi get_pos: entity_manager is nil")
        return self.posX,self.posY,self.posZ
    end
    local puppet = entity_manager.GetPuppet(self.entity_id)
    if puppet == nil then
        flog("warn", "imp_arena_dummy_aoi get_pos: puppet is nil")
        return self.posX,self.posY,self.posZ
    end
    local pos = puppet:GetPosition()
    return pos.x, pos.y, pos.z
end

return imp_arena_dummy_aoi



