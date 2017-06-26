--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/30 0030
-- Time: 16:17
-- To change this template use File | Settings | File Templates.
--
local scene = require "scene/scene"
local const = require "Common/constant"
local scene_func = require "scene/scene_func"
local flog = require "basic/log"
local common_scene_config = require "configs/common_scene_config"


local scenes = {}

-- 加载所有场景元素
local function load_scene(sceneID,scene_config,scene_setting)

	local s = scene()
	if s == nil then
		_error(string.format("Failed create scene: %d" ,sceneID))
		return false
	end

    if s:init(sceneID,scene_config,sceneID,scene_setting) == false then
        _error("Failed load layout of scene" .. sceneID)
        return false
    end

	local scene_resource_config = common_scene_config.get_scene_resource_config(scene_config.SceneID)
	local result = scene_func.create_aoi_scene(sceneID,const.SCENE_RADIUS,scene_resource_config.MinX,scene_resource_config.MaxX,scene_resource_config.MinZ,scene_resource_config.MaxZ,"detour/"..scene_config.SceneID..".nav")
	if not result then
		flog("error","can not create normal scene!scene id:"..sceneID)
		return nil
	end
	scenes[sceneID] = s
	return s
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

local function create_scene(scene_id)
	local result = 0
	if scenes[scene_id] ~= nil then
		return const.error_scene_already_create
	end
	local scene_scheme = common_scene_config.get_scene_config(scene_id)
	local scene = load_scene(scene_id,scene_scheme,common_scene_config.get_scene_detail_config(scene_id))
	scene:create_trriger_manager(common_scene_config.get_scene_scheme_table(),scene_scheme.SceneSetting)
	return result
end

return {
    load_scene = load_scene,
	find_scene = find_scene,
	destroy_scene = destroy_scene,
	create_scene = create_scene,
}

