--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/9 0009
-- Time: 11:30
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local math = require "math"
local broadcast_to_aoi = require("basic/net").broadcast_to_aoi
local flog = require "basic/log"
local math_floor = math.floor

local params = {}
local imp_aoi_common = {}
imp_aoi_common.__index = imp_aoi_common

setmetatable(imp_aoi_common, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_aoi_common.__params = params

function imp_aoi_common.__ctor(self)

end


function imp_aoi_common.imp_aoi_common_init_from_dict(self,dict)
end

function imp_aoi_common.imp_aoi_common_write_to_dict(self,dict)
end

function imp_aoi_common.imp_aoi_common_write_to_sync_dict(self,dict)
end

function imp_aoi_common.get_aoi_scene_id(self)
    local scene = self:get_scene()
    if scene ~= nil then
        return scene:get_scene_id()
    end
    return 0
end

function imp_aoi_common.get_scene_id(self)
    return self.scene_id
end

function imp_aoi_common.broadcast_to_aoi(self,msgid,msg)
    local puppet = self:get_puppet()
    if puppet then
        broadcast_to_aoi(puppet.aoi_proxy,msgid,msg, 0)
    end
end

function imp_aoi_common.broadcast_to_aoi_include_self(self, msgid, msg)
    local puppet = self:get_puppet()
    if puppet then
        broadcast_to_aoi(puppet.aoi_proxy, msgid, msg, 1)
    end
end

function imp_aoi_common.get_scene(self)
    return self.scene
end

function imp_aoi_common.get_entity_manager(self)
    if self.scene == nil then
        return nil
    end
    return self.scene:get_entity_manager()
end

function imp_aoi_common.get_entity_type(self)
    return self.type
end

function imp_aoi_common.get_entity_id(self)
    return self.entity_id
end

function imp_aoi_common.set_player_fight_state(self,value)
    if self.type == const.ENTITY_TYPE_PLAYER then
        self:fight_state_changed(value)
    elseif self.type == const.ENTITY_TYPE_FIGHT_AVATAR then
        self:fight_send_to_game({func_name="on_fight_state_changed",fight_state=value})
    end
end

function imp_aoi_common.pos_to_client(posX, posY, posZ)
    posX = math_floor(posX * 100)
    posY = math_floor(posY * 100)
    posZ = math_floor(posZ * 100)
    return posX, posY, posZ
end

function imp_aoi_common.get_puppet(self)
    local entity_manager = self:get_entity_manager()
    if entity_manager ~= nil then
        return entity_manager.GetPuppet(self.entity_id)
    end
    return nil
end

function imp_aoi_common.get_puppet_by_id(self, entity_id)
    if entity_id == nil then
        --flog("error", "imp_aoi_common.get_puppet_by_id entity_id is nil")
        return
    end
    local entity_manager = self:get_entity_manager()
    if entity_manager ~= nil then
        return entity_manager.GetPuppet(entity_id)
    end
    return nil
end

function imp_aoi_common.get_scene_entity_by_id(self, entity_id)
    local scene = self:get_scene()
    if scene ~= nil then
        return
    end
    return scene:get_entity(entity_id)
end

function imp_aoi_common.update_property_to_puppet(self, hp_change_percent, mp_change_percent)
    local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:ImmediateCalcProperty()

        if hp_change_percent ~= nil then
            puppet:SetHp(math.floor(hp_change_percent * puppet.hp / 100))
        end
        if mp_change_percent ~= nil then
            puppet:SetMp(math.floor(mp_change_percent * puppet.mp / 100))
        end
    end
end

return imp_aoi_common
