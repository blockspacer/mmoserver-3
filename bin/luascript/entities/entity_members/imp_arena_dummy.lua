--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/3 0003
-- Time: 17:40
-- To change this template use File | Settings | File Templates.
--
local const = require "Common/constant"
local flog = require "basic/log"
local SyncManager = require "Common/SyncManager"
local Totalparameter = require("data/common_scene").Totalparameter
local rebirth_param = require("data/common_fight_base").Revive
local timer = require "basic/timer"
local math = require "math"

local PROPERTY_NAME_TO_INDEX = const.PROPERTY_NAME_TO_INDEX
local REBIRTH_TYPE = const.REBIRTH_TYPE

local rebirth_index = {}
for i, v in ipairs(rebirth_param) do
    rebirth_index[v.Rebirthtype] = rebirth_index[v.Rebirthtype] or {}
    table.insert(rebirth_index[v.Rebirthtype], {index = i, lv = v.LowerLimit})
end
local function get_index_from_rebirth_times(type, times)
    local type_index = rebirth_index[type]
    if type_index == nil then
        flog("error", "get_index_from_rebirth_times: error type "..type)
        return
    end
    local idx
    local lv = 0
    for _, v in ipairs(type_index) do
        if times >= v.lv and v.lv > lv then
            idx = v.index
            lv = v.lv
        end
    end
    if idx == nil then
        idx = type_index[#type_index].index
    end
    return idx
end

local scene_type_configs = {}
for _,v in pairs(Totalparameter) do
    scene_type_configs[v.SceneType] = v
end

local imp_arena_dummy = {}
imp_arena_dummy.__index = imp_arena_dummy

setmetatable(imp_arena_dummy, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {

}
imp_arena_dummy.__params = params

function imp_arena_dummy.__ctor(self)
    self.actor_id = 0
    self.actor_name = ""
    self.level = 1
    self.vocation = 1
    self.country = 1
    self.sex = 1
    self.scene_id = 0
    self.posX = 0
    self.posY = 0
    self.posZ = 0
    self.current_hp = 100
    self.dungeon_rebirth_time = 1
    self.rebirth_type = "B"
end

function imp_arena_dummy.get_actor_id(self)
    return self.actor_id
end

function imp_arena_dummy.get_sex(self)
    return self.sex
end

function imp_arena_dummy.get_actor_name(self)
    return self.actor_name
end

function imp_arena_dummy.get_level(self)
    return self.level
end

function imp_arena_dummy.get_vocation(self)
    return self.vocation
end

function imp_arena_dummy.get_country(self)
    return self.country
end

function imp_arena_dummy.get_move_speed(self)
    return 450
end

function imp_arena_dummy.imp_arena_dummy_init_from_dict(self,dict)
    self.actor_id = dict.actor_id
    self.actor_name = dict.actor_name
    self.level = dict.level
    self.vocation = dict.vocation
    self.country = dict.country
    self.sex = dict.sex
end

function imp_arena_dummy.is_attackable(self, enemy)
    return true
end

function imp_arena_dummy.on_connect_fight_server(self,input)

end

function imp_arena_dummy.initialize_fight_avater(self,input)
end

function imp_arena_dummy.on_attack_player(self, enemy)

end

function imp_arena_dummy.get_max_hp(self)
    return self.combat_info.property[PROPERTY_NAME_TO_INDEX.hp_max]
end

function imp_arena_dummy.get_current_hp(self)
    return self.current_hp
end

function imp_arena_dummy.entity_die(self,killer_id)
    local arena_scene = arena_scene_manager.find_scene(self:get_aoi_scene_id())
    if arena_scene == nil then
        return
    end

    if arena_scene:is_dogfight() == true then
        return
    end

    local killer = arena_scene:get_entity(killer_id)
    if killer == nil then
        flog("tmlDebug","entity_die:can not find killer!killer_id:"..killer_id)
        return
    end
    if killer.type == const.ENTITY_TYPE_PET then
        killer = arena_scene:get_entity(killer.owner_id)
    end
    if killer == nil then
        flog("tmlDebug","entity_die:can not find killer owner!killer_id:"..killer_id)
        return
    end
    if killer.type == const.ENTITY_TYPE_FIGHT_AVATAR then
        killer:set_qualifying_arena_done()
        killer:fight_send_to_game({func_name="on_qualifying_arena_fight_result",success=true})
    end
    --由客户端处理死亡
    --self:leave_aoi_scene()
end

return imp_arena_dummy