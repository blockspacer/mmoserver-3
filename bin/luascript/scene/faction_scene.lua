--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/6/5 0005
-- Time: 18:31
-- To change this template use File | Settings | File Templates.
--
local flog = require "basic/log"
local const = require "Common/constant"


local faction_scene = {}
faction_scene.__index = faction_scene

setmetatable(faction_scene, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

function faction_scene.__ctor(self)

    local module_name = "scene/scene"
    local module = require(module_name)()

    for i, v in pairs(module) do
        self[i] = v
    end
    local moudule_metatable = getmetatable(module)
    for i, v in pairs(moudule_metatable) do
        if string.sub(i,1,2) ~= "__" then
            faction_scene[i] = v
        end
    end
    self.faction_id = nil
end

function faction_scene.initialize(self,scene_id,scene_config,table_scene_id,scene_scheme,faction_id,country)
    flog("tmlDebug","faction_scene.initialize,faction_id:"..faction_id..",country "..country)
    self:init(scene_id,scene_config,table_scene_id,scene_scheme)
    self.country = country
    self.rpc_code = const.SC_MESSAGE_LUA_GAME_RPC
    self.faction_id = faction_id
end

return faction_scene

