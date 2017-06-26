--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/3 0003
-- Time: 9:55
-- To change this template use File | Settings | File Templates.
--

local common_scene = require "data/common_scene"
local flog = require "basic/log"
local const = require "Common/constant"
local create_add_up_table = require("basic/scheme").create_add_up_table
local get_random_index_with_weight_by_count = require("basic/scheme").get_random_index_with_weight_by_count
local monster_setting = common_scene.MonsterSetting
local guard_npc_scheme = common_scene.Guardnpc
local guard_npc_camp_table
local guard_npc_addup
local trigger_guard_npc_original = common_scene.TriggerGuardnpc
local recreate_scheme_table_with_key = require("basic/scheme").recreate_scheme_table_with_key
local trigger_guard_npc_scheme
local transport_fleet_original_scheme = common_scene.Transporter
local transport_fleet_scheme
local math = math

local scenes = {}
local born_positions = {}
local scenes_resource = {}

local function get_scene_config(id)
    return scenes[id]
end

local function get_main_scene_table()
    return scenes
end

local function get_monster_config(monster_id)
    return monster_setting[monster_id]
end

local function get_scene_detail_config(id)
    if scenes[id] ~= nil then
        return common_scene[scenes[id].SceneSetting]
    end
    return nil
end

local function get_random_guard_npc(country, monster_scene_id)
    if guard_npc_addup[country] == nil then
        return
    end
    local trigger_type = trigger_guard_npc_scheme[monster_scene_id]
    if trigger_type == nil then
        return
    end
    trigger_type = trigger_type.TriggerType
    local weight_addup_table = guard_npc_addup[country][trigger_type]
    if table.isEmptyOrNil(weight_addup_table) then
        return
    end

    local index = get_random_index_with_weight_by_count(weight_addup_table)
    return guard_npc_camp_table[country][trigger_type][index]
end

local function get_random_transport_fleet(country)
    local transport_fleet_country_config = transport_fleet_scheme[country]
    local length = #transport_fleet_country_config
    local random_index = math.random(length)
    return transport_fleet_country_config[random_index]
end

local function get_scene_setting(id)
    if scenes[id] == nil then
        return nil
    end
    return common_scene[scenes[id].SceneSetting]
end

local function get_scene_element_config(sid,element)
    local scene_setting = get_scene_setting(sid)
    if scene_setting == nil then
        return nil
    end
    return scene_setting[element]
end

local function get_random_born_pos(id)
    if born_positions[id] == nil then
        return nil
    end
    local born_count = #born_positions[id]
    if born_count == 0 then
        return nil
    end
    if born_count == 1 then
        return born_positions[id][born_count]
    end

    return born_positions[id][math.random(born_count)]
end

local function get_scene_resource_config(scene_resource_id)
	return scenes_resource[scene_resource_id]
end

local function get_scene_resource_ids()
    local ids = {}
    for id,_ in pairs(scenes_resource) do
        table.insert(ids,id)
    end
    return ids
end

local function get_scene_scheme_table()
    return common_scene
end

local function reload()
    born_positions = {}
    --检查出生点
    for id,v in pairs(common_scene.MainScene) do
        local find = false
        for _,v1 in pairs(common_scene[v.SceneSetting]) do
            if v1.Type == const.ENTITY_TYPE_BIRTHDAY_POS then
                find = true
                if born_positions[v.ID] == nil then
                    born_positions[v.ID] = {}
                end
                table.insert(born_positions[v.ID],{v1.PosX,v1.PosY,v1.PosZ,v1.ForwardY})
            end
        end
        if find == false then
            flog("error","can not find birth position in main scene,id "..id)
        end
        scenes[id] = v
    end

    -- 守卫npc根据权重和阵营初始化
    guard_npc_camp_table = {{}, {} }

    for i, v in ipairs(guard_npc_scheme) do
        if v.Camp ~= 1 and v.Camp ~= 2 then
            flog("error", "guard_npc_scheme camp must be 1 or 2")
        end
        if guard_npc_camp_table[v.Camp][v.TriggerType] == nil then
            guard_npc_camp_table[v.Camp][v.TriggerType] = {}
        end

        table.insert(guard_npc_camp_table[v.Camp][v.TriggerType], v)
    end

    guard_npc_addup = {{}, {}}
    for i = 1, 2 do
        for trigger_type, v in pairs(guard_npc_camp_table[i]) do
            guard_npc_addup[i][trigger_type] = create_add_up_table(v, "Weight")
        end
    end

    -- 守卫npc触发类型
    trigger_guard_npc_scheme = recreate_scheme_table_with_key(trigger_guard_npc_original, "ElementID")

    -- 运输车初始化
    transport_fleet_scheme = {{}, {} }
    local index = {{}, {}}
    for i, v in pairs(transport_fleet_original_scheme) do
        local team_id = v.TransporterID
        local country = v.Camp
        local country_scheme = transport_fleet_scheme[country]
        if country_scheme == nil then
            flog("error", "transport_fleet_scheme error Camp, line "..i)
            return
        end

        local order = index[country][team_id]
        if order == nil then
            local new_team = {}
            table.insert(transport_fleet_scheme[country], new_team)
            table.insert(new_team, v)
            index[country][team_id] = #transport_fleet_scheme[country]
        else
            table.insert(transport_fleet_scheme[country][order], v)
        end
    end

    --场景汇总
    scenes_resource = {}
    for _,v in pairs(common_scene.TotalScene) do
        scenes_resource[v.SceneID] = v
    end
end
reload()

return{
    get_scene_config = get_scene_config,
    get_main_scene_table = get_main_scene_table,
    get_monster_config = get_monster_config,
    get_scene_detail_config = get_scene_detail_config,
    get_random_guard_npc = get_random_guard_npc,
    get_random_transport_fleet = get_random_transport_fleet,
    get_scene_setting = get_scene_setting,
    get_random_born_pos = get_random_born_pos,
    get_scene_resource_config = get_scene_resource_config,
    get_scene_element_config = get_scene_element_config,
    get_scene_resource_ids = get_scene_resource_ids,
    get_scene_scheme_table = get_scene_scheme_table,
    reload = reload,
}

