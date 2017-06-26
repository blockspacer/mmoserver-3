--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/12 0012
-- Time: 16:42
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local scene_func = require "scene/scene_func"
local flog = require "basic/log"
local challenge_arena_table = require "data/challenge_arena"
local arena_dogfight_scene = require "scene/arena_dogfight_scene"

local scenes = {}
local scene_id_index = 0

--排位赛出生位置
local qualifying_born_pos = {}
local scene_setting = challenge_arena_table[challenge_arena_table.ArenaScene[const.ARENA_QUALIFYING_SCENE_ID].SceneSetting]
if scene_setting ~= nil then
    local borns = {}
    for _,setting in pairs(scene_setting) do
        if setting.Type == const.ENTITY_TYPE_BIRTHDAY_POS then
            table.insert(borns,setting)
        end
    end
    table.sort(borns,function(a,b)
        return a.ID < b.ID
    end)
    for i=1,#borns,1 do
        table.insert(qualifying_born_pos,{borns[i].PosX,borns[i].PosY,borns[i].PosZ,borns[i].ForwardY})
    end
end
if #qualifying_born_pos == 0 then
    flog("error","can not init arena qualifying born pos!")
end

--混战赛出生位置
local dogfight_born_pos = {}
scene_setting = challenge_arena_table[challenge_arena_table.ArenaScene[const.ARENA_DOGFIGHT_SCENE_ID].SceneSetting]
if scene_setting ~= nil then
    for _,setting in pairs(scene_setting) do
        if setting.Type == const.ENTITY_TYPE_BIRTHDAY_POS then
            table.insert(dogfight_born_pos,{setting.PosX,setting.PosY,setting.PosZ,setting.ForwardY})
        end
    end
end
if #dogfight_born_pos == 0 then
    flog("error","can not init arena qualifying born pos!")
end

-- 加载所有场景元素
local function load_scene(sceneID,scene_config,scene_setting)
    scene_id_index = scene_id_index + 1
    if scene_id_index > 10000 then
        scene_id_index = 0
    end
    local aoi_scene_id = const.SCENE_TYPE.ARENA*100000000 + sceneID*10000 + scene_id_index
	local s = arena_dogfight_scene()

    s:initialize(aoi_scene_id,scene_config,sceneID,scene_setting)
	local result = scene_func.create_dungeon_scene(aoi_scene_id,"detour/"..scene_config.SceneID..".nav")
    if not result then
        flog("error","can not create arena scene!arena id "..sceneID)
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

local function create_qualifying_scene(fight_id)
    local arena_scene_table = challenge_arena_table.ArenaScene
    local arena_qualifying_scene_config = arena_scene_table[const.ARENA_QUALIFYING_SCENE_ID]
    if arena_qualifying_scene_config == nil then
        flog("tmlDebug","can not find qualifying scene config!")
        return 0
    end

    local aoi_scene_id = load_scene(const.ARENA_QUALIFYING_SCENE_ID,arena_qualifying_scene_config,challenge_arena_table[arena_qualifying_scene_config.SceneSetting])
    scenes[aoi_scene_id]:create_trriger_manager(challenge_arena_table,arena_scene_table[const.ARENA_QUALIFYING_SCENE_ID].SceneSetting)
    scenes[aoi_scene_id]:set_fight_id(fight_id)
    return aoi_scene_id
end

local function get_qualifying_scene_born_pos(index)
    if qualifying_born_pos[index] == nil then
        return qualifying_born_pos[1]
    end
    return qualifying_born_pos[index]
end

--混战赛场景
local function create_dogfight_scene(fight_id)
    local arena_scene_table = challenge_arena_table.ArenaScene
    local arena_dogfight_scene_config = arena_scene_table[const.ARENA_DOGFIGHT_SCENE_ID]
    if arena_dogfight_scene_config == nil then
        flog("tmlDebug","can not find dogfight scene config!")
        return 0
    end

    local aoi_scene_id = load_scene(const.ARENA_DOGFIGHT_SCENE_ID,arena_dogfight_scene_config,challenge_arena_table[arena_dogfight_scene_config.SceneSetting])
    scenes[aoi_scene_id]:create_trriger_manager(challenge_arena_table,arena_scene_table[const.ARENA_DOGFIGHT_SCENE_ID].SceneSetting)
    scenes[aoi_scene_id]:set_fight_id(fight_id)

    return aoi_scene_id
end

local function get_dogfight_scene_born_pos(index)
    if dogfight_born_pos[index] == nil then
        return dogfight_born_pos[1]
    end
    return dogfight_born_pos[index]
end
--register_function_on_start(init)

return {
    load_scene = load_scene,
	find_scene = find_scene,
	destroy_scene = destroy_scene,
    create_qualifying_scene = create_qualifying_scene,
    get_qualifying_scene_born_pos = get_qualifying_scene_born_pos,
    create_dogfight_scene = create_dogfight_scene,
    get_dogfight_scene_born_pos = get_dogfight_scene_born_pos,
}

