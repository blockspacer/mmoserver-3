----------------------------------------------------------------------
-- 文件名:	pet.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/21
-- 描  述:	单个宠物
--------------------------------------------------------------------
local flog = require "basic/log"
local entity_factory = require "entity_factory"
local const = require "Common/constant"
local entity_common = require "entities/entity_common"

local pet = {}
local parent = {}
pet.__index = pet

setmetatable(pet, {
    __index = parent,
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

local parent_part_list = {
    "imp_aoi_common","imp_interface",
}

local entity_part_list = {
        "imp_pet", "imp_property","imp_pet_aoi",
    }

function pet.__ctor(self, entity_id)
    self.entity_id = entity_id
    self.type = const.ENTITY_TYPE_PET

    -- 添加entity模块
    entity_common.create_entity_module(self, pet, entity_part_list, parent, parent_part_list)
end

-- 通过table初始化数据
-- NPC通过系统配置
-- 玩家通过数据库数据
function pet.init_from_dict(self, dict)
    flog("info", "Pet init")

    --初始化模块数据
    entity_common.init_all_module_from_dict(self, dict, pet, entity_part_list)

    return true
end

function pet.write_to_dict(self, dict)
    --模块数据保存
    for i in pairs(entity_part_list) do
        pet[entity_part_list[i].."_write_to_dict"](self, dict)
    end
end

function pet.write_to_sync_dict(self, dict)
    for i in pairs(entity_part_list) do
        pet[entity_part_list[i].."_write_to_sync_dict"](self, dict)
    end
    dict.entity_id = self.entity_id
end

function pet.get(self, param_name)
    return self[param_name]
end

function pet.set(self, param_name, value)
    self[param_name] = value
end

entity_factory.register_entity(const.ENTITY_TYPE_PET, pet)

return pet