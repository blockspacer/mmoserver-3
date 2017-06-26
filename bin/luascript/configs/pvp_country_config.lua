--------------------------------------------------------------------
-- 文件名:	pvp_country_config.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/5/25 0025
-- 描  述:	pvp阵营配置文件
--------------------------------------------------------------------
local pvp_country_scheme = require("data/pvp_country")
local pvp_country_param = pvp_country_scheme.Parameter
local tonumber = tonumber
local qualification_scheme = pvp_country_scheme.ElectionQualification
local office_scheme =  pvp_country_scheme.GovernmentPost
local election_time_original_scheme = pvp_country_scheme.ElectionDuration
local election_time_scheme
local discount_scheme = pvp_country_scheme.DiscountFunction
local war_rank_scheme = pvp_country_scheme.Rank
local officer_skill_scheme = pvp_country_scheme.OfficerSkill
local const = require "Common/constant"

local first_order_number
local skill_cd_list

local SEC_OF_MIN = 60
local SEC_OF_HOUR = 3600
local SEC_OF_DAY = 86400
local SEC_OF_WEEK = 604800
local SKILL_NAME_TO_ID = const.OFFICE_SKILL_NAME_TO_ID


local function is_qualification_time(current_time)
    local qualification_time = election_time_scheme[1]
    local current_date = os.date("*t", current_time)
    if current_date.wday == qualification_time.start_wday and current_date.hour == qualification_time.start_hour and current_date.min == qualification_time.start_min then
        return true
    end
    return false
end

local function _is_time_right(current_time, index)
    local current_date = os.date("*t", current_time)
    local nomination_time = election_time_scheme[index]
    if nomination_time.middle_index[current_date.wday] then
        return true
    else
        if current_date.wday ~= nomination_time.start_wday and current_date.wday ~= nomination_time.end_wday then
            return false
        end

        local day_time = current_date.hour * SEC_OF_HOUR + current_date.min * SEC_OF_MIN + current_date.sec
        if current_date.wday == nomination_time.start_wday then
            if day_time < nomination_time.start_day_time then
                return false
            end
        end
        if current_date.wday == nomination_time.end_wday then
            if day_time > nomination_time.end_day_time then
                return false
            end
        end
        return true
    end
end

local function is_nomination_time(current_time)
    return _is_time_right(current_time, 2)
end

local function is_nomination_end_time(current_time)
    local nomination_end_time = election_time_scheme[2]
    local current_date = os.date("*t", current_time)
    if current_date.wday == nomination_end_time.end_wday and current_date.hour == nomination_end_time.end_hour and current_date.min == nomination_end_time.end_min then
        return true
    end
    return false
end

local function _count_remaining_time(current_time, index)
    local current_date = os.date("*t", current_time)
    local time_config = election_time_scheme[index]
    if time_config == nil then
        _error("_count_remaining_time error index "..tostring(index))
    end
    local delta_day = (time_config.start_wday + 7 - current_date.wday) % 7
    local day_time = current_date.hour * SEC_OF_HOUR + current_date.min * SEC_OF_MIN + current_date.sec
    local delta_day_sec = time_config.start_day_time - day_time

    local delta_sec = delta_day * SEC_OF_DAY + delta_day_sec
    if delta_sec < 0 then
        delta_sec = delta_sec + SEC_OF_WEEK
    end
    return delta_sec
end

local function remaining_time_to_nomination(current_time)
    if is_nomination_time(current_time) then
        return 0
    end

    return _count_remaining_time(current_time, 2)
end


local function is_vote_time(current_time)
    return _is_time_right(current_time, 3)
end

local function remaining_time_to_vote(current_time)
    if is_vote_time(current_time) then
        return 0
    end

    return _count_remaining_time(current_time, 3)
end

local function remaining_time_to_count(current_time)
    return _count_remaining_time(current_time, 4)
end

local function is_count_votes_time(current_time)
    local settle_accounts_time = election_time_scheme[4]
    local current_date = os.date("*t", current_time)
    if current_date.wday == settle_accounts_time.start_wday and current_date.hour == settle_accounts_time.start_hour and current_date.min == settle_accounts_time.start_min then
        return true
    end
    return false
end

local function get_count_votes_time()
    local settle_accounts_time = election_time_scheme[4]
    return settle_accounts_time.start_wday, settle_accounts_time.start_hour, settle_accounts_time.start_min
end

local function get_officer_discount_info(office_id)
    local info = discount_scheme[office_id]
    if info == nil then
        return
    end
    return info.discount, info.lasttime, info.int
end

local function get_officer_total_skill(office_id)
    local info = office_scheme[office_id]
    if info == nil then
        return
    end
    return info.officerskill1BUFF
end

local function get_officer_halo_skill(office_id)
    local info = office_scheme[office_id]
    if info == nil then
        return
    end
    return info.officerskill2
end

local function has_right_to_pay_salary(office_id)
    if office_id == nil then
        return false
    end
    local info = office_scheme[office_id]
    if info == nil then
        return false
    end
    if info.paysalary == 1 then
        return true
    end
    return false
end

local function get_skill_info(skill_name)
    local skill_info = officer_skill_scheme[SKILL_NAME_TO_ID[skill_name]]
    return skill_info.CD, skill_info.Cdprice, skill_info.parameter1, skill_info.parameter2, skill_info.parameter3
end


local function reload()
    election_time_scheme = {}
    for i, v in pairs(election_time_original_scheme) do
        election_time_scheme[i] = {}

        election_time_scheme[i].start_wday = (v.begindate + 6) % 7
        election_time_scheme[i].end_wday = (v.enddate + 6) % 7
        local middle_index = {}
        election_time_scheme[i].middle_index = middle_index
        if v.begindate < v.enddate then
            for wday = v.begindate + 1, v.enddate - 1 do
                middle_index[wday] = true
            end
        elseif v.begindate > v.enddate then
            for wday = v.begindate + 1, 7 do
                middle_index[wday] = true
            end
            for wday = 1, v.enddate - 1 do
                middle_index[wday] = true
            end
        end

        election_time_scheme[i].start_day_time = v.begintime[1] * SEC_OF_HOUR + v.begintime[2] * SEC_OF_MIN
        election_time_scheme[i].end_day_time = v.endtime[1] * SEC_OF_HOUR + v.endtime[2] * SEC_OF_MIN

        election_time_scheme[i].start_hour = v.begintime[1]
        election_time_scheme[i].start_min = v.begintime[2]

        election_time_scheme[i].end_hour = v.endtime[1]
        election_time_scheme[i].end_min = v.endtime[2]
    end
    first_order_number = tonumber(pvp_country_param[15].Value)

    skill_cd_list = {}
    for name, id in pairs(SKILL_NAME_TO_ID) do
        local skill_info = officer_skill_scheme[id]
        skill_cd_list[name] = skill_info.CD
    end
end

reload()

return {
    is_qualification_time = is_qualification_time,
    qualification_scheme = qualification_scheme,
    office_scheme = office_scheme,
    is_nomination_time = is_nomination_time,
    is_nomination_end_time = is_nomination_end_time,
    is_vote_time = is_vote_time,
    is_count_votes_time = is_count_votes_time,
    get_count_votes_time = get_count_votes_time,
    get_officer_discount_info = get_officer_discount_info,
    get_officer_total_skill = get_officer_total_skill,
    get_officer_halo_skill = get_officer_halo_skill,
    has_right_to_pay_salary = has_right_to_pay_salary,
    war_rank_scheme = war_rank_scheme,
    first_order_number = first_order_number,
    remaining_time_to_nomination = remaining_time_to_nomination,
    remaining_time_to_vote = remaining_time_to_vote,
    skill_cd_list = skill_cd_list,
    get_skill_info = get_skill_info,
    remaining_time_to_count = remaining_time_to_count,
    reload = reload,
}