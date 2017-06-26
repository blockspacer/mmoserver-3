--------------------------------------------------------------------
-- 文件名:	country_donation.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/9 0009
-- 描  述:	国家捐献排行榜
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local scheme_noble_rank = require("data/pvp_country").NobleRank
local data_base = require "basic/db_mongo"
local timer = require "basic/timer"
local noble_rank_border_index = {}
local MAX_NUM_ON_DONATION_LIST = 0
local DATABASE_RANK_NAME = "rank_info_2"

for _, v in ipairs(scheme_noble_rank) do
    if v.Ranking ~= -1 then
        noble_rank_border_index[v.Ranking] = v.Donate
        MAX_NUM_ON_DONATION_LIST = v.Ranking
    end
end

local scheme_weekly_rank = require("data/pvp_country").NobleRank2
local weekly_rank_border_index = {}
local MAX_NUM_ON_WEEKLY_DONATION_LIST = 0
for _, v in ipairs(scheme_weekly_rank) do
    if v.Ranking ~= -1 then
        weekly_rank_border_index[v.Ranking] = true
        MAX_NUM_ON_WEEKLY_DONATION_LIST = v.Ranking
    end
end

local scheme_basic = require "basic/scheme"
local WEEKLY_REFRESH_DAY = require("data/pvp_country").Parameter[9].Value        --周榜刷新日
WEEKLY_REFRESH_DAY = math.floor(tonumber(WEEKLY_REFRESH_DAY))
local WEEKLY_REFRESH_HOUR,WEEKLY_REFRESH_MIN = scheme_basic.get_time_from_string(require("data/pvp_country").Parameter[10].Value)  --每周刷新时间


local NUMBER_IN_ONE_PAGE = 60
local MAX_COUNTRY = 2               --最大国家数

local total_rank_list = {{}, {} }
local weekly_rank_list = {{}, {}}
local total_id_index={{}, {} }
local weekly_id_index = {{},{}}
local country_fund = {0, 0 }
local declaration = {}
local table = table
local math = math
local weekly_refresher = require("helper/weekly_refresher")
local donation_weekly_refresher
local weekly_refresh_timer

local is_prepare_close = false
local function _db_callback_update_rank_list(caller, status)
    if status == 0 then
        flog("error", "_db_callback_update_rank_list: set data fail!")
        return
    end

    if is_prepare_close then
        CountryUserManageReadyClose("country_donation")
    end
end

local function write_to_database()
    local donation_data = {rank_name = 'donation_rank' }
    donation_data.total_rank_list = total_rank_list
    donation_data.id_index = total_id_index
    donation_data.country_fund = country_fund
    donation_data.declaration = declaration
    donation_data.weekly_rank_list = weekly_rank_list
    donation_data.weekly_id_index = weekly_id_index
    donation_data.weekly_last_refresh_time = donation_weekly_refresher:get_last_refresh_time()
    data_base.db_update_doc(0, _db_callback_update_rank_list, DATABASE_RANK_NAME, {rank_name = 'donation_rank'}, donation_data, 1, 0)
end

local function _weekly_refresh()
    weekly_rank_list = {{}, {}}
    weekly_id_index = {{},{}}
    write_to_database()
end

local function weekly_refresh_timer_callback()
    if donation_weekly_refresher ~= nil then
        donation_weekly_refresher:check_refresh()
    end
end

local function _db_callback_get_rank_list(caller, status, doc)
    if status == 0 or doc == nil then
        flog("error", "_db_callback_get_rank_list: get data fail!")
        return
    end

    total_rank_list = table.copy(doc.total_rank_list) or {}
    total_id_index = table.copy(doc.id_index) or {}
    country_fund = table.copy(doc.country_fund) or {}
    declaration = table.copy(doc.declaration) or {}
    weekly_rank_list = table.copy(doc.weekly_rank_list) or {}
    weekly_id_index = table.copy(doc.weekly_id_index) or {}

    for i = 1, MAX_COUNTRY do
        total_rank_list[i] = total_rank_list[i] or {}
        total_id_index[i] = total_id_index[i] or {}
        country_fund[i] = country_fund[i] or 0
        weekly_rank_list[i] = weekly_rank_list[i] or {}
        declaration[i] = declaration[i] or ""
        weekly_id_index[i] = weekly_id_index[i] or {}
    end

    local weekly_last_refresh_time = doc.weekly_last_refresh_time or _get_now_time_second()
    donation_weekly_refresher = weekly_refresher(_weekly_refresh, weekly_last_refresh_time, WEEKLY_REFRESH_DAY, WEEKLY_REFRESH_HOUR, WEEKLY_REFRESH_MIN)
    donation_weekly_refresher:check_refresh()

    if weekly_refresh_timer == nil then
        weekly_refresh_timer = timer.create_timer(weekly_refresh_timer_callback, 30000, const.INFINITY_CALL)
    end
end

local function get_data_from_database()
    data_base.db_find_one(0, _db_callback_get_rank_list, DATABASE_RANK_NAME, {rank_name = 'donation_rank'}, {})
end

local function _get_noble_rank(donation, donation_rank)
    for i, v in ipairs(scheme_noble_rank) do
        local need_rank = v.Ranking
        if need_rank == -1 then
            need_rank = math.huge
        end
        local need_donation = v.Donate
        if need_donation == -1 then
            need_donation = math.huge
        end

        if donation_rank ~= -1 then
            if donation >= need_donation or donation_rank <= need_rank then
                return i
            end
        else
            if donation >= need_donation then
                return i
            end
        end
    end
    flog("error", "_get_noble_rank: impossible here!")
end


local function _get_weekly_noble_rank(donation_rank)
    if donation_rank == -1 or donation_rank == nil then
       donation_rank = math.huge
    end
    
    for i, v in ipairs(scheme_weekly_rank) do
        local need_rank = v.Ranking
        if need_rank == -1 then
            need_rank = math.huge
        end
        if donation_rank <= need_rank then
            return i
        end
    end
    flog("error", "_get_weekly_noble_rank: impossible here!")
end

local function _get_next_level_need(rank_list, noble_rank, scheme, key, current_donation)
    if noble_rank == 1 then
        return 0
    end
    local next_noble_rank = noble_rank - 1
    local scheme_data = scheme[next_noble_rank]
    local fix_need = math.huge
    local rank_need = math.huge

    if scheme_data.Donate ~= nil and scheme_data.Donate ~= -1 then
        fix_need = scheme_data.Donate - current_donation
    end
    if scheme_data.Ranking ~= -1 then
        if rank_list[scheme_data.Ranking] ~= nil then
            rank_need = rank_list[scheme_data.Ranking][key] - current_donation
        else
            rank_need = 0
        end
    end

    local least_need
    if fix_need < rank_need then
        least_need = fix_need
    else
        least_need = rank_need
    end

    if least_need == math.huge then
        flog("error", "_get_next_level_need: least_need calc error.")
    end
    return least_need
end


local function _update_total_list(rank_list, id_index, actor_id, new_donation, actor_name)
    local list_len = #rank_list
    if list_len > MAX_NUM_ON_DONATION_LIST then
        flog("error", "_update_total_list: list lenght > MAX_NUM_ON_DONATION_LIST")
    end

    local affected_guy = {}
    local old_rank
    local is_list_changed = true
    if id_index[actor_id] ~= nil then       --已在榜上
        old_rank = id_index[actor_id]
    elseif list_len < MAX_NUM_ON_DONATION_LIST then               --榜单未满
        old_rank = list_len + 1
        table.insert(rank_list, {donation = new_donation, actor_id = actor_id, actor_name = actor_name})
        id_index[actor_id] = old_rank
    elseif new_donation > rank_list[MAX_NUM_ON_DONATION_LIST].donation then                  --进入排行榜
        old_rank = MAX_NUM_ON_DONATION_LIST
        local last_guy = rank_list[old_rank]
        id_index[last_guy.actor_id] = nil
        id_index[actor_id] = old_rank
        rank_list[old_rank] = {donation = new_donation, actor_id = actor_id , actor_name = actor_name}
        if last_guy.donation < noble_rank_border_index[old_rank] then
            last_guy.noble_rank = last_guy.noble_rank + 1
            table.insert(affected_guy, {actor_id = last_guy.actor_id, new_rank = -1, new_noble_rank = last_guy.noble_rank})
        end
    else
        is_list_changed = false
    end

    if is_list_changed then
        for i = old_rank - 1, 1, -1 do
            if rank_list[i].donation < new_donation then
                local guy = rank_list[i]
                local guy_new_rank = i + 1
                id_index[actor_id] = i
                id_index[guy.actor_id] = guy_new_rank
                rank_list[i] = rank_list[guy_new_rank]
                rank_list[guy_new_rank] = guy
                local need_donation = noble_rank_border_index[i]
                if need_donation == -1 then
                    need_donation = math.huge
                end
                if need_donation ~= nil and guy.donation < need_donation then
                    guy.noble_rank = guy.noble_rank + 1
                    table.insert(affected_guy, {actor_id = guy.actor_id, new_rank = guy_new_rank, new_noble_rank = guy.noble_rank})
                end
            else
                break
            end
        end
    end

    local new_donation_rank = id_index[actor_id] or -1
    local new_noble_rank = _get_noble_rank(new_donation, new_donation_rank)
    rank_list[new_donation_rank].noble_rank = new_noble_rank
    rank_list[new_donation_rank].actor_name = actor_name
    rank_list[new_donation_rank].donation = new_donation

    local info_in_total = table.copy(rank_list[new_donation_rank])
    info_in_total.donation_rank = new_donation_rank
    return is_list_changed, affected_guy, info_in_total
end

local function _update_weekly_list(rank_list,id_index, actor_id, new_donation, actor_name, noble_rank)
    local list_len = #rank_list
    if list_len > MAX_NUM_ON_WEEKLY_DONATION_LIST then
        flog("error", "_update_weekly_list: list lenght > MAX_NUM_ON_DONATION_LIST")
    end

    local affected_guy = {}
    local old_rank
    local is_list_changed = true
    if id_index[actor_id] ~= nil then       --已在榜上
        old_rank = id_index[actor_id]
    elseif list_len < MAX_NUM_ON_WEEKLY_DONATION_LIST then               --榜单未满
        old_rank = list_len + 1
        table.insert(rank_list, {weekly_donation = new_donation, actor_id = actor_id, actor_name = actor_name})
        id_index[actor_id] = old_rank
    elseif new_donation > rank_list[MAX_NUM_ON_WEEKLY_DONATION_LIST].weekly_donation then                  --进入排行榜
        old_rank = MAX_NUM_ON_WEEKLY_DONATION_LIST
        local last_guy = rank_list[old_rank]
        id_index[last_guy.actor_id] = nil
        id_index[actor_id] = old_rank
        rank_list[old_rank] = {weekly_donation = new_donation, actor_id = actor_id , actor_name = actor_name}

        last_guy.weekly_noble_rank = last_guy.weekly_noble_rank + 1
        table.insert(affected_guy, {actor_id = last_guy.actor_id, new_weekly_rank = -1, new_weekly_noble_rank = last_guy.noble_rank})
    else
        is_list_changed = false
    end

    if is_list_changed then
        for i = old_rank - 1, 1, -1 do
            if rank_list[i].weekly_donation < new_donation then
                local guy = rank_list[i]
                local guy_new_rank = i + 1
                id_index[actor_id] = i
                id_index[guy.actor_id] = guy_new_rank
                rank_list[i] = rank_list[guy_new_rank]
                rank_list[guy_new_rank] = guy
                local is_border = weekly_rank_border_index[i]
                if is_border then
                    guy.weekly_noble_rank = guy.weekly_noble_rank + 1
                    table.insert(affected_guy, {actor_id = guy.actor_id, new_weekly_rank = guy_new_rank, new_weekly_noble_rank = guy.weekly_noble_rank})
                end
            else
                break
            end
        end
    end

    local new_donation_rank = id_index[actor_id]
    local new_noble_rank = _get_weekly_noble_rank(new_donation_rank)
    rank_list[new_donation_rank].weekly_noble_rank = new_noble_rank
    rank_list[new_donation_rank].actor_name = actor_name
    rank_list[new_donation_rank].weekly_donation = new_donation
    rank_list[new_donation_rank].noble_rank = noble_rank

    local info_in_weekly = table.copy(rank_list[new_donation_rank])
    info_in_weekly.weekly_donation_rank = new_donation_rank

    return is_list_changed, affected_guy, info_in_weekly
end


local function country_player_donation(actor_id, country, new_donation, fund_addtion, actor_name, new_weekly_donation)
    country_fund[country] = country_fund[country] + fund_addtion

    local rank_list = total_rank_list[country]
    local id_index = total_id_index[country]
    local is_list_changed, affected_guy, info_in_total = _update_total_list(rank_list,id_index, actor_id, new_donation, actor_name)

    local weekly_list = weekly_rank_list[country]
    local weekly_id = weekly_id_index[country]
    local is_weekly_list_changed, weekly_affected_guy, info_in_weekly = _update_weekly_list(weekly_list,weekly_id, actor_id, new_weekly_donation, actor_name, info_in_total.noble_rank)
    for _, v in pairs(affected_guy) do
        local weekly_rank = weekly_id[v.actor_id]
        if weekly_rank ~= nil then
            weekly_list[weekly_rank].noble_rank = v.new_noble_rank
        end
    end

    if is_list_changed or is_weekly_list_changed then
        write_to_database()
    end
    return info_in_total, info_in_weekly, affected_guy, weekly_affected_guy, country_fund[country]
end

local function reget_noble_rank(country, actor_id, donation)
    local rank_list = total_rank_list[country]
    local id_index = total_id_index[country]
    local key = "noble_rank"
    local noble_rank = #scheme_noble_rank

    local donation_rank = id_index[actor_id] or -1
    if donation_rank ~= -1 then
        noble_rank = rank_list[donation_rank][key]
    else
        noble_rank = _get_noble_rank(donation, -1)
    end
    return noble_rank, donation_rank
end

local function reget_weekly_noble_rank(country, actor_id, donation)
    local rank_list = weekly_rank_list[country]
    local id_index = weekly_id_index[country]
    local key = "weekly_noble_rank"
    local noble_rank = #scheme_weekly_rank

    local donation_rank = id_index[actor_id] or -1
    if donation_rank ~= -1 then
        noble_rank = rank_list[donation_rank][key]
    else
        noble_rank = _get_weekly_noble_rank(donation_rank)
    end
    return noble_rank, donation_rank
end



local function get_donation_list(country, start_index, end_index, actor_id, list_type, old_noble_rank, donation)
    list_type = list_type or "total"
    local rank_list
    local id_index
    local next_level_need
    local noble_rank
    local donation_rank
    if list_type == "total" then
        rank_list = total_rank_list[country]
        id_index = total_id_index[country]
        noble_rank, donation_rank = reget_noble_rank(country, actor_id, donation)
        next_level_need = _get_next_level_need(rank_list, noble_rank, scheme_noble_rank, "donation", donation)
    elseif list_type == "weekly" then
        rank_list = weekly_rank_list[country]
        id_index = weekly_id_index[country]
        noble_rank, donation_rank = reget_weekly_noble_rank(country, actor_id, donation)
        next_level_need = _get_next_level_need(rank_list, noble_rank, scheme_weekly_rank, "weekly_donation", donation)
    else
        flog("warn", "get_donation_list: error type "..list_type)
        return const.error_impossible_param
    end

    local reply_list = {}
    local list_length = #rank_list
    if start_index == nil or end_index == nil or end_index < start_index or start_index < 1 then
        return const.error_impossible_param
    end
    if end_index - start_index > NUMBER_IN_ONE_PAGE then
        return const.error_to_large_data
    end
    if start_index <= list_length then
        if end_index > list_length then
            end_index = list_length
        end
        for i = start_index, end_index do
            table.insert(reply_list, rank_list[i])
        end
    end

    return 0, reply_list, donation_rank, country_fund[country], next_level_need
end


local function get_basic(country, actor_id, donation)
    local noble_rank, donation_rank = reget_noble_rank(country, actor_id, donation)
    return noble_rank, donation_rank, country_fund[country], declaration[country]
end

local function set_declaration(country, content)
    declaration[country] = content or ""
    write_to_database()
end

local function add_country_fund(country, count)
    country_fund[country] = country_fund[country] + count
end

local function remove_country_fund(country, count)
    country_fund[country] = country_fund[country] - count
    if country_fund[country] < 0 then
        country_fund[country] = 0
    end
end

local function get_country_fund(country)
    return country_fund[country]
end

local function on_server_start()
    get_data_from_database()
end

local function on_server_stop()
    is_prepare_close = true
    write_to_database()
end


return {
    country_player_donation = country_player_donation,
    get_donation_list = get_donation_list,
    on_server_start = on_server_start,
    write_to_database = write_to_database,
    reget_noble_rank = reget_noble_rank,
    reget_weekly_noble_rank = reget_weekly_noble_rank,
    get_basic = get_basic,
    add_country_fund = add_country_fund,
    remove_country_fund = remove_country_fund,
    get_country_fund = get_country_fund,
    set_declaration = set_declaration,
    on_server_stop = on_server_stop,
}

