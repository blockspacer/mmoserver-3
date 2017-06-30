--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/30 0030
-- Time: 13:46
-- To change this template use File | Settings | File Templates.
--
--

local const = require "Common/constant"
local scene_func = require "scene/scene_func"
local flog = require "basic/log"
local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"
local team_dungeon_scene = require "scene/team_dungeon_scene"

local scenes = {}
local scene_id_index = 0

local function get_scene_id()
    scene_id_index = scene_id_index + 1
    if scene_id_index > 10000 then
        scene_id_index = 0
    end
    while scenes[scene_id_index] ~= nil do
        scene_id_index = scene_id_index + 1
        if scene_id_index > 10000 then
            scene_id_index = 0
        end
    end
    return scene_id_index
end

-- 加载所有场景元素
local function load_scene(sceneID,scene_config,scene_setting,dungeon_id,level)
    flog("info","team_dungeon_scene_manager|load_scene")
    local aoi_scene_id = const.SCENE_TYPE.TEAM_DUNGEON*100000000 + sceneID*10000 + get_scene_id()
	local s = team_dungeon_scene()
    s:initialize(aoi_scene_id,scene_config,sceneID,scene_setting,dungeon_id,level)
	local result = scene_func.create_dungeon_scene(aoi_scene_id,"detour/"..scene_config.SceneID..".nav")
    if not result then
        flog("error","can not create team dungon scene!dungeon id:"..dungeon_id)
        return nil
    end
    scenes[aoi_scene_id] = s
	return aoi_scene_id
end

local function find_scene(sceneID)
    return scenes[sceneID]
end

local function destroy_scene(scene_id)
    if scenes[scene_id] == nil then
        return
    end

	if not scenes[scene_id]:destroy() then
		return
    end
	scenes[scene_id] = nil
	scene_func.destroy_aoi_scene(scene_id)
end

local function create_team_dungeon_scene(dungeon_id,level)
    flog("info","team_dungeon_scene_manager|create_team_dungeon_scene")
    local team_dungeon_config = challenge_team_dungeon_config.get_team_dungeon_config(dungeon_id)
    if team_dungeon_config == nil then
        flog("info","can not find team dungeon scene config!dungeon id:"..dungeon_id)
        return 0
    end

    local aoi_scene_id = load_scene(dungeon_id,team_dungeon_config,challenge_team_dungeon_config.get_team_dungeon_scene_setting(dungeon_id),dungeon_id,level)
    scenes[aoi_scene_id]:create_trriger_manager(challenge_team_dungeon_config.get_challenge_team_dungeon_table(),team_dungeon_config.SceneSetting)

    return aoi_scene_id
end

return {
    load_scene = load_scene,
	find_scene = find_scene,
	destroy_scene = destroy_scene,
    create_team_dungeon_scene = create_team_dungeon_scene,
}



