--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/22 0022
-- Time: 11:15
-- To change this template use File | Settings | File Templates.
--

local scene_func = require "scene/scene_func"
local flog = require "basic/log"
local system_task_config = require "configs/system_task_config"
local main_dungeon_scene = require "scene/main_dungeon_scene"
local const = require "Common/constant"

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
    local aoi_scene_id = const.SCENE_TYPE.TASK_DUNGEON*100000000 + sceneID*10000 + get_scene_id()
	local s = main_dungeon_scene()

    s:initialize(aoi_scene_id,scene_config,sceneID,scene_setting,dungeon_id,level)

	local result = scene_func.create_dungeon_scene(aoi_scene_id,"detour/"..scene_config.SceneID..".nav")
    if not result then
        flog("error","can not create task dungeon scene!dungeon_id "..dungeon_id)
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

local function create_dungeon_scene(dungeon_id,level)
    local dungeon_config = system_task_config.get_task_dungeon_config(dungeon_id)
    if dungeon_config == nil then
        flog("tmlDebug","can not find task dungeon scene config!dungeon id:"..dungeon_id)
        return 0
    end

    local aoi_scene_id = load_scene(dungeon_id,dungeon_config,system_task_config.get_task_dungeon_scene_setting(dungeon_id),dungeon_id,level)
    scenes[aoi_scene_id]:create_trriger_manager(system_task_config.get_task_dungeon_table(),dungeon_config.SceneSetting)

    return aoi_scene_id
end

return {
    load_scene = load_scene,
	find_scene = find_scene,
	destroy_scene = destroy_scene,
    create_dungeon_scene = create_dungeon_scene,
}

