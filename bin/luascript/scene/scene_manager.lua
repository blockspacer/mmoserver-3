--------------------------------------------------------------------
-- 文件名:	scene.lua
-- 版  权:	(C) 华风软件
-- 创建人:	hou(houontherun@gmail.com)
-- 日  期:	2016/08/08
-- 描  述:	场景管理文件，管理所有场景
--------------------------------------------------------------------
local flog = require "basic/log"

local function find_scene(sceneID)
	if normal_scene_manager ~= nil and normal_scene_manager.find_scene(sceneID) ~= nil then
		return normal_scene_manager.find_scene(sceneID)
	elseif arena_scene_manager ~= nil and arena_scene_manager.find_scene(sceneID) ~= nil then
		return arena_scene_manager.find_scene(sceneID)
	elseif team_dungeon_scene_manager ~= nil and team_dungeon_scene_manager.find_scene(sceneID) ~= nil then
		return team_dungeon_scene_manager.find_scene(sceneID)
	elseif main_dungeon_scene_manager ~= nil and main_dungeon_scene_manager.find_scene(sceneID) ~= nil then
		return main_dungeon_scene_manager.find_scene(sceneID)
	elseif task_dungeon_scene_manager ~= nil and task_dungeon_scene_manager.find_scene(sceneID) ~= nil then
		return task_dungeon_scene_manager.find_scene(sceneID)
	elseif faction_scene_manager ~= nil and faction_scene_manager.find_scene(sceneID) ~= nil then
		return faction_scene_manager.find_scene(sceneID)
	end
    return nil
end

local function destroy_scene(scene_id)
	if normal_scene_manager ~= nil then
		normal_scene_manager.destroy_scene(scene_id)
	end
	if arena_scene_manager ~= nil then
		arena_scene_manager.destroy_scene(scene_id)
	end
	if team_dungeon_scene_manager ~= nil then
		team_dungeon_scene_manager.destroy_scene(scene_id)
	end
	if main_dungeon_scene_manager ~= nil then
		main_dungeon_scene_manager.destroy_scene(scene_id)
	end
	if task_dungeon_scene_manager ~= nil then
		task_dungeon_scene_manager.destroy_scene(scene_id)
	end
	if faction_scene_manager ~= nil then
		faction_scene_manager.destroy_scene(scene_id)
	end
	return
end

local function create_dungeon_npc(scene_id,npc_data)
	local scene = find_scene(scene_id)
	if scene then
		return scene:create_dungeon_npc(npc_data)
    end
    return nil
end

local function destroy_entity(scene_id,entity_id)
	flog("tmlDebug","scene_manager destroy_entity")
	local scene = find_scene(scene_id)
	if scene then
		scene:destroy_entity(entity_id)
	end
end

return {
	find_scene = find_scene,
	destroy_scene = destroy_scene,
	destroy_entity = destroy_entity,
	create_dungeon_npc = create_dungeon_npc,
}