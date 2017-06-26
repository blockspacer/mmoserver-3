--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/12 0012
-- Time: 19:10
-- To change this template use File | Settings | File Templates.
--

local flog = require "basic/log"
local entity_factory = require "entity_factory"
local const = require "Common/constant"
local entity_common = require "entities/entity_common"

local avatar_dummy = {}
local parent = {}
avatar_dummy.__index = avatar_dummy

setmetatable(avatar_dummy, {
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
   "imp_arena_dummy", "imp_property", "imp_arena_dummy_pet","imp_arena_dummy_skill","imp_arena_dummy_aoi","imp_arena_dummy_arena","imp_arena_dummy_appearance",
    }


function avatar_dummy.__ctor(self, entity_id)
    --竞技场假人，用新生成的entity_id
    self.create_entityid = entity_id
    self.entity_id = entity_id
    flog("info","entity_id"..entity_id)
    self.saver_timer = nil
    self.type = const.ENTITY_TYPE_ARENA_DUMMY
    self.aoi_proxy = nil

    entity_common.create_entity_module(self, avatar_dummy, entity_part_list, parent, parent_part_list)
end

-- 通过table初始化数据
-- NPC通过系统配置
-- 玩家通过数据库数据
function avatar_dummy.init(self, dict)
    flog("info", "arena dummy init")

    --初始化模块数据
    entity_common.init_all_module_from_dict(self, dict, avatar_dummy, entity_part_list)
    self.entity_id = self.create_entityid
    return true
end

function avatar_dummy.on_logout(self)
    return
end

function avatar_dummy.get(self, param_name)
    return self[param_name]
end

--给参数赋值，建议外部不要调用
function avatar_dummy._set(self, param_name, value)
    if type(self[param_name]) == "table" then
        self[param_name] = table.copy(value)
    else
        self[param_name] = value
    end
end

function avatar_dummy.on_attack_player(self, enemy)

end

function avatar_dummy.is_attackable(self, enemy)
    return true
end

function avatar_dummy.on_kill_player(self, enemy)
end

entity_factory.register_entity(const.ENTITY_TYPE_ARENA_DUMMY, avatar_dummy)

return avatar_dummy

