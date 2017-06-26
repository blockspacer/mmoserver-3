
-- 文件名:	imp_activity.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/3 0003
-- 描  述:	日常、周常活动
--------------------------------------------------------------------
local flog = require "basic/log"
local const = require "Common/constant"
local daily_refresher = require("helper/daily_refresher")
local weekly_refresher = require("helper/weekly_refresher")
local activity_scheme_original = require("data/activity_daily").Activity
local liveness_scheme = require("data/activity_daily").Liveness
local liveness_box_scheme_original = require("data/activity_daily").Chest
local table_copy = table.copy
local string_split = require("basic/scheme").string_split
local tonumber = tonumber
local date_to_day_second = require("basic/scheme").date_to_day_second
local create_add_up_table = require("basic/scheme").create_add_up_table
local get_random_index_with_weight_by_count = require("basic/scheme").get_random_index_with_weight_by_count

local ACTIVITY_NAME_TO_INDEX = const.ACTIVITY_NAME_TO_INDEX

local function _get_interval_time_from_string(data_str)
    if data_str == nil or data_str == 0 or data_str == "" then
        return nil
    end

    local time_table = string_split(data_str,"-")
    local start_time = string_split(time_table[1],":")
    start_time[1] = tonumber(start_time[1])
    start_time[2] = tonumber(start_time[2])
    local start_time_daily = date_to_day_second({hour = start_time[1], min = start_time[2], sec = 0})
    local end_time = string_split(time_table[2],":")
    end_time[1] = tonumber(end_time[1])
    end_time[2] = tonumber(end_time[2])
    local end_time_daily = date_to_day_second({hour = end_time[1], min = end_time[2], sec = 0})

    return {
        start_time = start_time_daily,
        end_time = end_time_daily,
    }
end

local activity_scheme = {}
for _, v in pairs(activity_scheme_original) do
    local new_v = table_copy(v)
    activity_scheme[v.ID] = new_v
    if new_v.Date == 0 or new_v.Date[1] == -1 then
        new_v.Date = {[1] = true, [2] = true,[3] = true,[4] = true,[5] = true,[6] = true,[7] = true,}
    else
        local new_date = {}
        for _, k in pairs(new_v.Date) do
            if k == 7 then
                new_date[1] = true
            else
                new_date[k + 1] = true
            end
        end
        new_v.Date = new_date
    end

    new_v.DateInterval = {}
    for i = 1, 2 do
        new_v.DateInterval[i] = _get_interval_time_from_string(v["DateInterval"..i])
    end
end

local liveness_box_scheme = {}
for _, v in ipairs(liveness_box_scheme_original) do
    liveness_box_scheme[v.RandID] = liveness_box_scheme[v.RandID] or {}
    table.insert(liveness_box_scheme[v.RandID], v)
end


-----------------------------------------------------------------------------

local scheme_param = require("data/common_parameter_formula").Parameter
local DAILY_REFRESH_HOUR = scheme_param[37].Parameter
local DAILY_REFRESH_MIN = scheme_param[38].Parameter
local WEEKLY_REFRESH_DAY = const.WEEKLY_REFRESH_DAY        --周一
local ACTIVITY_TYPE = {
    DAILY_ACTIVITY = 1,                 --日常活动
    WEEKLY_ACTIVITY = 2,                --周常活动
    TIME_LIMITED_ACTIVITY = 3,          --限时活动
    HINT_ACTIVITY = 4,                  --提示性活动
}

local EVIL_INVADE_MONSTER_ID = {
    [44] = true,
    [45] = true,
    [46] = true,
    [47] = true,
    [48] = true,
    [49] = true,
    [50] = true,
}

local params = {
    liveness_history = {db = true, sync = true},                                 --最高活跃度
    liveness_current = {db = true, sync = true},                                 --当前活跃度
    exp_from_monster_daily = {db = true, sync = false},                           --每日杀怪所得经验
}

local imp_activity = {}
imp_activity.__index = imp_activity

setmetatable(imp_activity, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_activity.__params = params

local function _daily_refresh(self)
    --flog("salog", string.format("imp_activity _daily_refresh"), self.actor_id)
    self.exp_from_monster_daily = 0

    for activity_id, count in pairs(self.activity_counts) do
        local activity_type = activity_scheme[activity_id].RefreshType
        if activity_type == 1 then
            self.activity_counts[activity_id] = 0
        end
    end
end

local function _weekly_refresh(self)
    self:change_value_on_rank_list("liveness_history", 0)
    self.liveness_current = 0

    for activity_id, count in pairs(self.activity_counts) do
        if activity_scheme[activity_id].RefreshType == 2 then
            self.activity_counts[activity_id] = 0
        end
    end
end

function imp_activity.__ctor(self)
    self.activity_counts = {}
end

--根据dict初始化
function imp_activity.imp_activity_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    self.activity_counts = table.get(dict, "activity_counts", {})

    local current_time = _get_now_time_second()
    if dict.activity_daily_last_refresh_time == nil then
        dict.activity_daily_last_refresh_time = 0
        flog("warn", "activity_daily_last_refresh_time get nil "..self.actor_id)
    end
    if dict.activity_weekly_last_refresh_time == nil then
        dict.activity_weekly_last_refresh_time = 0
        flog("warn", "activity_weekly_last_refresh_time get nil "..self.actor_id)
    end

    self.activity_daily_refresher = daily_refresher(_daily_refresh, dict.activity_daily_last_refresh_time, DAILY_REFRESH_HOUR, DAILY_REFRESH_MIN)
    self.activity_weekly_refresher = weekly_refresher(_weekly_refresh, dict.activity_weekly_last_refresh_time, WEEKLY_REFRESH_DAY, DAILY_REFRESH_HOUR, DAILY_REFRESH_MIN)
    self.activity_daily_refresher:check_refresh(self)
    self.activity_weekly_refresher:check_refresh(self)
end

function imp_activity.imp_activity_init_from_other_game_dict(self,dict)
    self:imp_activity_init_from_dict(dict)
end

function imp_activity.imp_activity_write_to_dict(self, dict)
    self.activity_daily_refresher:check_refresh(self)
    self.activity_weekly_refresher:check_refresh(self)
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end

    dict.activity_counts = self.activity_counts

    dict.activity_daily_last_refresh_time = self.activity_daily_refresher:get_last_refresh_time()
    dict.activity_weekly_last_refresh_time = self.activity_weekly_refresher:get_last_refresh_time()
end

function imp_activity.imp_activity_write_to_other_game_dict(self,dict)
    self:imp_activity_write_to_dict(dict)
end

function imp_activity.imp_activity_write_to_sync_dict(self, dict)
    self.activity_daily_refresher:check_refresh(self)
    self.activity_weekly_refresher:check_refresh(self)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end

    dict.activity_counts = self.activity_counts
end

local function _is_in_activity_time(activity_id)
    local current_time = _get_now_time_second()
    local current_date = os.date("*t", current_time)
    local week_day = current_date.wday
    local config = activity_scheme[activity_id]
    if not config.Date[week_day] then
        return false
    end

    local time_daily = date_to_day_second(current_date)
    local data_interval = config.DateInterval
    for i, v in pairs(data_interval) do
        if time_daily >= v.start_time and time_daily <= v.end_time then
            return true
        end
    end

    return false
end


function imp_activity.finish_activity(self, activity_name)
    self.activity_daily_refresher:check_refresh(self)
    self.activity_weekly_refresher:check_refresh(self)
    local activity_id = ACTIVITY_NAME_TO_INDEX[activity_name]
    if activity_id == nil then
        flog("error", "imp_activity.finish_activity: wrong activity_name "..activity_name)
    end

    if not _is_in_activity_time(activity_id) then
        return
    end

    local config = activity_scheme[activity_id]
    self.activity_counts[activity_id] = self.activity_counts[activity_id] or 0
    if self.activity_counts[activity_id] < config.ActiveNum then
        self:change_value_on_rank_list("liveness_history", self.liveness_history + config.ActiveReward)
        self.liveness_current = self.liveness_current + config.ActiveReward
    end

    self.activity_counts[activity_id] = self.activity_counts[activity_id] + 1
end

function imp_activity.on_get_activity_info(self, input)
    local activity_info = {}
    self:imp_activity_write_to_sync_dict(activity_info)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetActivityInfoRet", activity_info = activity_info})
end

function imp_activity.on_open_activity_box(self, input)
    local box_id = input.box_id

    local liveness_config = liveness_scheme[box_id]
    if liveness_config == nil then
        flog("error", "on_open_activity_box fail, no box_id "..box_id)
        return
    end

    self.activity_daily_refresher:check_refresh(self)
    self.activity_weekly_refresher:check_refresh(self)

    local output = {func_name = "OpenActivityBoxRet"}
    local history_need = liveness_config.NeedLiveness
    if self.liveness_history < history_need then
        output.result = const.error_liveness_history_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    local current_need = liveness_config.ConsumeLiveness
    if self.liveness_current < current_need then
        output.result = const.error_liveness_current_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    self.liveness_current = self.liveness_current - current_need
    local package_id = liveness_config.PackageID
    local package_config = liveness_box_scheme[package_id]
    if package_config == nil then
        flog("error", "on_open_activity_box fail, no package_id "..package_id)
        return
    end

    local weight_table = {}
    for i, v in ipairs(package_config) do
        if self.level >= v.LowerLimit and self.level <= v.UpperLimit then
            weight_table[i] = v.Weight
        end
    end
    local add_up_table = create_add_up_table(weight_table)
    local index = get_random_index_with_weight_by_count(add_up_table)
    local item = package_config[index].Item
    local rewards = {}
    rewards[item[1]] = item[2]
    self:add_new_rewards(rewards)
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards)

    local activity_info = {}
    self:imp_activity_write_to_sync_dict(activity_info)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetActivityInfoRet", activity_info = activity_info})
end

function imp_activity.imp_activity_kill_monster(self, monster_type, monster_id)
    if monster_type == const.MONSTER_TYPE.WILD_ELITE_BOSS then
        self:finish_activity("elite_boss")
    end

    if EVIL_INVADE_MONSTER_ID[monster_id] then
        self:finish_activity("evil_invade")
    end
end

return imp_activity