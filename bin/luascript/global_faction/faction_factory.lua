--------------------------------------------------------------------
-- 文件名:	faction_factory.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/17 0017
-- 描  述:	帮会管理类
--------------------------------------------------------------------
local faction_class = require "global_faction/faction"
local const = require "Common/constant"
local flog = require "basic/log"
local string_match = string.match
local timer = require "basic/timer"
local faction_global_data = require("global_faction/faction_global_data")
local pairs = pairs
local data_base = require "basic/db_mongo"
local math_random = math.random
local get_random_n = require("basic/scheme").get_random_n
local table_insert = table.insert
local db_hiredis = require "basic/db_hiredis"
local common_parameter_formula_config = require "configs/common_parameter_formula_config"
local server_config = require "server_config"
local net_work = require "basic/net"
local send_to_game = net_work.forward_message_to_game
local system_faction_config = require "configs/system_faction_config"

local FACTION_DATABASE_TABLE_NAME = "faction_info"
local MAX_FACTION_NUM_IN_PAGE = 20
local SAVE_TIMER_INTERVAL = 300000
local RANDOM_INTERVAL = 30000
local SORT_TIMER_INTERVAL = 300000
local FACTION_VALUE_LIST = const.FACTION_VALUE_LIST
local day_second = 86400


local sort_timer
local faction_list = {}
local faction_ranking = faction_global_data.get_faction_ranking()
local faction_rank_data_cache = {}
local faction_id_to_index = {}

local is_prepare_close = false
local close_hash = {}

--完成数据读取，等待创建帮会领地的帮派
local pre_create_scene_factions = {}
--正在创建的帮会领地
local creating_scene_factions = {}
--可以创建帮会领地的进程
local faction_scene_games = {}
local line_scene_type = const.LINE_SCENE_TYPE
local faction_scene_game_init = false
local _games_info = nil
local maintain_timer = nil

local function is_ready_to_close(faction_id)
    if is_prepare_close then
        if faction_id ~= nil then
            close_hash[faction_id] = nil
        end

        if table.isEmptyOrNil(close_hash) then
            flog("info", "faction_global_data.on_server_stop")
            faction_global_data.on_server_stop()
        end
    end
end

local function _db_callback_update_faction_data(caller, status)
    if status == 0 then
        flog("error", "faction_factory.lua _db_callback_update_faction_data: set data fail!")
        return
    end

    is_ready_to_close(caller.faction_id)
end

local function _save_faction_data(faction, no_global)
    local faction_data = {}
    faction:recalc_faction_info()
    faction:write_to_dict(faction_data)
    data_base.db_update_doc(faction, _db_callback_update_faction_data, FACTION_DATABASE_TABLE_NAME, {faction_id = faction.faction_id}, faction_data, 1, 0)
    if no_global then
        return
    end
    faction_global_data.save_global_data()
end

local function _create_faction_save_timer(faction)
    local function save_tick()
        _save_faction_data(faction)
    end
    local random_second = math_random(RANDOM_INTERVAL)
    faction.save_data_timer = timer.create_timer(save_tick, SAVE_TIMER_INTERVAL + random_second, const.INFINITY_CALL)
end

local function create_faction_scene(faction_id)
    flog("tmlDebug","faction_factory|create_faction_scene")
    if #faction_scene_games == 0 then
        return
    end
    if faction_list[faction_id] == nil then
        return
    end
    if faction_list[faction_id].scene_gameid > 0 then
        flog("tmlDebug","this faction already have scene!!!")
        return
    end
    local target_game = faction_scene_games[math.random(#faction_scene_games)].gameid
    creating_scene_factions[faction_id] = {}
    creating_scene_factions[faction_id].create_time = _get_now_time_second()
    creating_scene_factions[faction_id].gameid = target_game
    pre_create_scene_factions[faction_id] = nil
    send_to_game(target_game,const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_create_faction_scene",faction_id=faction_id,country=faction_list[faction_id].country})
end

local function create_faction(creater, faction_name, declaration, visual_id)
    if create_faction == nil then
        return const.error_faction_name_illegal
    end

    local new_faction = faction_class()
    local rst = new_faction:create_new_faction(creater, faction_name, declaration, visual_id)
    if rst ~= 0 then
        return rst
    end

    local faction_id = new_faction.faction_id
    faction_list[faction_id] = new_faction
    _save_faction_data(new_faction)
    _create_faction_save_timer(new_faction)
    local country = creater.country
    flog("syzDebug", "create_faction country "..country)
    table_insert(faction_ranking[country], faction_id)
    create_faction_scene(faction_id)
    local faction_info = new_faction:get_basic_faction_info()
    return 0, faction_info
end

local function dissolve_faction(faction_id, operater_id, is_force)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    local country = faction.country
    local rst, members = faction:dissolve_faction(operater_id, is_force)
    if rst ~= 0 then
        return rst
    end
    faction:remove_faction_from_rank_list()
    for key, _ in pairs(FACTION_VALUE_LIST) do
        local rank_set_name = "faction_rank_set_"..key
        local redis_data = faction_rank_data_cache[rank_set_name] or {}

        local index
        for i, v in pairs(redis_data) do
            if v.key == faction_id then
                index = i
                break
            end
        end
        if index ~= nil then
            table.remove(redis_data, index)
        end
    end

    faction_list[faction_id] = nil
    local index
    for i, fid in pairs(faction_ranking[country]) do
        if fid == faction_id then
            index = i
            break
        end
    end
    if index ~= nil then
        table.remove(faction_ranking[country], index)
    end
    return 0, members
end

local function apply_join_faction(faction_id, player)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    if faction.country ~= player.country then
        return const.error_country_different
    end
    return faction:add_to_apply_list(player)
end

local function reply_apply_join_faction(faction_id, operater_id, player_id, is_agree)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:reply_apply_join_faction(operater_id, is_agree, player_id)
end

local function one_key_reply_all(faction_id, operater_id, is_agree)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:one_key_reply_all(operater_id, is_agree)
end

local function kick_faction_member(faction_id, operater_id, member_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:kick_faction_member(operater_id, member_id)
end

local function invite_faction_member(faction_id, operater_id, new_member)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:invite_faction_member(operater_id, new_member)
end

local function reply_faction_invite(faction_id, player_id, is_agree)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:reply_faction_invite(player_id, is_agree)
end


local function member_leave_faction(faction_id, member_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:member_leave_faction(member_id)
end

local function get_faction_apply_list(faction_id, operater_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end
    return faction:get_faction_apply_list(operater_id)
end

local function set_declaration(faction_id, new_declaration, operater_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:set_declaration(new_declaration, operater_id)
end

local function set_enemy_faction(faction_id, enemy_faction_id, operater_id)
    if faction_id == enemy_faction_id then
        return const.error_can_not_set_self_faction_as_enemy
    end

    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    local enemy_facation = faction_list[enemy_faction_id]
    if enemy_facation == nil then
        return const.error_faction_not_exist
    end

    return faction:set_enemy_faction(enemy_faction_id, operater_id, enemy_facation.faction_name)
end

local function get_faction_members_info(faction_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return 0, faction:get_faction_members_info()
end

local function faction_player_login(old_faction_id, player_id, self_info)
    faction_class.faction_player_login(player_id)

    local faction_id = faction_class.get_player_faction_id(player_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        faction_id = 0
    else
        faction:update_member_info(self_info)
    end
    if faction_id ~= old_faction_id then
        return true, faction_id
    end
    return false
end


local function faction_player_logout(faction_id, player_id)
    faction_class.faction_player_logout(player_id)
end

local function change_position(faction_id, operater_id, member_id, position)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:change_position(operater_id, member_id, position)
end


local function get_faction_list(start_index, end_index, country)
    if start_index == nil or end_index == nil or end_index < start_index or start_index < 1 then
        return const.error_impossible_param
    end
    if end_index - start_index > MAX_FACTION_NUM_IN_PAGE then
        end_index = start_index + MAX_FACTION_NUM_IN_PAGE
    end

    local ranking_list = faction_ranking[country]
    local total_length = #ranking_list
    if end_index > total_length then
        end_index = total_length
    end

    local info_list = {}
    for index = start_index, end_index do
        if index < 1 then
            break
        end

        local faction_id = ranking_list[index]
        local faction = faction_list[faction_id]
        if faction == nil then
            faction_id = faction_id or "nil"
            flog("error", "get_faction_list error faction_id "..faction_id)
        end
        table_insert(info_list, faction:get_brief_faction_info())
    end

    return 0, info_list
end

local function get_random_faction_list(list_length, country)
    list_length = list_length or MAX_FACTION_NUM_IN_PAGE

    local ranking_list = faction_ranking[country]
    local total_length = #ranking_list

    local random_list = get_random_n(list_length, total_length)

    local info_list = {}
    for _, index in pairs(random_list) do
        local faction_id = ranking_list[index]
        local faction = faction_list[faction_id]
        if faction == nil then
            faction_id = faction_id or "nil"
            flog("error", "get_faction_list error faction_id "..faction_id)
        end
        table_insert(info_list, faction:get_brief_faction_info())
    end

    return 0, info_list
end


local function search_faction(search_str, country)
    local ranking_list = faction_ranking[country]
    local search_id = tonumber(search_str)
    local info_list = {}
    if search_id ~= nil then
        for idx, faction_id in pairs(ranking_list) do
            local faction = faction_list[faction_id]
            if faction == nil then
                faction_id = faction_id or "nil"
                flog("error", "search_faction_by_id_or_name error faction_id "..faction_id)
                return
            end
            if faction.visual_id == search_id then
                table_insert(info_list, faction:get_brief_faction_info())
                break
            end
        end
    end
    if not table.isEmptyOrNil(info_list) then
        return 0, info_list
    end

    for idx, faction_id in pairs(ranking_list) do
        local faction = faction_list[faction_id]
        if faction == nil then
            faction_id = faction_id or "nil"
            flog("error", "search_faction_by_id_or_name error faction_id "..faction_id)
            return
        end
        if string_match(faction.faction_name, search_str) then
            table_insert(info_list, faction:get_brief_faction_info())
        end
    end
    return 0, info_list
end

local function sort_func(id_a, id_b)
    local faction_a = faction_list[id_a]
    local faction_b = faction_list[id_b]

    if faction_a.on_top > faction_b.on_top then
        return true
    elseif faction_a.on_top < faction_b.on_top then
        return false
    else
        return faction_a.activity > faction_b.activity
    end
end

local function _sort_faction_index(country)
    for _, faction in pairs(faction_list) do
        faction:check_on_top_time()
    end

    if country == nil then
        table.sort(faction_ranking[1], sort_func)
        table.sort(faction_ranking[2], sort_func)
    else
        table.sort(faction_ranking[country], sort_func)
    end
end

local function _get_faction_rank_data_cache()
    for key, _ in pairs(FACTION_VALUE_LIST) do
        local rank_set_name = "faction_rank_set_"..key
        --db_hiredis.clear_set(rank_set_name)
        faction_rank_data_cache[rank_set_name] = db_hiredis.zrevrange(rank_set_name, 0, common_parameter_formula_config.RANK_LIST_NUMBER, true)
        faction_id_to_index[rank_set_name] = {}
        for i, data in ipairs(faction_rank_data_cache[rank_set_name]) do
            faction_id_to_index[rank_set_name][data.key] = i
        end
    end
end

local function buy_faction_on_top(faction_id, country)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end
    local expire_time = faction:buy_faction_on_top()
    _sort_faction_index(country)
    return expire_time
end

local function get_basic_faction_info(faction_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    local faction_info = faction:get_basic_faction_info()
    return 0, faction_info
end


local function sort_timer_callback()
    _sort_faction_index()
    _get_faction_rank_data_cache()
end

local function _on_finish_get_faction_data()
    flog("info", "_finish_get_global_data_callback")
    if sort_timer == nil then
        sort_timer = timer.create_timer(sort_timer_callback, SORT_TIMER_INTERVAL, const.INFINITY_CALL)
    end
end

local function _is_all_faction_data_initalized()
    for country = 1, 2 do
        local ranking_list = faction_ranking[country]
        for _, faction_id in pairs(ranking_list) do
            if faction_list[faction_id] == nil then
                return false
            end
        end
    end
    return true
end

local function _db_callback_get_faction_data(faction_id, status, doc)
    if status == 0 then
        flog("error", "_db_callback_get_faction_data: get data fail!")
        return
    end

    doc = doc or {}
    local faction = faction_class()
    faction:init_from_dict(doc)
    faction_list[faction_id] = faction

    _create_faction_save_timer(faction)
    if faction_scene_game_init then
        create_faction_scene(faction_id)
    else
        pre_create_scene_factions[faction_id]=1
    end
    if _is_all_faction_data_initalized() then
        _on_finish_get_faction_data()
    end
end

local function _finish_get_global_data_callback()
    flog("info", "_finish_get_global_data_callback")
    faction_ranking = faction_global_data.get_faction_ranking()
    faction_class.on_inital_global_data()

    for country = 1, 2 do
        local ranking_list = faction_ranking[country]
        for _, faction_id in pairs(ranking_list) do
            data_base.db_find_one(faction_id, _db_callback_get_faction_data, FACTION_DATABASE_TABLE_NAME, {faction_id = faction_id}, {})
        end
    end
end

local function add_faction_fund(faction_id, count)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:add_faction_fund(count)
end

local function change_faction_name(faction_id, operater_id, new_faction_name)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:change_faction_name(operater_id, new_faction_name)
end

local function get_faction_rank_list(faction_id, key, start_index, end_index)
    local rank_set_name = "faction_rank_set_"..key
    local redis_data = faction_rank_data_cache[rank_set_name] or {}
    if start_index == nil or end_index == nil or end_index < start_index or start_index < 1 then
        return const.error_impossible_param
    end
    local list_length = #redis_data
    if end_index > list_length then
        end_index = list_length
    end
    if start_index > end_index then
        start_index = end_index
    end

    local rank_list = {}
    for i = start_index, end_index do
        if i < 1 then
            break
        end
        local v = redis_data[i]
        local faction = faction_list[v.key]
        if faction ~= nil then
            local data = faction:get_brief_faction_info()
            data[key] = v.value
            rank_list[i] = data
        end
    end

    local self_data = {}
    local faction = faction_list[faction_id]
    if faction ~= nil then
        self_data = faction:get_brief_faction_info()
        self_data.self_index = faction_id_to_index[rank_set_name][faction_id]
    end

    return 0, rank_list, self_data
end

local function _update_games_info(games_info)
    flog("tmlDebug","faction_factory|_update_games_info")
    for i=1,#faction_scene_games,1 do
        local start = false
        for j=1,#games_info,1 do
            if faction_scene_games[i].gameid == games_info[j].gameid then
                start = true
                break
            end
        end
        if not start then
            return
        end
    end
    faction_scene_game_init = true
    for id,pre_create_scene_factions in pairs(pre_create_scene_factions) do
        create_faction_scene(id)
        pre_create_scene_factions[id] = nil
    end
end

local function _maintain_handle()
    for _,faction in pairs(faction_list) do
        faction:maintain_handle()
    end
end

local function maintain_handle()
    _maintain_handle()
end

local function first_maintain_handle()
    if maintain_timer ~= nil then
        timer.destroy_timer(maintain_timer)
    end
    _maintain_handle()
    maintain_timer = timer.create_timer(maintain_handle,day_second*1000,const.INFINITY_CALL)
end

local function on_server_start()
    flog("tmlDebug","faction_factory|on_server_start")
    local server_config = server_config.get_server_config()
    if server_config.game == nil then
        _error("can not find game config!!!")
        assert(false)
        return
    end
    for _,server in pairs(server_config.game) do
        if server.line_scene_type == nil then
            _error("server config is error!line_scene_type == nil")
            assert(false)
        end
        if server.line_scene_type == line_scene_type.faction then
            table.insert(faction_scene_games,{gameid=server.id})
        end
    end
    --如果没有独立的帮派场景进程，使用野外场景进程
    if #faction_scene_games == 0 then
        for _,server in pairs(server_config.game) do
            if server.line_scene_type == line_scene_type.start then
                table.insert(faction_scene_games,{gameid=server.id})
            end
        end
    end
    flog("tmlDebug","faction_factory|on_server_start faction_scene_games "..table.serialize(faction_scene_games))
    if _games_info ~= nil and #faction_scene_games > 0 and not faction_scene_game_init then
        _update_games_info(_games_info)
    end

    faction_global_data.on_server_start(_finish_get_global_data_callback)
    _get_faction_rank_data_cache()

    local time_now = _get_now_time_second()
    local current_date = os.date("*t", time_now)
    local refresh_date = current_date
    refresh_date.hour = system_faction_config.get_maintain_hour()
    refresh_date.min = 0
    refresh_date.sec = 0
    local refresh_time = os.time(refresh_date)
    local delay_time = 0
    if time_now > refresh_time then
        delay_time = refresh_time + day_second - time_now
    else
        delay_time = refresh_time - time_now
    end
    maintain_timer = timer.create_timer(first_maintain_handle,delay_time*1000,0)
end

local function on_server_stop()
    is_prepare_close = true
    for faction_id, faction in pairs(faction_list) do
        close_hash[faction_id] = true
        local no_global = true
        _save_faction_data(faction, true)
    end
    is_ready_to_close()
end

local function get_faction_members(faction_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return nil
    end
    return faction:get_members()
end

local function transfer_chief(faction_id, operater_id, member_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_faction_not_exist
    end

    return faction:transfer_chief(operater_id, member_id)
end

local function on_update_games_info(games_info)
    flog("tmlDebug","faction_factory|on_update_games_info")
    if #faction_scene_games == 0 then
        _games_info = games_info
        return
    end
    --如果没有进行过初始化，则等待所有帮派领地进程开启后创建
    if not faction_scene_game_init then
        _update_games_info(games_info)
    else
        --如果需要的话，开启或者关闭某个帮派领地进程时处理
    end
end

local function on_create_faction_scene_ret(input)
    flog("tmlDebug","faction_factory|on_create_faction_scene_ret "..input.faction_id)
    if input.result ~= 0 then
        creating_scene_factions[input.faction_id] = nil
        flog("warn","can not create faction scene,faction id "..input.faction_id)
        return
    end
    if faction_list[input.faction_id] == nil then
        return
    end
    faction_list[input.faction_id].scene_gameid = creating_scene_factions[input.faction_id].gameid
    creating_scene_factions[input.faction_id] = nil

end

local function get_faction_scene_gameid(faction_id)
    flog("tmlDebug","faction_factory|get_faction_scene_gameid")
    if faction_list[faction_id] == nil then
        flog("tmlDebug","faction_factory|get_faction_scene_gameid no faction!faction_id "..faction_id)
        return nil
    end
    return faction_list[faction_id].scene_gameid
end

local function on_query_faction_building(faction_id,building_id,actor_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_have_not_faction
    end
    return faction:on_query_faction_building(building_id,actor_id)
end

local function on_investment_faction_building(faction_id,building_id,actor_id,investment_type,investment_count,actor_name)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_have_not_faction
    end
    return faction:on_investment_faction_building(building_id,actor_id,investment_type,investment_count,actor_name)
end

local function on_upgrade_faction_building(faction_id,building_id,actor_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return const.error_have_not_faction
    end
    return faction:on_upgrade_faction_building(building_id,actor_id)
end

local function on_faction_player_init(faction_id,actor_id)
    local faction = faction_list[faction_id]
    if faction == nil then
        return
    end
    return faction:on_faction_player_init(faction_id,actor_id)
end

return {
    create_faction = create_faction,
    dissolve_faction = dissolve_faction,
    apply_join_faction = apply_join_faction,
    reply_apply_join_faction = reply_apply_join_faction,
    one_key_reply_all = one_key_reply_all,
    kick_faction_member = kick_faction_member,
    invite_faction_member = invite_faction_member,
    reply_faction_invite = reply_faction_invite,
    member_leave_faction = member_leave_faction,
    get_faction_apply_list = get_faction_apply_list,
    set_declaration = set_declaration,
    set_enemy_faction = set_enemy_faction,
    get_faction_members_info = get_faction_members_info,
    faction_player_login = faction_player_login,
    faction_player_logout = faction_player_logout,
    change_position = change_position,
    get_faction_list = get_faction_list,
    search_faction = search_faction,
    buy_faction_on_top = buy_faction_on_top,
    get_basic_faction_info = get_basic_faction_info,
    get_random_faction_list = get_random_faction_list,
    add_faction_fund = add_faction_fund,
    change_faction_name = change_faction_name,
    get_faction_rank_list = get_faction_rank_list,
    on_server_start = on_server_start,
    on_server_stop = on_server_stop,
    get_faction_members = get_faction_members,
    transfer_chief = transfer_chief,
    on_update_games_info = on_update_games_info,
    on_create_faction_scene_ret = on_create_faction_scene_ret,
    get_faction_scene_gameid = get_faction_scene_gameid,
    on_query_faction_building = on_query_faction_building,
    on_investment_faction_building = on_investment_faction_building,
    on_upgrade_faction_building = on_upgrade_faction_building,
    on_faction_player_init = on_faction_player_init,
}