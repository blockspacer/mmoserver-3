--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/17 0017
-- Time: 18:24
-- To change this template use File | Settings | File Templates.
--


local scene_func = require "scene/scene_func"
local flog = require "basic/log"
local challenge_main_dungeon_config = require "configs/challenge_main_dungeon_config"
local main_dungeon_scene = require "scene/main_dungeon_scene"
local const = require "Common/constant"

local scenes = {}
local scene_id_index = 0

local function get_scene_id()
    scene_id_index = scene_id_index + 1
    if scene_id_index >= 10000 then
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
local function load_scene(sceneID,scene_config,scene_setting,dungeon_id)
    local aoi_scene_id = const.SCENE_TYPE.DUNGEON*100000000 + sceneID*10000 + get_scene_id()
	local s = main_dungeon_scene()

    s:initialize(aoi_scene_id,scene_config,sceneID,scene_setting,dungeon_id)
	local result = scene_func.create_dungeon_scene(aoi_scene_id,"detour/"..scene_config.SceneID..".nav")
    if not result then
        flog("error","can not create main dungeon scene!dungeon_id "..dungeon_id)
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

local function create_main_dungeon_scene(dungeon_id)
    local dungeon_config = challenge_main_dungeon_config.get_main_dungeon_config(dungeon_id)
    if dungeon_config == nil then
        flog("tmlDebug","can not find main dungeon scene config!dungeon id:"..dungeon_id)
        return 0
    end

    local aoi_scene_id = load_scene(dungeon_id,dungeon_config,challenge_main_dungeon_config.get_main_dungeon_scene_setting(dungeon_id),dungeon_id)
    scenes[aoi_scene_id]:create_trriger_manager(challenge_main_dungeon_config.get_challenge_main_dungeon_table(),dungeon_config.SceneSetting)

    return aoi_scene_id
end

return {
    load_scene = load_scene,
	find_scene = find_scene,
	destroy_scene = destroy_scene,
    create_main_dungeon_scene = create_main_dungeon_scene,
}

