--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/6/5 0005
-- Time: 18:32
-- To change this template use File | Settings | File Templates.
--
local system_faction = require "data/system_faction"
local const = require "Common/constant"
local flog = require "basic/log"

local faction_scenes = {}
local born_positions = {}
local faction_building = {}
local faction_hall = {}
local faction_treasary = {}
local faction_altar = {}
local faction_investment = {}
local faction_authority = {}

local function get_faction_scene_config(id)
    return faction_scenes[id]
end

local function get_faction_scenes_config()
    return faction_scenes
end

local function get_scene_setting(id)
    if faction_scenes[id] ~= nil then
        return system_faction[faction_scenes[id].SceneSetting]
    end
    return nil
end

local function get_faction_table()
    return system_faction
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

local function _sort_faction_investment(a,b)
    return a.TimeLowerLimit < b.TimeLowerLimit
end

local function reload()
    faction_scenes = {}
    born_positions = {}
    for _,v in pairs(system_faction.GangMap) do
        local find = false
        for _,v1 in pairs(system_faction[v.SceneSetting]) do
            if v1.Type == const.ENTITY_TYPE_BIRTHDAY_POS then
                find = true
                if born_positions[v.ID] == nil then
                    born_positions[v.ID] = {}
                end
                table.insert(born_positions[v.ID],{v1.PosX,v1.PosY,v1.PosZ,v1.ForwardY})
            end
        end
        if find == false then
            flog("error","can not find birth position in main scene,id "..v.ID)
        end
        faction_scenes[v.ID] = v
    end
    faction_building = {}
    for _,v in pairs(system_faction.Building) do
        faction_building[v.ID] = v
    end

    faction_hall = {}
    for _,v in pairs(system_faction.Hall) do
        faction_hall[v.Level] = v
    end

    faction_treasary = {}
    for _,v in pairs(system_faction.Vault) do
        faction_treasary[v.Level] = v
    end

    faction_altar = {}
    for _,v in pairs(system_faction.Altar) do
        faction_altar[v.Level] = v
    end

    faction_investment = {}
    for _,v in pairs(system_faction.Investment) do
        if #v.Cost1 ~= 2 or #v.Cost2 ~= 2 then
            flog("error","system_faction.Investment config error!TimeLowerLimit "..v.TimeLowerLimit)
        end
        table.insert(faction_investment,v)
    end
    if #faction_investment > 1 then
        table.sort(faction_investment,_sort_faction_investment)
    end

    faction_authority = {}
    for _,v in pairs(system_faction.Authority) do
        faction_authority[v.Position] = v
    end
end

local function get_building_basic_config(id)
    return faction_building[id]
end

local function get_hall_config(level)
    return faction_hall[level]
end

local function get_treasary_config(level)
    return faction_treasary[level]
end

local function get_altar_config(level)
    return faction_altar[level]
end

local function check_building(id)
    return faction_building[id] ~= nil
end

local function get_investment_config(count)
    for i = #faction_investment,1,-1 do
        if faction_investment[i].TimeLowerLimit <= count then
            return faction_investment[i]
        end
    end
    return nil
end

local function get_authority_config(position)
    return faction_authority[position]
end

local function get_faction_init_fund()
    return system_faction.Parameter[24].Value
end

local function get_maintain_hour()
    return system_faction.Parameter[25].Value
end

local function get_investment_buff_id()
    return system_faction.Parameter[26].Value
end

local function get_faction_breakup_dissolve_time()
    return system_faction.Parameter[27].Value*3600
end

reload()

return{
    reload = reload,
    get_faction_scene_config = get_faction_scene_config,
    get_scene_setting = get_scene_setting,
    get_faction_table = get_faction_table,
    get_scene_element_config = get_scene_element_config,
    get_random_born_pos = get_random_born_pos,
    get_building_basic_config = get_building_basic_config,
    get_hall_config = get_hall_config,
    get_treasary_config = get_treasary_config,
    get_altar_config = get_altar_config,
    check_building = check_building,
    get_investment_config = get_investment_config,
    get_authority_config = get_authority_config,
    get_faction_init_fund = get_faction_init_fund,
    get_maintain_hour = get_maintain_hour,
    get_faction_breakup_dissolve_time = get_faction_breakup_dissolve_time,
    get_investment_buff_id = get_investment_buff_id,
}
