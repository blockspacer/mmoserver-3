--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/6 0006
-- Time: 11:18
-- To change this template use File | Settings | File Templates.
--

local entity_factory = require "entity_factory"
local const = require "Common/constant"
local flog = require "basic/log"
local table = table

local params = {

}

local imp_fight_avatar_pet = {}
imp_fight_avatar_pet.__index = imp_fight_avatar_pet

setmetatable(imp_fight_avatar_pet, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_fight_avatar_pet.__params = params

function imp_fight_avatar_pet.__ctor(self)
    --pet_list和self.pet_on_fight中的宠物唯一id均为新id
    self.pet_list = {}
    self.pet_on_fight = {}
    --在战斗服务器，需要一个新的宠物唯一id,这里保留新老对应,战斗服已独立，理论上不需要新的宠物id
    --self.pet_map = {}
end

function imp_fight_avatar_pet.imp_fight_avatar_pet_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    local pet_on_fight = table.copy(table.get(dict, "pet_on_fight", {}))

    local dict_pet_list = table.get(dict, "pet_list", {})
    for i, v in ipairs(dict_pet_list) do
        local entity = entity_factory.create_entity(const.ENTITY_TYPE_PET)
        if entity ==  nil then
            flog("error", "imp_seal_init_from_dict: Failed create pet ")
            return const.error_create_pet_fail
        end
        entity:init_from_dict(v)
        entity:set_owner_id(self.entity_id)
        table.insert(self.pet_list, entity)
    end
    self.pet_on_fight = table.copy(pet_on_fight)
end

function imp_fight_avatar_pet.imp_fight_avatar_pet_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end

    dict.pet_on_fight = table.copy(self.pet_on_fight)

    local dict_pet_list = {}
    for i, v in ipairs(self.pet_list) do
        local t = {}
        v:write_to_sync_dict(t)
        table.insert(dict_pet_list, t)
    end
    dict.pet_list = dict_pet_list
end

local function get_pet(self,pet_entity_id)
    for i=1,#self.pet_list,1 do
        if self.pet_list[i].entity_id == pet_entity_id then
            return self.pet_list[i]
        end
    end
end

function imp_fight_avatar_pet.pet_enter_scene(self)
    for _,v in pairs(self.pet_on_fight) do
        for _,pet in pairs(self.pet_list) do
            if pet.entity_id == v then
                pet:enter_scene(self)
                break;
            end
        end
    end
end

function imp_fight_avatar_pet.pet_leave_scene(self)
    for _,v in pairs(self.pet_on_fight) do
        for _,pet in pairs(self.pet_list) do
            if pet.entity_id == v then
                pet:leave_scene()
                break;
            end
        end
    end
end

function imp_fight_avatar_pet.get_pet_info(self,entity_id)
    for i,pet in pairs(self.pet_list) do
        if pet.entity_id == entity_id then
            local pet_info = {}
            pet:write_to_dict(pet_info)
            return pet_info
        end
    end
    return nil
end

function imp_fight_avatar_pet.is_have_pet(self,entity_id)
    for i,pet in pairs(self.pet_list) do
        if pet.entity_id == entity_id then
            return true
        end
    end
    return false
end

function imp_fight_avatar_pet.on_fight_avatar_pet_on_fight(self,input)
    for i,v in pairs(input.data.pet_on_fight) do
        local on_fight = false
        for _,pet_entity_id in pairs(self.pet_on_fight) do
            if v == pet_entity_id then
                on_fight = true
            end
        end
        if on_fight == false then
            local pet = get_pet(self,v)
            if pet ~= nil then
                pet:set('fight_index',i)
                pet:enter_scene(self)
            end
        end
    end
    self.pet_on_fight = table.copy(input.data.pet_on_fight)
end

function imp_fight_avatar_pet.on_fight_avatarpet_on_rest(self,input)
    for i,v in pairs(self.pet_on_fight) do
        local on_fight = false
        for _,pet_entity_id in pairs(input.data.pet_on_fight) do
            if v == pet_entity_id then
                on_fight = true
            end
        end
        if on_fight == false then
            local pet = get_pet(self,v)
            if pet ~= nil then
                pet:leave_scene(self)
            end
        end
    end
    self.pet_on_fight = table.copy(input.data.pet_on_fight)
end

function imp_fight_avatar_pet.set_pet_attack_state(self,value)
    for i,v in pairs(self.pet_on_fight) do
        if self.scene ~= nil then
            self.scene:get_entity_manager().SetEntityAttackStatus(v,value)
        end
    end
end

function imp_fight_avatar_pet.rebirth_pet(self,entity_id)
    flog("tmlDebug","imp_fight_avatar_pet.rebirth_pet "..entity_id)
    for i=1,#self.pet_list,1 do
        if self.pet_list[i].entity_id == entity_id then
            self.pet_list[i]:reset_rebirth_time()
            for _,pet_id in pairs(self.pet_on_fight) do
                if pet_id == entity_id then
                    self.pet_list[i]:enter_scene(self)
                    break
                end
            end
            break
        end
    end
    return true
end

function imp_fight_avatar_pet.send_fight_pet_to_client(self)
    local dict = {}
    dict.result = 0
    dict.pet_on_fight_entity = {}
    for _,pet_id in pairs(self.pet_on_fight) do
        for i=1,#self.pet_list,1 do
            if self.pet_list[i].entity_id == pet_id then
                local t = {}
                self.pet_list[i]:write_to_sync_dict(t)
                dict.pet_on_fight_entity[pet_id] = t
            end
        end
    end
    self:send_message(const.SC_MESSAGE_LUA_UPDATE,dict)
end

return imp_fight_avatar_pet

