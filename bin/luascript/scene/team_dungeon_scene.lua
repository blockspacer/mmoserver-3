--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/30 0030
-- Time: 13:46
-- To change this template use File | Settings | File Templates.
--
local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"
local flog = require "basic/log"
local const = require "Common/constant"


local team_dungeon_scene = {}
team_dungeon_scene.__index = team_dungeon_scene

setmetatable(team_dungeon_scene, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

function team_dungeon_scene.__ctor(self)

    local module_name = "scene/scene"
    local module = require(module_name)()

    for i, v in pairs(module) do
        self[i] = v
    end
    local moudule_metatable = getmetatable(module)
    for i, v in pairs(moudule_metatable) do
        if string.sub(i,1,2) ~= "__" then
            team_dungeon_scene[i] = v
        end
    end
end

function team_dungeon_scene.initialize(self,scene_id,scene_config,table_scene_id,scene_scheme,dungeon_id,level)
    flog("tmlDebug","team_dungeon_scene.initialize,dungeon_id:"..dungeon_id)
    if scene_config.SceneType == const.SCENE_TYPE.TEAM_DUNGEON and scene_config.Chapter ~= challenge_team_dungeon_config.get_level_dungeon_chapter() then
        self:set_scene_monster_level(level)
    end
    self:init(scene_id,scene_config,table_scene_id,scene_scheme)
    self.rpc_code = const.DC_MESSAGE_LUA_GAME_RPC
end

return team_dungeon_scene