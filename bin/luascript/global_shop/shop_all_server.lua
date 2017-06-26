--------------------------------------------------------------------
-- 文件名:	shop_all_server.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/6 0006
-- 描  述:	全服商店，处理全服相关商店功能，如 全服限购、团购等
--------------------------------------------------------------------
local ingot_shop_scheme = require("data/system_store").mall
local const = require "Common/constant"
local mail_helper = require "global_mail/mail_helper"
local get_time_from_date_string = require("basic/scheme").get_time_from_date_string
local get_config_name = require("basic/scheme").get_config_name
local flog = require "basic/log"
local data_base = require "basic/db_mongo"
local timer = require "basic/timer"
local daily_refresher = require("helper/daily_refresher")
local weekly_refresher = require("helper/weekly_refresher")
local scheme_param = require("data/common_parameter_formula").Parameter
local DAILY_REFRESH_HOUR = scheme_param[37].Parameter
local DAILY_REFRESH_MIN = scheme_param[38].Parameter
local WEEKLY_REFRESH_DAY = 2        --周一
local scheme_items = require("data/common_item").Item
local _get_now_time_second = _get_now_time_second

local item_buy_num = {}
local group_buy_list = {}
local store_save_timer
local refresh_timer
local store_daily_refresher
local store_weekly_refresher
local is_prepare_close = false

local function _refresh_store_data()
    if store_daily_refresher ~= nil then
        store_daily_refresher:check_refresh()
    end
    if store_weekly_refresher ~= nil then
        store_weekly_refresher:check_refresh()
    end

    -- 清理过期的团购
    local current_time = _get_now_time_second()
    for i, group_data in pairs(group_buy_list) do
        if current_time > group_data.over_time then
            group_buy_list[i] = {}
        end
    end
end

local function _db_callback_update_store_info(self, status, doc)
    if status == 0 then
        flog("error", "_db_callback_update_store_info: set data fail!")
        return
    end

    if is_prepare_close then
        ShopUserManageReadyClose()
    end
end

local function _write_data_to_database()
    local store_data = {shop_name = 'ingot_shop' }
    store_data.item_buy_num = item_buy_num
    store_data.group_buy_list = group_buy_list
    store_data.store_daily_last_refresh_time = store_daily_refresher:get_last_refresh_time()
    store_data.store_weekly_last_refresh_time = store_weekly_refresher:get_last_refresh_time()
    data_base.db_update_doc(0, _db_callback_update_store_info, "store_info", {shop_name = 'ingot_shop'}, store_data, 1, 0)
end

local function _daily_refresh()
    for shop_item_id, _ in pairs(item_buy_num) do
        local shop_config = ingot_shop_scheme[shop_item_id]
        if shop_config.BuyType == 1 then  --日限购类型
            item_buy_num[shop_item_id] = nil
        end
    end
    _write_data_to_database()
end

local function _weekly_refresh()
    for shop_item_id, _ in pairs(item_buy_num) do
        local shop_config = ingot_shop_scheme[shop_item_id]
        if shop_config.BuyType == 2 then  --周限购类型
            item_buy_num[shop_item_id] = nil
        end
    end
    _write_data_to_database()
end


local function _db_callback_get_shop_data(self, status, doc)
    if status == 0 or doc == nil then
        flog("error", "_db_callback_get_shop_data: get data fail!")
        return
    end
    item_buy_num = table.copy(doc.item_buy_num) or {}
    group_buy_list = table.copy(doc.group_buy_list) or {}

    local current_time = _get_now_time_second()
    local store_daily_last_refresh_time = doc.store_daily_last_refresh_time or current_time
    local store_weekly_last_refresh_time = doc.store_weekly_last_refresh_time or current_time
    store_daily_refresher = daily_refresher(_daily_refresh, store_daily_last_refresh_time, DAILY_REFRESH_HOUR, DAILY_REFRESH_MIN)
    store_weekly_refresher = weekly_refresher(_weekly_refresh, store_weekly_last_refresh_time, WEEKLY_REFRESH_DAY, DAILY_REFRESH_HOUR, DAILY_REFRESH_MIN)
end

local function _get_data_from_database()
    data_base.db_find_one(0, _db_callback_get_shop_data, "store_info", {rank_name = 'ingot_shop'}, {})
end


local function on_server_start()
    if store_save_timer == nil then
        --store_save_timer = timer.create_timer(_write_data_to_database, 30000, const.INFINITY_CALL)
    end

    if refresh_timer == nil then
        refresh_timer = timer.create_timer(_refresh_store_data, 10000, const.INFINITY_CALL)
    end
    _get_data_from_database()
end

local function ingot_shop_buy(actor_id, shop_item_id, count, on_activity)
    local shop_config = ingot_shop_scheme[shop_item_id]
    item_buy_num[shop_item_id] = item_buy_num[shop_item_id] or 0

    if shop_config.TotalbuyNum ~= -1 then
        if item_buy_num[shop_item_id] + count > shop_config.TotalbuyNum then
            return const.error_item_buy_number_not_enough
        end
        item_buy_num[shop_item_id] = item_buy_num[shop_item_id] + count
    end

    if shop_config.RewardInterval ~= 0 and on_activity then --团购
        local group_data = group_buy_list[shop_item_id]
        if group_data == nil then
            group_buy_list[shop_item_id] = {}
            group_data = group_buy_list[shop_item_id]
            if shop_config.OverTime == "" then
                shop_item_id = shop_item_id or "nil"
                flog("error", "group buy has no over time! shop_item_id "..shop_item_id)
                group_data.over_time = math.huge
            else
                group_data.over_time = get_time_from_date_string(shop_config.OverTime)
            end
        end

        group_data.total_num = group_data.total_num or 0
        group_data.total_num = group_data.total_num + 1
        local total_num = group_data.total_num
        group_data.buy_player = group_data.buy_player or {}
        group_data.buy_player[total_num] = actor_id
        local _itr = total_num - shop_config.RewardInterval
        while(_itr > 0) do
            if group_data.buy_player[_itr] ~= nil then
                local player_id = group_data.buy_player[_itr]
                local item_name = get_config_name(scheme_items[shop_config.Item])
                local attachment = {{item_id = shop_config.RewardID, count = 1} }
                mail_helper.send_mail(player_id,const.MAIL_IDS.GROUP_BUY_REWARD,attachment,_get_now_time_second(),{total_num,item_name})
            end
            _itr = _itr - shop_config.RewardInterval
        end
    end

    _write_data_to_database()
    return 0
end

local function get_ingot_shop_info()
    local group_buy_num = {}
    for i, v in pairs(group_buy_list) do
        group_buy_num[i] = v.total_num
    end
    return item_buy_num, group_buy_num
end

local function on_server_stop()
    is_prepare_close = true
    _write_data_to_database()
end

return {
    ingot_shop_buy = ingot_shop_buy,
    on_server_start = on_server_start,
    get_ingot_shop_info = get_ingot_shop_info,
    on_server_stop = on_server_stop,
}