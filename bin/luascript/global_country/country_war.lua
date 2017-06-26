--------------------------------------------------------------------
-- 文件名:	country_war.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/5/8 0008
-- 描  述:	阵营大攻防
--------------------------------------------------------------------
local fix_string = require "basic/fix_string"
local timer = require "basic/timer"
local const = require "Common/constant"
local db_hiredis = require "basic/db_hiredis"
local common_scene_config = require "configs/common_scene_config"
local get_scene_detail_config = common_scene_config.get_scene_detail_config
local get_monster_config = common_scene_config.get_monster_config
local common_fight_base_config = require "configs/common_fight_base_config"
local pvp_country_war_config = require "configs/pvp_country_war_config"
local get_modify_level = pvp_country_war_config.get_modify_level
local flog = require "basic/log"
local get_server_level = require("helper/global_server_data").get_server_level
local _get_now_time_second = _get_now_time_second
local get_battle_score = pvp_country_war_config.get_battle_score
local get_loser_buff_id = pvp_country_war_config.get_loser_buff_id
local center_server_manager = require "center_server_manager"
local get_config_name = require("basic/scheme").get_config_name
local broadcast_message = require("basic/net").broadcast_message
local get_top_n = require("basic/scheme").get_top_n
local create_system_message_by_id = require("basic/scheme").create_system_message_by_id
local battle_rank_reward = pvp_country_war_config.battle_rank_reward
local mail_helper = require "global_mail/mail_helper"
local create_rank_list = require("global_ranking/basic_rank_list").create_rank_list
local update_rank_list = require("global_ranking/basic_rank_list").update_rank_list
local pvp_country_config = require "configs/pvp_country_config"

local BATTLE_TIMER_INTERVAL = 1000
local MAX_RECORD_NUM_IN_ACHIEVEMENT_LIST = 100
local BATTLE_SCENE_LIST = const.BATTLE_SCENE_LIST
local RECORD_TYPE_TO_TEXT_ID = {
    kill_country_boss_1 = 1135053,
    kill_country_boss_2 = 1135052,
    fleet_get_target_1 = 1135055,
    fleet_get_target_2 = 1135054,
}

local battle_timer
local already_in_battle_time = false
local is_in_battle = false
local country_monster_list = {}
local country_total_score = {0, 0}
local battle_achievement_dict = {{}, {} }
local battle_achievement_list = {}
for country = 1, 2 do
    battle_achievement_list[country] = create_rank_list("battle_achievement_list_"..country, "score", MAX_RECORD_NUM_IN_ACHIEVEMENT_LIST, "actor_id")
end
local monster_hatred_list = {}
local battle_record = {}
local country_war_winner = -1
local gm_end_war_time = 0
local battle_start_time = 0
local notice_sended = false

local function get_monster_modify_info(monster_id)
    local monster_config = get_monster_config(monster_id)
    local monster_type = monster_config.Type
    local level = get_modify_level(monster_type)
    local server_level = get_server_level()
    level = level + server_level
    local key =  level.. "_" .. monster_config.Power .. "_" .. monster_type
    local monster_attrib = common_fight_base_config.get_monster_attribute(key)
    local hp = monster_attrib.Hp
    return level, hp, monster_type
end


local function init_country_monster()
    local current_time = _get_now_time_second()
    local past_winner = db_hiredis.get("country_war_winner") or {winner = 0, continuous_times = 0}
    local buff_id
    local loser_country = 0
    if past_winner.winner ~= 0 then
        loser_country = past_winner.winner % 2 + 1
        buff_id = get_loser_buff_id(past_winner.continuous_times)
    end


    local function get_data()
        return db_hiredis.get("country_monster_state") or {}
    end
    local function err_handler()
        db_hiredis.del("country_monster_state")
        return {}
    end
    local rst, country_monster_state = xpcall(get_data, err_handler)

    for _, id in pairs(BATTLE_SCENE_LIST) do
        local scene_config = get_scene_detail_config(id)
        for obj_scene_id, obj_config in pairs(scene_config) do
            if const.SHARE_HP_CONTRY_MONSTER[obj_config.Type] then
                local level, hp = get_monster_modify_info(obj_config.MonsterID)
                local country = obj_config.Camp
                if country ~= 1 and country ~= 2 then
                    flog("error", "init_country_monster: Error Camp "..obj_scene_id)
                end
                local monster_buff = nil
                if loser_country == country and buff_id ~= nil then
                    monster_buff = buff_id
                end

                local monster_state = country_monster_state[obj_scene_id] or {}
                monster_state.order = 0
                monster_state.level = level
                monster_state.hp = hp
                monster_state.country = country
                monster_state.type = obj_config.Type
                monster_state.monster_buff = monster_buff
                monster_state.max_hp = hp
                monster_state.rebirth_time = current_time
                country_monster_list[obj_scene_id] = monster_state

                -- 初始化仇恨列表
                monster_hatred_list[obj_scene_id] = {}
            end
        end
    end
end

local function _is_in_battle_time()
    local current_time = _get_now_time_second()
    if pvp_country_war_config.is_country_war_time(current_time) then
        return true
    end
    if current_time < gm_end_war_time then
        return true
    end
    return false
end

local function _get_country_boss_alive()
    local alive_boss_num = {0, 0}
    for monster_scene_id, monster_state in pairs(country_monster_list) do
        if monster_state.type == const.ENTITY_TYPE_COUNTRY_BOSS or monster_state.type == const.ENTITY_TYPE_COUNTRY_BOSS_LEADER then
            if monster_state.order == 0 and monster_state.hp > 0 then
                local country = monster_state.country
                alive_boss_num[country] = alive_boss_num[country] + 1
            end
        end
    end
    return alive_boss_num
end

local function _update_war_state()
    local war_state = {start_time = battle_start_time, is_in_battle = is_in_battle, country_total_score = country_total_score}
    db_hiredis.set("country_war_state", war_state)
    local alive_boss_num = _get_country_boss_alive()
    broadcast_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "SyncCountryWarInfo", country_total_score = country_total_score, alive_boss_num = alive_boss_num})
end

local function _battle_start()
    is_in_battle = true
    init_country_monster()
    battle_achievement_dict = {{}, {} }
    battle_record = {}
    country_total_score = {0, 0 }
    country_war_winner = -1
    battle_achievement_list = {}
    for country = 1, 2 do
        battle_achievement_list[country] = create_rank_list("battle_achievement_list_"..country, "score", MAX_RECORD_NUM_IN_ACHIEVEMENT_LIST, "actor_id")
    end
    battle_start_time =  _get_now_time_second()
    notice_sended = false

    _update_war_state()
end

local function _battle_achievement_reward(country_achievement_list)
    local length = #battle_rank_reward
    for i = 2, length do
        local start_index = battle_rank_reward[i - 1].RankedLowerlimit
        local end_index = battle_rank_reward[i].RankedLowerlimit - 1

        local rewards = {}
        for k = 1, 4 do
            local rwd = battle_rank_reward[i - 1]["Reward"..k]
            if not table.isEmptyOrNil(rwd) then
                local rwd_temp = {}
                rwd_temp.item_id = rwd[1]
                rwd_temp.count = rwd[2]
                table.insert(rewards, rwd_temp)
            end
        end
        for j = start_index, end_index do
            if country_achievement_list[j] ~= nil then
                local actor_id = country_achievement_list[j].actor_id
                mail_helper.send_mail(actor_id,const.MAIL_IDS.BATTLE_RANK_REWARD, rewards,_get_now_time_second(),{j})
            end
        end
    end
end

local function _battle_end(winner)
    is_in_battle = false
    gm_end_war_time = 0
    init_country_monster()

    _update_war_state()

    local alive_boss_num = _get_country_boss_alive()
    if winner == nil then
        local loser
        if alive_boss_num[1] > alive_boss_num[2] then
            winner = 1
            loser = 2
        elseif alive_boss_num[1] < alive_boss_num[2] then
            winner = 2
            loser = 1
        else
            winner = 0
        end
    end

    country_war_winner = winner
    local past_winner = db_hiredis.get("country_war_winner") or {}
    if past_winner.winner == winner then
        past_winner.continuous_times = past_winner.continuous_times + 1
    else
        past_winner.winner = winner
        past_winner.continuous_times = 1
    end
    db_hiredis.set("country_war_winner", past_winner)

    local output_achievement_data = {}
    for country, country_achievement in pairs(battle_achievement_list) do
        output_achievement_data[country] = country_achievement.rank_data
        _battle_achievement_reward(country_achievement.rank_data)
    end
    db_hiredis.set("battle_achievement_list", battle_achievement_list)

    broadcast_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "CountryWarEnd", country_total_score = country_total_score, winner = winner, battle_achievement_list = output_achievement_data, alive_boss_num = alive_boss_num})
end


local function battle_timer_callback()
    if _is_in_battle_time() then
        if is_in_battle then
        elseif not already_in_battle_time then
            already_in_battle_time = true
            _battle_start()
        end
    else
        if is_in_battle then
            _battle_end()
        elseif not notice_sended then
            local current_time = _get_now_time_second()
            if pvp_country_war_config.is_time_send_notice(current_time) then
                notice_sended = true
                local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.prepare_country_war, {})
                broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data)
            end
        end
        already_in_battle_time = false
    end
    db_hiredis.set("country_monster_state", country_monster_list)
end

local function _create_fight_record(key, param)
    local text_id = RECORD_TYPE_TO_TEXT_ID[key]
    local record = {}
    record.text_id = text_id
    record.param = param
    table.insert(battle_record, record)
end

local function _get_monster_name(monster_scene_id)
    local monster_name = fix_string.country_monster
    for _, id in pairs(BATTLE_SCENE_LIST) do
        local scene_config = get_scene_detail_config(id)
        if scene_config[monster_scene_id] ~= nil then
            monster_name = get_config_name(scene_config[monster_scene_id])
            break
        end
    end
    return monster_name
end

local function on_being_attack(monster_scene_id, monster_order, attacker_id, damage, attacker_name, is_player, attacker_level)
    flog("syzDebug", string.format("on_being_attack %d %d %s %d", monster_scene_id, monster_order, attacker_id, damage))
    if not is_in_battle then
        return
    end

    local monster_state = country_monster_list[monster_scene_id]
    if monster_state == nil or monster_order ~= monster_state.order then
        return
    end

    -- 记录仇恨
    local current_time = _get_now_time_second()
    if is_player then
        monster_hatred_list[monster_scene_id][attacker_id] = monster_hatred_list[monster_scene_id][attacker_id] or {damage = 0, name = attacker_name, level = attacker_level}
        local hatred_info = monster_hatred_list[monster_scene_id][attacker_id]
        hatred_info.damage = hatred_info.damage + damage
        hatred_info.last_time = current_time
    end

    -- 扣血操作
    monster_state.hp = monster_state.hp - damage
    local monster_name = _get_monster_name(monster_scene_id)
    if monster_state.hp <= 0 then
        local country_score, killer_score = get_battle_score("kill", "country_monster", monster_state.type)
        local _, assist_score = get_battle_score("assist", "country_monster", monster_state.type)

        -- 更新npc
        monster_state.order = monster_state.order + 1
        local country = (monster_state.order + monster_state.country + 1) % 2 + 1

        if monster_state.type == const.ENTITY_TYPE_COUNTRY_BOSS_LEADER then
            _battle_end(country)        --阵营boss被杀直接胜利
            monster_state.order = -1
        else
            local guard_npc_config = common_scene_config.get_random_guard_npc(country, monster_scene_id)
            if guard_npc_config ~= nil then
                local level, hp, monster_type = get_monster_modify_info(guard_npc_config.MonsterID)
                monster_state.level = level
                monster_state.hp = hp
                monster_state.type = monster_type
                monster_state.rebirth_time = current_time + 6       --几秒后复活
            else
                monster_state.order = -1
                monster_state.rebirth_time = nil
            end
        end

        -- 计算得分
        country_total_score[country] = country_total_score[country] + country_score
        _create_fight_record("kill_country_boss_"..country, {attacker_name, monster_name, country_score})

        -- 广播阵营boss死亡\击杀
        if monster_state.order == 0 then
            local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.country_boss_is_dead, {}, monster_name)
            local r_country = country % 2 + 1
            broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data, r_country)

            local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.enmey_country_boss_be_killed, {}, attacker_name, monster_name)
            broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data, country)
        end


        local output = {func_name = "on_get_country_war_score", monster_name = monster_name}
        -- 击杀
        if is_player then
            battle_achievement_dict[country][attacker_id] = battle_achievement_dict[country][attacker_id] or {score = 0, kill = 0, die = 0, name = attacker_name, actor_id = attacker_id, level = attacker_level}
            local battle_achievement = battle_achievement_dict[country][attacker_id]
            battle_achievement.score = battle_achievement.score + killer_score
            update_rank_list(battle_achievement_list[country], battle_achievement)

            -- 发送系统消息
            output.message_id = const.SYSTEM_MESSAGE_ID.country_war_kill_monster
            output.country_war_score = battle_achievement.score
            output.score_addition = killer_score
            output.actor_id = attacker_id
            center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, output)
        end


        if country_score ~= 0 then
            _update_war_state()
        end
        -- 助攻
        output.message_id = const.SYSTEM_MESSAGE_ID.country_war_assist_kill_monster
        output.score_addition = assist_score
        monster_hatred_list[monster_scene_id][attacker_id] = nil
        for player_id, v in pairs(monster_hatred_list[monster_scene_id]) do
            if current_time - v.last_time <= const.ASSIST_IN_COUNT_SEC then
                battle_achievement_dict[country][player_id] = battle_achievement_dict[country][player_id] or {score = 0, kill = 0, die = 0, name = v.name, actor_id = player_id, level = v.level}
                local assist_achievement = battle_achievement_dict[country][player_id]
                assist_achievement.score = assist_achievement.score + assist_score
                update_rank_list(battle_achievement_list[country], assist_achievement)

                -- 发送系统消息
                output.country_war_score = assist_achievement.score
                output.actor_id = player_id
                center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, output)
            end
        end
        monster_hatred_list[monster_scene_id] = {}
    elseif monster_state.hp <= monster_state.max_hp * 0.3 and monster_state.order == 0 and not monster_state.noticed then
        local country = monster_state.country
        monster_state.noticed = true
        local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.country_boss_is_low_hp, {}, monster_name, fix_string["country_name_"..country])
        broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data, country)
    end
end

local function on_server_start()
    if battle_timer == nil then
        battle_timer = timer.create_timer(battle_timer_callback, BATTLE_TIMER_INTERVAL, const.INFINITY_CALL)
    end
    init_country_monster()

    local past_winner = db_hiredis.get("country_war_winner") or {}
    country_war_winner = past_winner.winner
    battle_achievement_list = db_hiredis.get("battle_achievement_list")
    if battle_achievement_list == nil or battle_achievement_list[1] == nil or battle_achievement_list[1].rank_name == nil or battle_achievement_list[2].rank_name == nil then
        db_hiredis.del("battle_achievement_list")
        battle_achievement_list = {}
        for country = 1, 2 do
            battle_achievement_list[country] = create_rank_list("battle_achievement_list_"..country, "score", MAX_RECORD_NUM_IN_ACHIEVEMENT_LIST, "actor_id")
        end
    end
    db_hiredis.del("country_war_state")
end

local function on_server_stop()
end

local function get_country_war_basic_info()
    local basic_info = {}
    basic_info.country_total_score = country_total_score
    basic_info.battle_record = battle_record
    return basic_info
end

local function kill_player_in_country_war(killer_id, killer_name, hatred_list, country, dead_id, dead_name, killer_level, dead_level)
    if not is_in_battle then
        return
    end

    local country_score, killer_score = get_battle_score("kill", "player")
    local _, assist_score = get_battle_score("assist", "player")

    battle_achievement_dict[country][killer_id] = battle_achievement_dict[country][killer_id] or {score = 0, kill = 0, die = 0, name = killer_name, actor_id = killer_id, level = killer_level}
    local battle_achievement = battle_achievement_dict[country][killer_id]
    battle_achievement.score = battle_achievement.score + killer_score
    battle_achievement.kill = battle_achievement.kill + 1
    update_rank_list(battle_achievement_list[country], battle_achievement)

    -- 发送系统消息
    local output = {func_name = "on_get_country_war_score", monster_name = dead_name}
    output.message_id = const.SYSTEM_MESSAGE_ID.country_war_kill_monster
    output.country_war_score = battle_achievement.score
    output.score_addition = killer_score
    output.actor_id = killer_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, output)

    local dead_country = country % 2 + 1
    battle_achievement_dict[dead_country][dead_id] = battle_achievement_dict[dead_country][dead_id] or {score = 0, kill = 0, die = 0, name = dead_name, actor_id = dead_id, level = dead_level}
    local dead_battle_achievement = battle_achievement_dict[dead_country][dead_id]
    dead_battle_achievement.die = dead_battle_achievement.die + 1

    -- 助攻
    output.message_id = const.SYSTEM_MESSAGE_ID.country_war_assist_kill_monster
    output.score_addition = assist_score
    for assistor_id, info in pairs(hatred_list) do
        battle_achievement_dict[country][assistor_id] = battle_achievement_dict[country][assistor_id] or {score = 0, kill = 0, die = 0, name = info.name, actor_id = assistor_id, level = info.level}
        local assistor_battle_achievement = battle_achievement_dict[country][assistor_id]
        assistor_battle_achievement.score = assistor_battle_achievement.score + assist_score
        update_rank_list(battle_achievement_list[country], assistor_battle_achievement)

        -- 发送系统消息
        output.country_war_score = assistor_battle_achievement.score
        output.actor_id = assistor_id
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, output)
    end
end

local function get_detail_battle_achievement_list()
    local info = {}
    info.country_total_score = country_total_score
    info.winner = country_war_winner
    info.battle_achievement_list = {}
    for country = 1, 2 do
        info.battle_achievement_list[country] = battle_achievement_list[country].rank_data
    end
    local alive_boss_num = _get_country_boss_alive()
    info.alive_boss_num = alive_boss_num
    return 0, info
end

local function get_self_battle_achievement(actor_id, country)
    return battle_achievement_dict[country][actor_id]
end

local function transport_fleet_be_killed(killer_id, killer_name, hatred_list, country, dead_name, is_player, killer_level)
    if not is_in_battle then
        return
    end

    local country_score, killer_score = get_battle_score("kill", "transporter")
    local _, assist_score = get_battle_score("assist", "transporter")

    -- 计算国家得分
    country_total_score[country] = country_total_score[country] + country_score
    _create_fight_record("kill_country_boss_"..country, {killer_name, dead_name, country_score})
    --_update_war_state()

    local output = {func_name = "on_get_country_war_score", monster_name = dead_name}
    if is_player then
        battle_achievement_dict[country][killer_id] = battle_achievement_dict[country][killer_id] or {score = 0, kill = 0, die = 0, name = killer_name, actor_id = killer_id, level = killer_level}
        local battle_achievement = battle_achievement_dict[country][killer_id]
        battle_achievement.score = battle_achievement.score + killer_score
        update_rank_list(battle_achievement_list[country], battle_achievement)

        -- 发送系统消息
        output.message_id = const.SYSTEM_MESSAGE_ID.country_war_kill_monster
        output.country_war_score = battle_achievement.score
        output.score_addition = killer_score
        output.actor_id = killer_id
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, output)
    end

    -- 助攻
    output.message_id = const.SYSTEM_MESSAGE_ID.country_war_assist_kill_monster
    output.score_addition = assist_score
    for assistor_id, info in pairs(hatred_list) do
        battle_achievement_dict[country][assistor_id] = battle_achievement_dict[country][assistor_id] or {score = 0, kill = 0, die = 0, name = info.name, actor_id = assistor_id, level = info.level}
        local assistor_battle_achievement = battle_achievement_dict[country][assistor_id]
        assistor_battle_achievement.score = assistor_battle_achievement.score + assist_score
        update_rank_list(battle_achievement_list[country], assistor_battle_achievement)

        -- 发送系统消息
        output.country_war_score = assistor_battle_achievement.score
        output.actor_id = assistor_id
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, output)
    end
end

local function transport_fleet_get_target(name, country)
    flog("info", "transport_fleet_get_target "..tostring(country))
    local country_score = get_battle_score("supply", "default")

    -- 计算得分
    country_total_score[country] = country_total_score[country] + country_score
    _create_fight_record("fleet_get_target_"..country, {country_score})

    -- 增加boss血量
    for monster_scene_id, monster_state in pairs(country_monster_list) do
        if monster_state.type == const.ENTITY_TYPE_COUNTRY_BOSS or monster_state.type == const.ENTITY_TYPE_COUNTRY_BOSS_LEADER then
            monster_state.hp = monster_state.hp + monster_state.max_hp * 5 / 100
            if monster_state.hp > monster_state.max_hp then
                monster_state.hp = monster_state.max_hp
            end
            monster_state.hp = math.floor(monster_state.hp)
        end
    end

    -- 广播消息
    local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.transport_fleet_get_target, {}, fix_string["country_name_"..country])
    broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data, country)

    --_update_war_state()
end

local function gm_start_country_war(last_time)
    gm_end_war_time = last_time * 60 + _get_now_time_second()
end

local function player_init_data()
    if is_in_battle then
        return {func_name = "SyncCountryWarInfo", country_total_score = country_total_score }
    end
end

local function on_add_hp(monster_scene_id, hp_percent)
    local monster_state = country_monster_list[monster_scene_id]
    if monster_state == nil then
        return const.error_country_monster_not_exist
    end
    if monster_state.hp >= monster_state.max_hp then
        return const.error_country_monster_hp_is_full
    end

    monster_state.hp = monster_state.hp + monster_state.max_hp * hp_percent / 10000
    if monster_state.hp > monster_state.max_hp then
        monster_state.hp = monster_state.max_hp
    end
    monster_state.hp = math.floor(monster_state.hp)
    return 0
end

local function on_add_arrow(monster_scene_id, arrow_num, max_arrow_num)
    local monster_state = country_monster_list[monster_scene_id]
    if monster_state == nil then
        return const.error_country_monster_not_exist
    end
    if monster_state.type ~= const.ENTITY_TYPE_COUNTRY_ARCHER_TOWER then
        return const.error_can_not_add_arrow_for_non_tower
    end

    monster_state.arrow = monster_state.arrow or 0
    if monster_state.arrow >= max_arrow_num then
        return const.error_arrow_number_get_max
    end

    monster_state.arrow = monster_state.arrow + arrow_num
    if monster_state.arrow > max_arrow_num then
        monster_state.arrow = max_arrow_num
    end
    return 0
end


return {
    on_server_start = on_server_start,
    on_server_stop = on_server_stop,
    on_being_attack = on_being_attack,
    get_country_war_basic_info = get_country_war_basic_info,
    kill_player_in_country_war = kill_player_in_country_war,
    get_detail_battle_achievement_list = get_detail_battle_achievement_list,
    get_self_battle_achievement = get_self_battle_achievement,
    transport_fleet_be_killed = transport_fleet_be_killed,
    transport_fleet_get_target = transport_fleet_get_target,
    gm_start_country_war = gm_start_country_war,
    player_init_data = player_init_data,
    on_add_hp = on_add_hp,
    on_add_arrow = on_add_arrow,
}