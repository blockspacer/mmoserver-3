--------------------------------------------------------------------
-- 文件名:	country_election.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/5/25 0025
-- 描  述:	阵营官职选举
--------------------------------------------------------------------
local const = require "Common/constant"
local pvp_country_config = require "configs/pvp_country_config"
local timer = require "basic/timer"
local _get_now_time_second = _get_now_time_second
local qualification_scheme = pvp_country_config.qualification_scheme
local table_insert = table.insert
local data_base = require "basic/db_mongo"
local flog = require "basic/log"
local office_scheme = pvp_country_config.office_scheme
local db_hiredis = require "basic/db_hiredis"
local GLOBAL_DATABASE_TABLE_NAME = "global_info"
local broadcast_message_to_all_game = require("basic/net").broadcast_message_to_all_game
local common_char_chinese_config = require "configs/common_char_chinese_config"
local broadcast_message = require("basic/net").broadcast_message
local create_system_message_by_id = require("basic/scheme").create_system_message_by_id
local mail_helper = require "global_mail/mail_helper"
local is_command_cool_down = require("helper/command_cd").is_command_cool_down

local ELECTION_TIMER_INTERVAL = 45000
local SAVE_DATA_TIMER_INTERVAL = 300000
local SAVE_DATA_TIMER_INTERVAL_RANDOM = 100000
local PLAYER_DATA_FIELD = {actor_id = 1, country_war_score = 1, liveness_history = 1 }
local MAX_KEEP_SALARY_NUM = 3
local TIMER_TRIGGER_CD = 61

local election_timer
local save_data_timer
local is_prepare_close = false
local gm_election_state

local candidate_qualification_table     --候选人资格认证列表
local candidate_list                      --候选人列表
local candidate_number
local current_officer                    --现任官员
local history_officer                    --历任官员
local discount_times                      --已打折次数
local all_skill_cd                      --全体技能的cd
local salary_pool                         --俸禄池
local is_salary_paid                   --俸禄是否已发放
local call_together_position = {}

local function _init_all_election_data()
    candidate_qualification_table = {}      --候选人资格认证列表
    candidate_list = {{}, {}}                     --候选人列表
    candidate_number = {{}, {}}
    current_officer = {{}, {}}                    --现任官员
    history_officer = {{}, {}}                    --历任官员
    discount_times = {{}, {}}                     --已打折次数
    all_skill_cd = {}                           --全体技能cd
    salary_pool = {{}, {}}                         --俸禄池
    is_salary_paid = {false, false}               --俸禄是否已发放
end
_init_all_election_data()

local function _daily_refresh(self)
    is_salary_paid = {false, false}
end

local function _db_callback_update_election_data(caller, status)
    if status == 0 then
        flog("error", "_db_callback_update_election_data: set data fail!")
        return
    end

    if is_prepare_close then
        CountryUserManageReadyClose("country_election")
    end
end

local function write_data_to_database()
    local election_data = {info_name = 'election_data' }
    election_data.candidate_qualification_table = candidate_qualification_table
    election_data.candidate_list = candidate_list
    election_data.candidate_number = candidate_number
    election_data.current_officer = current_officer
    election_data.history_officer = history_officer
    election_data.discount_times = discount_times
    election_data.all_skill_cd = all_skill_cd
    election_data.salary_pool = salary_pool
    election_data.is_salary_paid = is_salary_paid
    data_base.db_update_doc(0, _db_callback_update_election_data, GLOBAL_DATABASE_TABLE_NAME, {info_name = 'election_data'}, election_data, 1, 0)
end

local function _db_callback_election_data(caller, status, doc)
    if status == 0 or doc == nil then
        flog("error", "_db_callback_election_data: get data fail!")
        return
    end

    candidate_qualification_table = doc.candidate_qualification_table or {}      --候选人资格认证列表
    candidate_list = doc.candidate_list or {{}, {}}                     --候选人列表
    candidate_number = doc.candidate_number or {{}, {}}
    current_officer = doc.current_officer or {{}, {}}                    --现任官员
    history_officer = doc.history_officer or {{}, {}}                    --历任官员
    discount_times = doc.discount_times or {{}, {}}                       --已打折次数
    all_skill_cd = doc.all_skill_cd or {}                       --所有技能cd
    salary_pool = doc.salary_pool or {{}, {} }
    is_salary_paid = doc.is_salary_paid or {false, false}

    if save_data_timer == nil then
        -- SAVE_DATA_TIMER_INTERVAL + math.random(SAVE_DATA_TIMER_INTERVAL_RANDOM)
        save_data_timer = timer.create_timer(write_data_to_database, 10000, const.INFINITY_CALL)
    end
end

local function get_data_from_database()
    data_base.db_find_one(0, _db_callback_election_data, GLOBAL_DATABASE_TABLE_NAME, {info_name = 'election_data'}, {})
end

local function init_election_data()
    candidate_qualification_table = {}
    candidate_list = {{}, {}}

    candidate_number = {{}, {}}
    for i, config in ipairs(qualification_scheme) do
        candidate_number[1][config.officeID] = 0
        candidate_number[2][config.officeID] = 0
    end

end

local function _is_qualification_time()
    local current_time = _get_now_time_second()
    if pvp_country_config.is_qualification_time(current_time) then
        local result = is_command_cool_down("system", "election_qualification", TIMER_TRIGGER_CD)
        if result == 0 then
            return true
        end
    end
    return false
end

-- 竞选资格认证
local function _candidate_qualification()
    init_election_data()

    local karma_rank_list = global_get_player_rank_list_data("karma_value")
    local fight_rank_list = global_get_player_rank_list_data("fight_power")
    local liveness_rank_list = global_get_player_rank_list_data("liveness_history")
    local war_score_rank_list = global_get_player_rank_list_data("country_war_score")

    local karma_list_index = {}
    for i, v in pairs(karma_rank_list) do
        karma_list_index[v.key] = i
    end

    local liveness_list_index = {}
    for i, v in pairs(liveness_rank_list) do
        liveness_list_index[v.key] = i
    end

    local war_score_list_index = {}
    for i, v in pairs(war_score_rank_list) do
        war_score_list_index[v.key] = i
    end

    local past_winner = db_hiredis.get("country_war_winner")

    for i, config in ipairs(qualification_scheme) do
        local office_candidate = {}
        candidate_qualification_table[config.officeID] = office_candidate

        local lowest_rank = config.fight
        for j = 1, lowest_rank do
            if fight_rank_list[j] ~= nil then
                local actor_id = fight_rank_list[j].key
                local karma_rank = karma_list_index[actor_id]
                local liveness_rank = liveness_list_index[actor_id]
                local war_score_rank = war_score_list_index[actor_id]

                local is_ok = true
                if config.kindness ~= -1 and (karma_rank == nil or karma_rank > config.kindness) then
                    is_ok = false
                end

                if config.liveness ~= -1 and (liveness_rank == nil or liveness_rank > config.liveness) then
                    is_ok = false
                end

                if past_winner ~= nil and config.exploit ~= -1 and (war_score_rank == nil or war_score_rank > config.exploit) then
                    is_ok = false
                end
                office_candidate[actor_id] = is_ok
            end
        end
    end

    local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.election_nomination_start, {})
    broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data)
end

-- 是否投票时间
local function _is_count_votes_time()
    local current_time = _get_now_time_second()
    if pvp_country_config.is_count_votes_time(current_time) then
        local result = is_command_cool_down("system", "count_votes", TIMER_TRIGGER_CD)
        if result == 0 then
            return true
        end
    end
    return false
end

local function _init_current_officer_info()
    current_officer = {{}, {}}
    discount_times = {{}, {}}
    all_skill_cd = {}
end

local function _count_candidate_votes()
    for country = 1, 2 do
        if not table.isEmptyOrNil(current_officer[country]) or #history_officer[country] > 0 then
            table_insert(history_officer[country], current_officer[country])
        end
    end
    _init_current_officer_info()

    for country = 1, 2 do
        for office_id, _ in ipairs(office_scheme) do
            local office_canditate = {}
            for player_id, candidate_data in pairs(candidate_list[country]) do
                if candidate_data.offices[office_id] then
                    office_canditate[player_id] = candidate_data.vote
                end
            end
            local max_vote_num = -1
            local winner_id
            for i, vote_num in pairs(office_canditate) do
                if vote_num > max_vote_num then
                    winner_id = i
                    max_vote_num = vote_num
                elseif vote_num == max_vote_num then
                    if candidate_list[country][i].order < candidate_list[country][winner_id].order then
                        winner_id = i
                        max_vote_num = vote_num
                    end
                end
            end
            if winner_id ~= nil then
                local candidate_data = candidate_list[country][winner_id]
                current_officer[country][winner_id] = {actor_id = winner_id, actor_name = candidate_data.actor_name, vote = candidate_data.vote, office_id = office_id}
                candidate_list[country][winner_id] = nil

                --发送邮件
                local office_name = office_scheme[office_id].name
                mail_helper.send_mail(winner_id, const.MAIL_IDS.BE_ELECTED_OFFICER, {}, _get_now_time_second(), {office_name})
            end
        end
        init_election_data()
    end
    local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.election_count_end, {})
    broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data)
    global_clear_player_rank_list_data("liveness_rank_list")
end

local function get_current_election_state()
    if gm_election_state ~= nil then
        return gm_election_state
    end

    local state
    local current_time = _get_now_time_second()
    if pvp_country_config.is_nomination_time(current_time) then
        state = "nomination"
    elseif pvp_country_config.is_vote_time(current_time) then
        state = "vote"
    end

    return state
end

local function _is_nomination_end_time()
    local current_time = _get_now_time_second()
    if pvp_country_config.is_nomination_end_time(current_time) then
        local result = is_command_cool_down("system", "nomination_end", TIMER_TRIGGER_CD)
        if result == 0 then
            return true
        end
    end
    return false
end

local function _sort_func(a, b)
    return a.time < b.time
end

local function _serialize_candidate_list()
    local first_order = pvp_country_config.first_order_number
    for country = 1, 2 do
        local order_list = {}
        for i, v in pairs(candidate_list[country]) do
            table.insert(order_list, v)
        end
        table.sort(order_list, _sort_func)
        for i, v in ipairs(order_list) do
            v.order = first_order + i
        end
    end

    local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.election_vote_start, {})
    broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data)
end

local function election_timer_callback()
    if _is_qualification_time() then
        _candidate_qualification()
    end

    if _is_nomination_end_time() then
        _serialize_candidate_list()
    end

    if _is_count_votes_time() then
        _count_candidate_votes()
    end
end

local function on_server_start()
    get_data_from_database()
    if election_timer == nil then
        election_timer = timer.create_timer(election_timer_callback, ELECTION_TIMER_INTERVAL, const.INFINITY_CALL)
    end
end

local function on_server_stop()
    is_prepare_close = true
    write_data_to_database()
end

local function gm_start_qualification_office_candidate()
    _candidate_qualification()
end

local function gm_start_count_votes()
    _count_candidate_votes()
    gm_election_state = nil
end

local function participate_in_election(actor_id, office_id, actor_name, is_cancel, war_rank, country)
    if get_current_election_state() ~= "nomination" then
        return const.error_not_in_nomination_time
    end

    local current_time = _get_now_time_second()
    local candidate_data = candidate_list[country][actor_id] or {time = current_time, offices = {}, vote = 0, actor_name = actor_name, war_rank = war_rank}
    if is_cancel then
        if candidate_data.offices[office_id] == nil then
            return const.error_not_in_candidate_list
        end
        candidate_data.offices[office_id] = nil
        candidate_number[country][office_id] = candidate_number[country][office_id] - 1
    else
        local length = table.getnum(candidate_data.offices)
        if length > 2 then
            return const.error_election_office_too_much
        end
        if candidate_qualification_table[office_id] == nil or not candidate_qualification_table[office_id][actor_id] then
            return const.error_not_match_election_require
        end
        if candidate_data.offices[office_id] ~= nil then
            return const.error_already_in_candidate_list
        end
        candidate_number[country][office_id] = candidate_number[country][office_id] + 1
        candidate_data.offices[office_id] = true
    end
    candidate_list[country][actor_id] = candidate_data
    return 0
end

local function get_salary_value(actor_id, country)
    local salary_detail = salary_pool[country][actor_id] or {}
    local salary = salary_detail.s or {}
    local value = 0
    for _, v in pairs(salary) do
        value = value + v
    end
    return value
end

local function get_election_basic_info(actor_id, country)
    local optional_office = {}
    for i, office_candidate in pairs(candidate_qualification_table) do
        if office_candidate[actor_id] then
            optional_office[i] = true
        end
    end
    local candidate_data = candidate_list[country][actor_id] or {}
    return optional_office, candidate_number[country], candidate_data.offices
end

local function modify_participate_declaration(actor_id, declaration, country)
    local candidate_data = candidate_list[country][actor_id]
    if candidate_data == nil then
        return const.error_not_in_candidate_list
    end
    candidate_data.declaration = declaration
    return 0
end

local function get_candidate_list(country)
    return candidate_list[country]
end

local function vote_for_candidate(candidate_player_id, vote_num, country)
    local current_time = _get_now_time_second()
    if get_current_election_state() ~= "vote" then
        return const.error_not_in_vote_time
    end

    local candidate_data = candidate_list[country][candidate_player_id]
    if candidate_data == nil then
        return const.error_not_in_candidate_list
    end
    candidate_data.vote = candidate_data.vote + vote_num
    return 0
end

local function get_current_officers(country)
    return current_officer[country]
end

local function get_history_officers(index, country)
    local length = #history_officer[country]
    index = index or length
    local officers = {}
    if index > 0 and history_officer[country][index] ~= nil then
        officers = history_officer[country][index]
    end
    return officers, index, length
end

local function give_like_to_history_officer(index, officer_id, country)
    if history_officer[country][index] == nil then
        return const.error_history_officers_index_error
    end
    local officer = history_officer[country][index][officer_id]
    if officer == nil then
        return const.error_history_officer_not_exsit
    end
    officer.like = officer.like or 0
    officer.like = officer.like + 1
    return 0
end

local function country_shop_discount(officer_actor_id, officer_actor_name, country, make_sure)
    local officer = current_officer[country][officer_actor_id]
    if officer == nil then
        return const.error_no_permission_to_operate
    end
    local discount, last_time, times = pvp_country_config.get_officer_discount_info(officer.office_id)
    if discount == nil then
        return const.error_no_permission_to_operate
    end
    local office_id = officer.office_id
    discount_times[country][office_id] = discount_times[country][office_id] or 0
    if discount_times[country][office_id] > times then
        return const.error_discount_times_is_full
    end

    local current_time = _get_now_time_second()
    local skill_name = "shop_discount"
    local key = string.format("%d_%d_%s", country, office_id, skill_name)
    if current_time < all_skill_cd[key] then
        return const.error_command_not_cool_down
    end
    local cd_min = pvp_country_config.get_skill_info(skill_name)
    all_skill_cd[key] = current_time + cd_min * 60

    local country_discount_info = db_hiredis.get("country_discount_info")
    if country_discount_info ~= nil and country_discount_info.office_id ~= nil and current_time < country_discount_info.end_time then
        if not make_sure then
            return const.need_make_sure_cover_discount, country_discount_info
        end

        local old_grade = office_scheme[country_discount_info.office_id].grade
        local self_grade = office_scheme[office_id].grade
        if self_grade > old_grade then
            return const.error_already_in_higher_discount, country_discount_info
        end
    end
    discount_times[country][office_id] = discount_times[country][office_id] + 1
    country_discount_info = {office_id = office_id, end_time = current_time + last_time, actor_name = officer_actor_name, discount = discount }
    db_hiredis.set("country_discount_info", country_discount_info)

    local office_name = office_scheme[office_id].name
    local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.country_shop_discount, {}, office_name, officer_actor_name)
    broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data, country)
    return 0
end

local function get_player_office_id(player_id, country)
    if current_officer[country][player_id] == nil then
        return -1
    end
    return current_officer[country][player_id].office_id
end

local function office_total_skill(actor_id, country, actor_name)
    local office_id = get_player_office_id(actor_id, country)
    local buff_id = pvp_country_config.get_officer_total_skill(office_id)
    if buff_id == nil or buff_id == 0 then
        return const.error_no_permission_to_operate
    end
    local current_time = _get_now_time_second()
    local skill_name = "total_skill"
    local key = string.format("%d_%d_%s", country, office_id, skill_name)
    all_skill_cd[key] = all_skill_cd[key] or 0
    if current_time < all_skill_cd[key] then
        return const.error_command_not_cool_down
    end
    local cd_min = pvp_country_config.get_skill_info(skill_name)
    all_skill_cd[key] = current_time + cd_min * 60
    local output = {country = country, buff_id = buff_id }
    broadcast_message_to_all_game(const.OG_ADD_BUFF_TO_ALL_COUNTRY_PLAYER, output)

    local office_name = office_scheme[office_id].name
    local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.country_total_buff, {}, office_name, actor_name)
    broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data, country)
    return 0
end

local function office_halo_skill(office_id, country)
    local skill_id = pvp_country_config.get_officer_halo_skill(office_id)
    if skill_id == nil or skill_id == 0 then
        return const.error_no_permission_to_operate
    end
    local current_time = _get_now_time_second()
    local skill_name = "halo_skill"
    local key = string.format("%d_%d_%s", country, office_id, skill_name)
    if current_time < all_skill_cd[key] then
        return const.error_command_not_cool_down
    end
    local cd_min = pvp_country_config.get_skill_info(skill_name)
    all_skill_cd[key] = current_time + cd_min * 60
    return 0, skill_id
end

local function pay_salary(player_id, country, country_fund, player_name)
    if is_salary_paid[country] then
        --return const.error_salary_already_paid
    end
    local office_id = get_player_office_id(player_id, country)
    local is_has_right = pvp_country_config.has_right_to_pay_salary(office_id)
    if not is_has_right then
        return const.error_no_permission_to_operate
    end
    local total_salary = 0
    local war_rank_scheme = pvp_country_config.war_rank_scheme
    for i, v in pairs(salary_pool[country]) do
        if v.war_rank ~= nil then
            local salary = war_rank_scheme[v.war_rank].Salary
            total_salary = total_salary + salary
        end
    end

    for i, officer in pairs(current_officer[country]) do
        local office_id = officer.office_id
        local salary = office_scheme[office_id].salary
        total_salary = total_salary + salary
        if salary_pool[country][i] == nil then
            salary_pool[country][i] = {s = {}}
        end
    end

    if country_fund < total_salary then
        return const.error_country_fund_not_enough
    end
    is_salary_paid[country] = true

    for id, v in pairs(salary_pool[country]) do
        local salary = 0
        if v.war_rank ~= nil then        
            salary = war_rank_scheme[v.war_rank].Salary
        end
        if current_officer[country][id] ~= nil then
            local office_id = current_officer[country][id].office_id
            local office_salary = office_scheme[office_id].salary
            salary = salary + office_salary
        end

        v.s = v.s or {}
        local max_index = #v.s + 1
        if max_index > MAX_KEEP_SALARY_NUM then
            max_index = MAX_KEEP_SALARY_NUM
        end
        local new_s = {}
        for j = MAX_KEEP_SALARY_NUM, 2, -1 do
            new_s[j] = v.s[j - 1]
        end
        new_s[1] = salary
        v.s = new_s
    end

    local office_name = office_scheme[office_id].name
    local message_data = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.salary_paid, {}, office_name, player_name)
    broadcast_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, message_data, country)

    return 0, total_salary
end

local function on_war_rank_upgrade(player_id, country, war_rank)
    salary_pool[country][player_id] = salary_pool[country][player_id] or {war_rank = war_rank, s = {}}
end

local function country_player_call_together(player_id, country, player_name)
    local office_id = get_player_office_id(player_id, country)
    local current_time = _get_now_time_second()
    local skill_name = "call_together"
    local key = string.format("%d_%d_%s", country, office_id, skill_name)
    all_skill_cd[key] = all_skill_cd[key] or 0
    if current_time < all_skill_cd[key] then
        return const.error_command_not_cool_down
    end
    local cd_min, cd_price, valid_sec, distence, num = pvp_country_config.get_skill_info(skill_name)
    all_skill_cd[key] = current_time + cd_min * 60

    local position_info = {caller_id = player_id, caller_name = player_name, office_id = office_id, country = country,
        time = current_time + valid_sec, num = num}
    call_together_position[player_id] = position_info
    return 0, position_info
end

local function respond_to_call_together(player_id, country, caller_id, is_pre)
    local position_info = call_together_position[caller_id]
    if country ~= position_info.country then
        return const.error_country_different
    end
    local current_time = _get_now_time_second()
    if current_time > position_info.time then
        return const.error_call_together_out_of_time
    end
    if position_info.num <= 0 then
        return const.error_call_together_number_full
    end
    if not is_pre then
        position_info.num = position_info.num - 1
    end
    return 0, position_info.scene_id, position_info.position
end

local function gm_change_election_state(state)
    gm_election_state = state
    if state == "vote" then
        _serialize_candidate_list()
    end
end

local function gm_clear_election_data()
    _init_all_election_data()
    write_data_to_database()
end

local function get_salary(actor_id, country)
    local salary = get_salary_value(actor_id, country)
    if salary_pool[country][actor_id] ~= nil then
        salary_pool[country][actor_id].s = {}
    end

    if salary > 0 then
        return 0, salary
    else
        return const.error_no_salary_of_this_time
    end
end

local function gm_become_officer(office_id, actor_id, actor_name, country)
    local pre_office_id
    for i, v in pairs(current_officer[country]) do
        if v.office_id == nil then
            pre_office_id = i
        end
    end
    if pre_office_id ~= nil then
        current_officer[country][pre_office_id] = nil
    end

    current_officer[country][actor_id] = {actor_id = actor_id, actor_name = actor_name, vote = 0, office_id = office_id}
end

local function get_office_skill_cd(actor_id, country)
    local office_id = get_player_office_id(actor_id, country)
    local cd_list = {}
    if office_id == nil then
        return cd_list
    end
    local current_time = _get_now_time_second()
    for skill_name, _ in pairs(const.OFFICE_SKILL_NAME_TO_ID) do
        local key = string.format("%d_%d_%s", country, office_id, skill_name)
        all_skill_cd[key] = all_skill_cd[key] or 0
        if current_time < all_skill_cd[key] then
            cd_list[skill_name] = all_skill_cd[key] - current_time
        end
    end
    return cd_list
end

local function get_refresh_skill_cd_money_need(actor_id, country, skill_name)
    local office_id = get_player_office_id(actor_id, country)
    if office_id == nil then
        return const.error_no_permission_to_operate
    end
    local key = string.format("%d_%d_%s", country, office_id, skill_name)
    all_skill_cd[key] = all_skill_cd[key] or 0
    local current_time = _get_now_time_second()

    if current_time >= all_skill_cd[key] then
        return const.error_skill_already_cooled_down
    end
    local last_min = 0
    last_min = all_skill_cd[key] - current_time
    last_min = last_min / 60
    local cd_min, cd_price = pvp_country_config.get_skill_info(skill_name)
    if cd_min <= 0 then
        return const.error_can_not_refresh_this_skill
    end
    local money_need = cd_price * last_min / cd_min
    money_need = math.ceil(money_need)
    return 0, money_need
end


local function refresh_office_skill_cd(actor_id, country, skill_name)
    local office_id = get_player_office_id(actor_id, country)
    if office_id == nil then
        return const.error_no_permission_to_operate
    end
    local key = string.format("%d_%d_%s", country, office_id, skill_name)
    all_skill_cd[key] = nil
    return 0
end

local function gm_clear_skill_cd(actor_id, country)
    local office_id = get_player_office_id(actor_id, country)
    if office_id == nil then
        return
    end
    for skill_name, _ in pairs(const.OFFICE_SKILL_NAME_TO_ID) do
        local key = string.format("%d_%d_%s", country, office_id, skill_name)
        all_skill_cd[key] = nil
    end
end

return {
    on_server_start = on_server_start,
    on_server_stop = on_server_stop,
    gm_start_qualification_office_candidate = gm_start_qualification_office_candidate,
    get_election_basic_info = get_election_basic_info,
    participate_in_election = participate_in_election,
    modify_participate_declaration = modify_participate_declaration,
    get_candidate_list = get_candidate_list,
    vote_for_candidate = vote_for_candidate,
    gm_start_count_votes = gm_start_count_votes,
    get_current_officers = get_current_officers,
    get_history_officers = get_history_officers,
    give_like_to_history_officer = give_like_to_history_officer,
    country_shop_discount = country_shop_discount,
    get_player_office_id = get_player_office_id,
    office_total_skill = office_total_skill,
    office_halo_skill = office_halo_skill,
    get_salary_value = get_salary_value,
    on_war_rank_upgrade = on_war_rank_upgrade,
    pay_salary = pay_salary,
    get_current_election_state = get_current_election_state,
    gm_change_election_state = gm_change_election_state,
    gm_clear_election_data = gm_clear_election_data,
    get_salary = get_salary,
    gm_become_officer = gm_become_officer,
    country_player_call_together = country_player_call_together,
    respond_to_call_together = respond_to_call_together,
    get_office_skill_cd = get_office_skill_cd,
    get_refresh_skill_cd_money_need = get_refresh_skill_cd_money_need,
    refresh_office_skill_cd = refresh_office_skill_cd,
    gm_clear_skill_cd = gm_clear_skill_cd,
}