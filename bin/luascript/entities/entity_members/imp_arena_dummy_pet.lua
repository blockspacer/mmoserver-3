--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/9 0009
-- Time: 11:11
-- To change this template use File | Settings | File Templates.
--

local entity_factory = require "entity_factory"
local const = require "Common/constant"
local flog = require "basic/log"
local table = table

local params = {

}

local imp_arena_dummy_pet = {}
imp_arena_dummy_pet.__index = imp_arena_dummy_pet

setmetatable(imp_arena_dummy_pet, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_arena_dummy_pet.__params = params

function imp_arena_dummy_pet.__ctor(self)
    self.pet_list = {}
end

function imp_arena_dummy_pet.imp_arena_dummy_pet_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    local dict_pet_list = table.get(dict, "pet_list", {})
    self.pet_list = table.copy(dict_pet_list)
end

function imp_arena_dummy_pet.imp_arena_dummy_pet_write_to_dict(self, dict)

end

function imp_arena_dummy_pet.imp_arena_dummy_pet_write_to_sync_dict(self, dict, no_pet)

end

function imp_arena_dummy_pet.get_pet_info(self,entity_id)
    for i,pet in pairs(self.pet_list) do
        if pet.entity_id == entity_id then
            return pet
        end
    end
    return nil
end

return imp_arena_dummy_pet

