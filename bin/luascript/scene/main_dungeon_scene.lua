--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/17 0017
-- Time: 18:48
-- To change this template use File | Settings | File Templates.
--
local flog = require "basic/log"
local const = require "Common/constant"
local timer = require "basic/timer"


local main_dungeon_scene = {}
main_dungeon_scene.__index = main_dungeon_scene

setmetatable(main_dungeon_scene, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

function main_dungeon_scene.__ctor(self)

    local module_name = "scene/scene"
    local module = require(module_name)()

    for i, v in pairs(module) do
        self[i] = v
    end
    local moudule_metatable = getmetatable(module)
    for i, v in pairs(moudule_metatable) do
        if string.sub(i,1,2) ~= "__" then
            main_dungeon_scene[i] = v
        end
    end
end

function main_dungeon_scene.update(self)
    if self.scene_state == const.SCENE_STATE.done then
        if not self.is_destroy then
            if table.isEmptyOrNil(self.actorlist) then
                scene_manager.destroy_scene(self.scene_id)
            end
        end
    end
end

function main_dungeon_scene.initialize(self,scene_id,scene_config,table_scene_id,scene_scheme,dungeon_id,level)
    flog("tmlDebug","main_dungeon_scene.initialize,dungeon_id:"..dungeon_id)
    self:set_scene_monster_level(level)
    self:init(scene_id,scene_config,table_scene_id,scene_scheme)
    self.rpc_code = const.DC_MESSAGE_LUA_GAME_RPC
    local function scene_timer_handle()
        self:update()
    end
    self.scene_timer = timer.create_timer(scene_timer_handle,1000,const.INFINITY_CALL)
end

return main_dungeon_scene

