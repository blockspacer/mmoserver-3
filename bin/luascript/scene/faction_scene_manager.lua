--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/6/5 0005
-- Time: 18:31
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local scene_func = require "scene/scene_func"
local flog = require "basic/log"
local system_faction_config = require "configs/system_faction_config"
local faction_scene = require "scene/faction_scene"

local scenes = {}
local faction_scenes = {}
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
local function load_scene(sceneID,scene_config,scene_setting,faction_id,country)
    local aoi_scene_id = const.SCENE_TYPE.FACTION*100000000 + sceneID*10000 + get_scene_id()
	local s = faction_scene()
    s:initialize(aoi_scene_id,scene_config,sceneID,scene_setting,faction_id,country)
	local result = scene_func.create_dungeon_scene(aoi_scene_id,"detour/"..scene_config.SceneID..".nav")
    if not result then
        flog("error","can not create faction scene!sceneID id:"..sceneID)
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

local function create_scene(faction_id,country)
    local faction_scene_config = system_faction_config.get_faction_scene_config(const.FACTION_SCENE_ID)
    if faction_scene_config == nil then
        flog("error","can not find faction scene config!")
        return const.error_data
    end

    local aoi_scene_id = load_scene(const.FACTION_SCENE_ID,faction_scene_config,system_faction_config.get_scene_setting(const.FACTION_SCENE_ID),faction_id,country)
    scenes[aoi_scene_id]:create_trriger_manager(system_faction_config.get_faction_table(),faction_scene_config.SceneSetting)
    faction_scenes[faction_id] = scenes[aoi_scene_id]

    return 0,aoi_scene_id
end

local function find_faction_scene(faction_id)
    return faction_scenes[faction_id]
end

return {
    load_scene = load_scene,
	find_scene = find_scene,
	destroy_scene = destroy_scene,
    create_scene = create_scene,
    find_faction_scene = find_faction_scene,
}

