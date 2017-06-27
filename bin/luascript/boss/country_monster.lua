--------------------------------------------------------------------
-- 文件名:	country_monster.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/5/8 0008 
-- 描  述:	阵营boss 总boss 守卫npc 箭塔
--------------------------------------------------------------------
local timer = require "basic/timer"
local const = require "Common/constant"
local db_hiredis = require "basic/db_hiredis"
local tonumber = tonumber
local pairs = pairs
local center_server_manager = require "center_server_manager"
local flog = require "basic/log"
local common_scene_config = require "configs/common_scene_config"
local pvp_country_war_config = require "configs/pvp_country_war_config"
local get_random_transport_fleet = common_scene_config.get_random_transport_fleet
local transport_fleet_manager = require "Common/combat/Entity/TransportFleetManager"
local online_user = require "onlinerole"
local get_scene_detail_config = common_scene_config.get_scene_detail_config
local tostring = tostring
local create_system_message_by_id = require("basic/scheme").create_system_message_by_id
local fix_string = require "basic/fix_string"
local _get_now_time_second = _get_now_time_second
local broadcast_message = require("basic/net").broadcast_message
local is_in_battle = false
local math_floor = math.floor
local game_id = _get_serverid()

local BATTLE_SCENE_LIST = const.BATTLE_SCENE_LIST
local FLEET_TYPE_NAME_TO_INDEX = const.FLEET_TYPE_NAME_TO_INDEX
local CLOSE_ENOUGH_SQUARE = 4

local monster_puppet_list = {}
local transport_puppet_list = {}
local state_sync_timer

local country_monster_state = {}
local transport_fleet_state = {}
local transport_fleet_state_modified = false
local transport_id_index = {}
local transport_fleet_is_under_attack = {}
local gm_dispatch_fleet_time = 0
local country_war_start_time = 0
local country_total_score = {0, 0}

local function create_guard_npc(monster_scene_id, puppet, country)
    local guard_npc_config = common_scene_config.get_random_guard_npc(country, monster_scene_id)
    if guard_npc_config == nil then
        return
    end
    local pos = puppet:GetPosition()
    guard_npc_config.PosX = pos.x
    guard_npc_config.PosY = pos.y
    guard_npc_config.PosZ = pos.z
    guard_npc_config.ID = monster_scene_id
    return puppet:GetEntityManager().CreateScenePuppet(guard_npc_config, EntityType.MonsterCamp)
end


local function create_country_boss(monster_scene_id, entity_manager, monster_buff)
    for _, id in pairs(BATTLE_SCENE_LIST) do
        local scene_config = get_scene_detail_config(id)
        if scene_config[monster_scene_id] ~= nil then
            local new_puppet = entity_manager.CreateScenePuppet(scene_config[monster_scene_id], EntityType.MonsterCamp)
            if monster_buff ~= nil then
                local skill_manager = new_puppet.skillManager
                skill_manager:AddBuff(monster_buff)
            end
            return new_puppet
        end
    end
end

local function _is_time_send_transport_fleet()
    local current_time = _get_now_time_second()
    if pvp_country_war_config.is_dispatch_fleet_time(current_time) then
        return true
    end
    if current_time < gm_dispatch_fleet_time then
        return true
    end
    return false
end

local function _init_transport_fleet()
    local refresh_number = pvp_country_war_config.transport_fleet_refresh_number
    transport_fleet_state = {}
    for country = 1, 2 do
        for i = 1, refresh_number do
            local key = string.format("transport_fleet_%d_%d", country, i)
            transport_fleet_state[key] = {country = country, is_refreshed = false}
        end
    end
    transport_fleet_state_modified = false
    db_hiredis.del("transport_fleet_state")
end

local function transport_fleet_tick()
    if not _is_time_send_transport_fleet() then
        if transport_fleet_state_modified then
            _init_transport_fleet()
        end
        return
    end

    transport_fleet_state_modified = true
    for key, v in pairs(transport_fleet_state) do
        if not v.is_refreshed then
            local result = db_hiredis.hsetnx("transport_fleet_state", key, true)
            if result then
                -- 创建一组运输车队
                local create_success = false
                for i = 1, 5 do
                    local fleet_list = get_random_transport_fleet(v.country)
                    local trans_id = fleet_list[1].TransporterID
                    if transport_id_index[trans_id] == nil then
                        v.is_refreshed = true
                        local result = transport_fleet_manager:AddTransportFleetItem(trans_id)
                        flog("syzDebug", string.format("transport_fleet_state create %d result %s", trans_id, tostring(result)))
                        if result then
                            create_success = true
                            transport_id_index[trans_id] = v
                            transport_fleet_is_under_attack[trans_id] = false
                            break
                        end
                    end
                end
                if not create_success then
                    flog("info", "transport_fleet_state create failed")
                    db_hiredis.hdel("transport_fleet_state", key)
                end
                break
            end
        end
    end

end

local function switch_rebirth_pos(monster_scene_id, country)
    for _, scene_id in pairs(BATTLE_SCENE_LIST) do
        local scene = scene_manager.find_scene(scene_id)
        if scene ~= nil then
            scene:switch_birth_pos_country(monster_scene_id, country)
        end
    end
end

local function monster_state_sync_callback()
    local war_state = db_hiredis.get("country_war_state") or {start_time = 0, is_in_battle = false, country_total_score = {0, 0}}
    country_war_start_time = war_state.start_time
    is_in_battle = war_state.is_in_battle
    country_total_score = war_state.country_total_score
    country_monster_state = db_hiredis.get("country_monster_state") or {}

    local country_boss_leader_buff_id = pvp_country_war_config.country_boss_leader_buff_id
    local total_boss = {{buff_layer = 0}, {buff_layer = 0}}
    for monster_scene_id, monster_state in pairs(country_monster_state) do
        local boss_leader_config = total_boss[monster_state.country]
        if monster_state.type == const.ENTITY_TYPE_COUNTRY_BOSS_LEADER then
            boss_leader_config.monster_scene_id = monster_scene_id
        end
        if monster_state.type == const.ENTITY_TYPE_COUNTRY_BOSS and monster_state.order == 0 and monster_state.hp > 0 then
            boss_leader_config.buff_layer = boss_leader_config.buff_layer + 1
        end

        local monster_puppet = monster_puppet_list[monster_scene_id]
        if monster_puppet ~= nil and monster_puppet.puppet ~= nil then
            local puppet = monster_puppet.puppet
            local country = (monster_state.order + monster_state.country + 1) % 2 + 1
            if monster_puppet.order ~= monster_state.order then
                if not puppet:IsDied() then
                    --kill_monster
                    puppet:SetHp(0)
                    puppet:Died()
                end
                monster_puppet.order = monster_state.order

                --切换复活点归属
                switch_rebirth_pos(monster_scene_id, country)
            end
            if puppet:IsDied() then
                local current_time = _get_now_time_second()
                if monster_state.hp > 0 and monster_state.rebirth_time ~= nil and current_time >= monster_state.rebirth_time then
                    local entity_manager = puppet:GetEntityManager()
                    entity_manager.DestroyPuppet(puppet.uid)
                    flog("syzDebug", string.format("new country_monster %d hp %d order %d", monster_scene_id, monster_state.hp, monster_state.order))

                    if monster_state.order == -1 then       --死亡，无守卫npc接替
                    elseif monster_state.order == 0 then    --重新开始
                        local new_puppet = create_country_boss(monster_scene_id, puppet:GetEntityManager(), monster_state.monster_buff)
                        monster_puppet.puppet = new_puppet
                    else        --死亡，有守卫npc接替
                        local new_puppet = create_guard_npc(monster_scene_id, puppet, country)
                        monster_puppet.puppet = new_puppet
                        puppet = new_puppet
                    end
                    puppet:SetLevel(monster_state.level)
                    puppet:SetHp(monster_state.hp)
                end
            else
                if puppet.level ~= monster_state.level then
                    puppet:SetLevel(monster_state.level)
                end
                local puppet_hp_max = puppet.hp_max()
                if puppet_hp_max ~= monster_state.max_hp then
                    --flog("syzDebug", string.format("country_monster %d puppet hp_max %d true hpmax %d", monster_scene_id, puppet.hp_max(), monster_state.max_hp))
                end

                if puppet.hp ~= monster_state.hp and monster_state.hp > 0 then
                    flog("syzDebug", string.format("country_monster %d hp %d order %d", monster_scene_id, monster_state.hp, monster_state.order))
                    puppet:SetHp(monster_state.hp)
                end
            end
        end
    end

    -- 阵营boss对总boss的buff加成
    for country, boss_leader_config in pairs(total_boss) do
        local monster_scene_id = boss_leader_config.monster_scene_id
        local monster_puppet = monster_puppet_list[monster_scene_id]
        if monster_puppet ~= nil and monster_puppet.puppet ~= nil then
            local puppet = monster_puppet.puppet
            local skill_manager = puppet.skillManager
            if skill_manager ~= nil then
                local buff = skill_manager:FindBuff(country_boss_leader_buff_id)
                if buff ~= nil then
                    skill_manager:RemoveBuff(buff)
                end
                for i = 1, boss_leader_config.buff_layer do
                    skill_manager:AddBuff(country_boss_leader_buff_id)
                end
            end
        end
    end

    transport_fleet_tick()
end

local function _server_start()
    if state_sync_timer == nil then
        state_sync_timer = timer.create_timer(monster_state_sync_callback, 1000, const.INFINITY_CALL)
    end
    _init_transport_fleet()
end
register_function_on_start(_server_start)

local function on_country_monster_born(monster_scene_id, puppet)
    if monster_puppet_list[monster_scene_id] == nil then
        monster_puppet_list[monster_scene_id] = {order = 0, puppet = puppet }
    else
        monster_puppet_list[monster_scene_id].puppet = puppet
    end
end

local function on_country_monster_take_damage(monster_scene_id, attacker_id, damage, attacker_name, is_player, attacker_level)
    local monster_puppet = monster_puppet_list[monster_scene_id]
    if monster_puppet == nil then
        return
    end

    local output = {func_name = "on_being_attack" }
    output.monster_scene_id = monster_scene_id
    output.monster_order = monster_puppet.order
    output.actor_id = attacker_id
    output.damage = damage
    output.attacker_name = attacker_name
    output.is_player = is_player
    output.attacker_level = attacker_level
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.country_service,const.GC_MESSAGE_LUA_GAME_RPC,output)
end

local function _hatred_list_filter(hatred_list)
    local new_hatred_list = {}
    for _, entity_id in pairs(hatred_list) do
        local entity = online_user.get_user(entity_id)
        if entity ~= nil then
            new_hatred_list[entity_id] = {damage = 0, name = entity.actor_name, level = entity.level}
        end
    end
    return new_hatred_list
end

local function is_puppet_transport_van(puppet)
    local obj_type = puppet.data.sceneType
    local fleet_type = tonumber(puppet.data.Para1)
    if obj_type == const.ENTITY_TYPE_TRANSPORT_FLEET and FLEET_TYPE_NAME_TO_INDEX.VAN == fleet_type then
        return true
    end
    return false
end

local function on_transport_fleet_be_killed(puppet, name, killer_id, killer_name, hatred_list, is_player, killer_level)
    if not is_puppet_transport_van(puppet) then
        return
    end
    flog("info", string.format("on_transport_fleet_be_killed %s kill %s ", killer_name, name))
    local trans_id = puppet.TransporterID
    transport_fleet_manager:DeleteTransportFleet(trans_id, false)

    if puppet.position_timer ~= nil then
        timer.destroy_timer(puppet.position_timer)
        puppet.position_timer = nil
    end
    transport_fleet_is_under_attack[trans_id] = false
    transport_id_index[trans_id] = nil
    transport_puppet_list[trans_id] = nil

    local output = {func_name = "transport_fleet_be_killed"}
    output.killer_id = killer_id
    output.killer_name = killer_name
    output.hatred_list = _hatred_list_filter(hatred_list)
    local fleet_country = puppet.data.Camp
    output.country = fleet_country % 2 + 1
    output.dead_name = name
    output.actor_id = killer_id
    output.is_player = is_player
    output.killer_level = killer_level
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.country_service,const.GC_MESSAGE_LUA_GAME_RPC,output)
end

local function on_transport_fleet_get_target(puppet, name)
    flog("info", "on_transport_fleet_get_target")

    if puppet.position_timer ~= nil then
        timer.destroy_timer(puppet.position_timer)
        puppet.position_timer = nil
    end

    local trans_id = puppet.TransporterID
    transport_fleet_manager:DeleteTransportFleet(trans_id, true)
    transport_puppet_list[trans_id] = nil

    transport_id_index[trans_id] = nil

    local output = {func_name = "transport_fleet_get_target"}
    output.country = puppet.data.Camp
    output.name = name
    output.actor_id = "global_id_without_actor"
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.country_service,const.GC_MESSAGE_LUA_GAME_RPC,output)
end

local function on_transport_fleet_born(puppet, name)
    if not is_puppet_transport_van(puppet) then
        return
    end

    local move_path_str = puppet.data.LimitedRadius
    local move_path = string.split(move_path_str, '|')
    local target_pos_str = move_path[#move_path]
    local target_pos_temp = string.split(target_pos_str, '*')
    local target_pos = {}
    target_pos.x = tonumber(target_pos_temp[1])
    target_pos.y = tonumber(target_pos_temp[2])
    target_pos.z = tonumber(target_pos_temp[3])

    if target_pos.x == nil or target_pos.y == nil or target_pos.z == nil then
        flog("error", "on_transport_fleet_born error move path "..tostring(puppet.data.TransporterID))
    end

    local trans_id = puppet.TransporterID
    transport_puppet_list[trans_id] = puppet

    local function position_timer_callback()
        local pos = puppet:GetPosition()
        local delta_x = pos.x - target_pos.x
        local delta_y = pos.y - target_pos.y
        local delta_z = pos.z - target_pos.z
        local distance_square = delta_x * delta_x + delta_y * delta_y + delta_z * delta_z
        if distance_square <= CLOSE_ENOUGH_SQUARE then
            on_transport_fleet_get_target(puppet, name)
        end
    end

    puppet.position_timer = timer.create_timer(position_timer_callback, 1000, const.INFINITY_CALL)
end

local function on_transport_fleet_be_attack(puppet)
    local obj_type = puppet.data.sceneType
    if obj_type ~= const.ENTITY_TYPE_TRANSPORT_FLEET then
        return
    end

    local trans_id = puppet.TransporterID
    if not transport_fleet_is_under_attack[trans_id] then
        -- 广播消息
        local country = puppet.data.Camp
        local scene_id = puppet:GetSceneID()
        local pos = puppet:GetPosition()
        local x = math_floor(pos.x * 100)
        local y = math_floor(pos.y * 100)
        local z = math_floor(pos.z * 100)
        local attach = {type = 'position' , x = x, z = z, scene_id = scene_id, game_id = game_id }
        local pos_str = common_scene_config.get_position_string(scene_id, pos.x, pos.z, game_id)
        local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.transport_fleet_is_under_attack, {}, fix_string["country_name_"..country], pos_str)
        broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data, country)
    end

    transport_fleet_is_under_attack[trans_id] = true
end

local function on_transport_fleet_out_of_danger(puppet)
    local obj_type = puppet.data.sceneType
    if obj_type ~= const.ENTITY_TYPE_TRANSPORT_FLEET then
        return
    end

    local trans_id = puppet.TransporterID
    transport_fleet_is_under_attack[trans_id] = false
end

function gm_dispatch_transport_fleet_now()
    gm_dispatch_fleet_time = _get_now_time_second() + 60
end

local function get_country_war_start_time()
    return country_war_start_time
end

local function is_in_battle_time()
    return is_in_battle
end

local function get_country_total_score()
    return country_total_score
end

local function get_country_monster_hp(monster_scene_id)
    local monster_state = country_monster_state[monster_scene_id]
    if monster_state ~= nil then
        return monster_state.hp, monster_state.max_hp
    end
end

local function get_archer_tower_arrow_num(monster_scene_id)
    local monster_state = country_monster_state[monster_scene_id]
    if monster_state ~= nil then
        return monster_state.arrow or 0
    end
end

local function get_transport_fleet_position(scene_id)
    local transport_fleet_pos = {}
    for id, puppet in pairs(transport_puppet_list) do
        if puppet:GetSceneID() == scene_id then
            local pos = puppet:GetPosition()
            if pos ~= nil then
                local x = math_floor(pos.x * 100)
                local y = math_floor(pos.y * 100)
                local z = math_floor(pos.z * 100)
                transport_fleet_pos[id] = {x = x, y = y, z = z}
            end
        end
    end
    return transport_fleet_pos
end

return {
    on_country_monster_born = on_country_monster_born,
    on_country_monster_take_damage = on_country_monster_take_damage,
    _server_start = _server_start,
    on_transport_fleet_be_killed = on_transport_fleet_be_killed,
    on_transport_fleet_born = on_transport_fleet_born,
    on_transport_fleet_be_attack = on_transport_fleet_be_attack,
    on_transport_fleet_out_of_danger = on_transport_fleet_out_of_danger,
    gm_dispatch_transport_fleet_now = gm_dispatch_transport_fleet_now,
    get_country_war_start_time = get_country_war_start_time,
    is_in_battle_time = is_in_battle_time,
    get_country_total_score = get_country_total_score,
    get_country_monster_hp = get_country_monster_hp,
    get_archer_tower_arrow_num = get_archer_tower_arrow_num,
    get_transport_fleet_position = get_transport_fleet_position,
}