----------------------------------------------------------------------
-- 文件名:	imp_store.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/10/24
-- 描  述:	商店模块
--------------------------------------------------------------------
local flog = require "basic/log"
local const = require "Common/constant"
local item_scheme = require("data/common_item").Item
local shop_total_scheme = require("data/system_store")
local store_param = require("data/system_store").Parameter
local ingot_shop_scheme = require("data/system_store").mall
local daily_refresher = require("helper/daily_refresher")
local weekly_refresher = require("helper/weekly_refresher")
local is_command_cool_down = require("helper/command_cd").is_command_cool_down
local get_cool_down_expire_time = require("helper/command_cd").get_cool_down_expire_time
local wander_scheme = require("data/system_store").wander
local timer = require "basic/timer"
local date_to_day_second = require("basic/scheme").date_to_day_second
local db_hiredis = require "basic/db_hiredis"

local WANDER_BUY_CD = tonumber(store_param[1].value)
local RESOURCE_ID_TO_NAME = const.RESOURCE_ID_TO_NAME
local NORMAL_SHOP_NAME = {
    grocery = true,
    copy = true,
    arena = true,
    confraternity = true,
    camp = true,
    blackmarket = true,
}

-------------
--云游商人初始化
--------------
local wander_appear = false
local buying_num = 0
local wander_timer
local is_debug = false

--- 初始化活动时间
local activity_start_time = {}
local activity_end_time = {}
local get_time_from_date_string = require("basic/scheme").get_time_from_date_string
for i, v in pairs(ingot_shop_scheme) do
    if v.BeginTime == "" then
        activity_start_time[i] = 0
    else
        activity_start_time[i] = get_time_from_date_string(v.BeginTime)
    end

    if v.OverTime == "" then
        activity_end_time[i] = math.huge
    else
        activity_end_time[i] = get_time_from_date_string(v.OverTime)
    end
end


--- 日常限购刷新
local refresh_timer
local store_daily_refresher
local store_weekly_refresher
local scheme_param = require("data/common_parameter_formula").Parameter
local DAILY_REFRESH_HOUR = scheme_param[37].Parameter
local DAILY_REFRESH_MIN = scheme_param[38].Parameter
local WEEKLY_REFRESH_DAY = const.WEEKLY_REFRESH_DAY        --周一

local function _daily_refresh(self)
    for shop_item_id, _ in pairs(self.ingot_item_buy_num) do
        local shop_config = ingot_shop_scheme[shop_item_id]
        if shop_config.BuyType == 1 then  --日限购类型
            self.ingot_item_buy_num[shop_item_id] = nil
        end
    end
end

local function _weekly_refresh(self)
    for shop_item_id, _ in pairs(self.ingot_item_buy_num) do
        local shop_config = ingot_shop_scheme[shop_item_id]
        if shop_config.BuyType == 2 then  --周限购类型
            self.ingot_item_buy_num[shop_item_id] = nil
        end
    end
end


-------------------------------------------------------


local params = {
    is_wander_buy = {default = false},
    vip_level = {db = true,sync=true,default=0},       --vip等级
}

local imp_store = {}
imp_store.__index = imp_store

setmetatable(imp_store, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_store.__params = params

local function _init_normal_item_buy_num(self)
    self.normal_item_buy_num = {}
    for shop_name, _ in pairs(NORMAL_SHOP_NAME) do
        self.normal_item_buy_num[shop_name] = {}
    end
end

function imp_store.__ctor(self)
    self.ingot_item_buy_num = {}
    _init_normal_item_buy_num(self)
end

local function _get_item_price(item_id, money_type_id)
    local price_name
    if RESOURCE_ID_TO_NAME[money_type_id] == "coin" or RESOURCE_ID_TO_NAME[money_type_id] == "bind_coin" then
        price_name = "SliverPrice"
    elseif RESOURCE_ID_TO_NAME[money_type_id] == "ingot" then
        price_name = "IngotPrice"
    elseif RESOURCE_ID_TO_NAME[money_type_id] == "silver" then
        price_name = "SilveringotPrice"
    elseif RESOURCE_ID_TO_NAME[money_type_id] == "faction_score" then
        price_name = "TributePrice"
    elseif RESOURCE_ID_TO_NAME[money_type_id] == "feats" then
        price_name = "FeatsPrice"
    elseif RESOURCE_ID_TO_NAME[money_type_id] == "dungeon_score" then
        price_name = "CopyPrice"
    elseif RESOURCE_ID_TO_NAME[money_type_id] == "pvp_score" then
        price_name = "AthleticsPrice"
    end

    if price_name == nil then
        money_type_id = money_type_id or "nil"
        flog("error", "price_name is nil, not config price "..money_type_id)
    end

    local price = item_scheme[item_id][price_name]
    if price == nil or price == 0 then
        item_id = item_id or "nil"
        flog("error", "_get_item_price item price error: "..item_id)
        return math.huge
    end
    return price
end

function imp_store.get_item_price(item_id, money_type_id)
    return _get_item_price(item_id, money_type_id)
end


local function on_wander_buy(self, input, syn_data)
    local cell = input.cell
    local count = input.count
    local index = input.index

    if count > 1 then
        count = 1
    end

    local result = 0

    if not wander_appear then
        return self:send_message(const.SC_MESSAGE_LUA_WANDER_BUY , {result = const.error_wander_disappear})
    end

    local wander_item = wander_scheme[index]
    if self.level < wander_item.levelmin or self.level > wander_item.levelmax then
        return self:send_message(const.SC_MESSAGE_LUA_WANDER_BUY , {result = const.error_level_not_match_goods})
    end

    local cd_rst, expire_time = is_command_cool_down(self.actor_id, "wander_buy", WANDER_BUY_CD)
    if cd_rst ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_WANDER_BUY , {result = cd_rst, expire_time = expire_time})
    end

    if not self:is_item_addable(wander_item.item[1], count) then
        return self:send_message(const.SC_MESSAGE_LUA_WANDER_BUY , {result = const.error_bag_is_full})
    end

    local money_type_id = wander_item.money
    local price = _get_item_price(wander_item.item[1], money_type_id)
    price = math.ceil(price * wander_item.discount / 100 * count)

    if not self:is_enough_by_id(money_type_id, price) then
        return self:send_message(const.SC_MESSAGE_LUA_WANDER_BUY , {result = const.error_item_not_enough})
    end

    input.func_name = "wander_shop_buy"
    input.price = price
    input.count = count
    input.index = index
    input.cell = cell
    self:send_message_to_shop_server(input)
end

function imp_store.wander_buy_end(self, input)
    local result = input.result
    local index = input.index
    local price = input.price
    local count = input.count

    local wander_item = wander_scheme[index]
    local money_type_id = wander_item.money

    if result == 0 then
        if not self:is_enough_by_id(money_type_id, price) then
            return self:send_message(const.SC_MESSAGE_LUA_WANDER_BUY , {result = const.error_item_not_enough})
        end

        self:remove_item_by_id(money_type_id, price)
        self:add_new_rewards({[wander_item.item[1]] = count})
        self:send_message(const.SC_MESSAGE_LUA_REQUIRE, {[wander_item.item[1]] = count})
        local bag_dict = {}
        self:imp_assets_write_to_sync_dict(bag_dict)
        self:send_message(const.SC_MESSAGE_LUA_UPDATE , bag_dict)

        local expire_time = get_cool_down_expire_time(self.actor_id, "wander_buy", WANDER_BUY_CD)
        self:send_message(const.SC_MESSAGE_LUA_WANDER_BUY , {result = 0, expire_time = expire_time})
    end
end

local function on_wander_hold(self, input, syn_data)
    if wander_appear then
        buying_num = buying_num + 1
        self.is_wander_buy = true

        input.func_name = "wander_hold"
        local expire_time = get_cool_down_expire_time(self.actor_id, "wander_buy", WANDER_BUY_CD)
        input.expire_time = expire_time
        self:send_message_to_shop_server(input)
    else
        self:send_message(const.SC_MESSAGE_LUA_WANDER_BUY , {result = const.error_wander_disappear})
    end
end

local function on_wander_free(self, input, syn_data)
    if wander_appear then
        buying_num = buying_num - 1
        self.is_wander_buy = false
        if buying_num < 0 then
            flog("error", "buying_num cannot less than 0! : "..buying_num)
        end
        self:send_message(const.SC_MESSAGE_LUA_WANDER_FREE , {result = 0})
    else
        self:send_message(const.SC_MESSAGE_LUA_WANDER_BUY , {result = const.error_wander_disappear})
    end
end


local function on_logout(self, input, syn_data)
    if self.is_wander_buy == true then
        buying_num = buying_num - 1
        self.is_wander_buy = false
    end

    if buying_num < 0 then
        flog("warn", "buying_num cannot less than 0! : "..buying_num)
    end
end
--根据dict初始化
function imp_store.imp_store_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    self.ingot_item_buy_num = table.copy(dict.ingot_item_buy_num) or {}
    self.normal_item_buy_num = table.copy(dict.normal_item_buy_num)
    if self.normal_item_buy_num == nil then
        _init_normal_item_buy_num(self)
    end

    local current_time = _get_now_time_second()
    local store_daily_last_refresh_time = dict.store_daily_last_refresh_time or current_time
    local store_weekly_last_refresh_time = dict.store_weekly_last_refresh_time or current_time
    store_daily_refresher = daily_refresher(_daily_refresh, store_daily_last_refresh_time, DAILY_REFRESH_HOUR, DAILY_REFRESH_MIN)
    store_weekly_refresher = weekly_refresher(_weekly_refresh, store_weekly_last_refresh_time, WEEKLY_REFRESH_DAY, DAILY_REFRESH_HOUR, DAILY_REFRESH_MIN)
    store_daily_refresher:check_refresh(self)
    store_weekly_refresher:check_refresh(self)
end

function imp_store.imp_store_init_from_other_game_dict(self,dict)
    self:imp_store_init_from_dict(dict)
end

function imp_store.imp_store_write_to_dict(self, dict, to_other_game)
    store_daily_refresher:check_refresh(self)
    store_weekly_refresher:check_refresh(self)
    if to_other_game then
        for i, _ in pairs(params) do
            dict[i] = self[i]
        end
    else
        for i, v in pairs(params) do
            if v.db then
                dict[i] = self[i]
            end
        end
    end

    dict.ingot_item_buy_num = table.copy(self.ingot_item_buy_num)
    dict.normal_item_buy_num = table.copy(self.normal_item_buy_num)
    dict.store_daily_last_refresh_time = store_daily_refresher:get_last_refresh_time()
    dict.store_weekly_last_refresh_time = store_weekly_refresher:get_last_refresh_time()
end

function imp_store.imp_store_write_to_other_game_dict(self,dict)
    self:imp_store_write_to_dict(dict, true)
end

function imp_store.imp_store_write_to_sync_dict(self, dict)
    store_daily_refresher:check_refresh(self)
    store_weekly_refresher:check_refresh(self)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end

    dict.wander_appear = wander_appear
end

function imp_store.gm_wander_appear(self, debug)
    if debug == 1 then
        is_debug = true
        wander_appear = true
    else
        is_debug = false
    end

    self:send_message_to_shop_server({func_name = "gm_wander_appear", debug = debug})
end

local function _get_ingot_shop_item_price(shop_item_id, count, on_activity)
    local shop_config = ingot_shop_scheme[shop_item_id]
    local money_type_id = shop_config.Money
    local item_id = shop_config.Item
    local price = _get_item_price(item_id, money_type_id)
    if on_activity then
        price = math.ceil(price * shop_config.DiscountTime / 100) * count
    else
        price = math.ceil(price * count)
    end
    return price
end

local function _ingot_shop_buy_success(self, shop_item_id, count, price)
    local shop_config = ingot_shop_scheme[shop_item_id]
    local money_type_id = shop_config.Money
    local item_id = shop_config.Item

    if not self:is_enough_by_id(shop_config.Money, price) then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "IngotShopBuyRet", result = const.error_item_not_enough, items_lack = {shop_config.Money}})
    end
    self.ingot_item_buy_num[shop_item_id] = self.ingot_item_buy_num[shop_item_id] + count
    self:remove_item_by_id(money_type_id, price)
    self:add_new_rewards({[item_id] = count})
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, {[item_id] = count})
    self:on_get_ingot_shop_info()
    local bag_dict = {}
    self:imp_assets_write_to_sync_dict(bag_dict)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE , bag_dict)
    flog("salog", string.format("Ingot shop buy %d ,cost %d : %d", shop_item_id, money_type_id, price), self.actor_id)
end

function imp_store.on_ingot_shop_buy(self, input)
    store_daily_refresher:check_refresh(self)
    store_weekly_refresher:check_refresh(self)

    local shop_item_id = input.shop_item_id
    local count = input.count or 1
    local shop_config = ingot_shop_scheme[shop_item_id]

    if shop_config == nil then
        flog("error", "imp_store.on_ingot_shop_buy error "..shop_item_id)
    end

    -- 等级限制
    if self.level < shop_config.BuyLevel then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "IngotShopBuyRet", result = const.error_level_not_match_goods})
    end

    -- TODO：累计货币要求

    -- vip等级限制
    if self.vip_level < shop_config.VipLevel then
      return  self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "IngotShopBuyRet", result = const.error_vip_level_is_not_enough})
    end

    -- 个人限购
    self.ingot_item_buy_num[shop_item_id] = self.ingot_item_buy_num[shop_item_id] or 0
    if shop_config.BuyNum ~= -1 and self.ingot_item_buy_num[shop_item_id] + count > shop_config.BuyNum then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "IngotShopBuyRet", result = const.error_item_buy_number_not_enough})
    end

    -- 职业限制
    if shop_config.UseCareer[1] ~= -1 then
        local vocation_match = false
        for _, v in pairs(shop_config.UseCareer) do
            if v == self.vocation then
                vocation_match = true
                break
            end
        end
        if not vocation_match then
            return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "IngotShopBuyRet", result = const.error_vocation_not_match})
        end
    end

    -- 活动是否开启
    local current_time = _get_now_time_second()
    local on_activity = true

    if current_time < activity_start_time[shop_item_id] or current_time > activity_end_time[shop_item_id] then
        on_activity = false
        if shop_config.OffSell == 1 then
            return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "IngotShopBuyRet", result = const.error_item_is_off_shelves})
        end
    end

    -- 货币是否足够
    local price = _get_ingot_shop_item_price(shop_item_id, count, on_activity)
    if not self:is_enough_by_id(shop_config.Money, price) then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "IngotShopBuyRet", result = const.error_item_not_enough, items_lack = {shop_config.Money}})
    end

    -- 背包是否已满
    if not self:is_item_addable(shop_config.Item, count) then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "IngotShopBuyRet", result = const.error_bag_is_full, items_lack = {shop_config.Money}})
    end

    if shop_config.TotalbuyNum ~= -1 or shop_config.RewardInterval ~= 0 then
        input.func_name = "ingot_shop_buy"
        input.on_activity = on_activity
        input.price = price
        input.actor_id = self.actor_id
        return self:send_message_to_shop_server(input)
    end
    _ingot_shop_buy_success(self, shop_item_id, count, price)
end

function imp_store.on_ingot_shop_buy_end(self, input)
    local result = input.result
    if result == 0 then
        _ingot_shop_buy_success(self, input.shop_item_id, input.count, input.price)
    end
end

function imp_store.on_get_ingot_shop_info(self, input)
    store_daily_refresher:check_refresh(self)
    store_weekly_refresher:check_refresh(self)
    local output = {}
    output.func_name = "get_ingot_shop_info"
    output.ingot_item_buy_num = self.ingot_item_buy_num
    return self:send_message_to_shop_server(output)
end

local function _get_extral_discount_info(shop_name)
    local current_time = _get_now_time_second()
    if shop_name == "camp" then
        local country_discount_info = db_hiredis.get("country_discount_info")
        if country_discount_info ~= nil and country_discount_info.office_id ~= nil and current_time < country_discount_info.end_time then
            return country_discount_info
        end
    end
    return
end

function imp_store.on_normal_shop_buy(self, input, syn_data)
    store_daily_refresher:check_refresh(self)
    store_weekly_refresher:check_refresh(self)
    local shop_name = input.shop_name
    local shop_item_id = input.shop_item_id
    local count = input.count

    local discount_info = _get_extral_discount_info(shop_name)
    local extra_discount = 1
    if discount_info ~= nil then
        extra_discount = discount_info.discount / 100
    end

    local item_buy_num = self.normal_item_buy_num[shop_name]
    local output = {func_name = "NormalShopBuyRet", result = 0}
    if item_buy_num == nil or count == nil then
        output.result = const.error_impossible_param
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    local current_item_buy_num = item_buy_num[shop_item_id] or 0

    local shop_item_config = shop_total_scheme[shop_name][shop_item_id]
    if shop_item_config == nil then
        output.result = const.error_impossible_param
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    if not self:is_item_addable(shop_item_config.item, count) then
        output.result = const.error_bag_is_full
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    if self.level < shop_item_config.levelmin or self.level > shop_item_config.levelmax then
        output.result = const.error_level_not_match_goods
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    if shop_item_config.BuyNum ~= -1 and current_item_buy_num + count > shop_item_config.BuyNum then
        output.result = const.error_item_buy_number_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    local money_type_id = shop_item_config.money
    local price = _get_item_price(shop_item_config.item, money_type_id) * extra_discount
    price = math.ceil(price * shop_item_config.discount / 100 * count)

    if not self:is_enough_by_id(money_type_id, price) then
        output.result = const.error_item_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    --- 购买成功
    if shop_item_config.BuyNum ~= -1 then
        item_buy_num[shop_item_id] = current_item_buy_num + count
    end

    self:remove_item_by_id(money_type_id, price)
    self:add_new_rewards({[shop_item_config.item] = count})
    output.item_buy_num = item_buy_num
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, {[shop_item_config.item] = count})
    self:imp_assets_write_to_sync_dict(syn_data)
    flog("salog", string.format("Normal shop %s buy %d ,cost %d : %d", shop_name, shop_item_id, money_type_id, price), self.actor_id)
end

function imp_store.on_get_normal_shop_info(self, input)
    store_daily_refresher:check_refresh(self)
    store_weekly_refresher:check_refresh(self)
    local shop_name = input.shop_name

    local discount_info = _get_extral_discount_info(shop_name)

    local item_buy_num = self.normal_item_buy_num[shop_name]
    local output = {func_name = "GetNormalShopInfoRet", item_buy_num = item_buy_num, result = 0, discount_info = discount_info}
    if item_buy_num == nil then
        output.result = const.error_impossible_param
    end
    return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_store.gm_clear_shop_item_buy_num(self)
    self.ingot_item_buy_num = {}
    _init_normal_item_buy_num(self)
end


local string_split = require("basic/scheme").string_split
local wander_exist_range = {}
local refresh_time = store_param[2].value
refresh_time = string_split(refresh_time,"|")
for _, time in pairs(refresh_time) do
    time = string_split(time,":")
    local start_time = date_to_day_second({hour = time[1], min = time[2], sec = 0})
    local end_time = date_to_day_second({hour = time[1], min = time[2], sec = 0}) + const.WANDER_LAST_TIME
    table.insert(wander_exist_range, {start_time = start_time, end_time = end_time})
end


local function wander_timer_callback()
    if is_debug then
        return
    end

    local cur_time = date_to_day_second()
    local is_in_refresh = false
    for _, v in pairs(wander_exist_range) do
        if cur_time > v.start_time and cur_time < v.end_time then
            is_in_refresh = true
            break
        end
    end

    if wander_appear and not is_in_refresh then
        wander_appear = false
    elseif not wander_appear and is_in_refresh then
        wander_appear = true
    end
end

local function _server_start()
    if wander_timer == nil then
        wander_timer = timer.create_timer(wander_timer_callback, 5000, const.INFINITY_CALL)
    end
end
register_function_on_start(_server_start)

register_message_handler(const.CS_MESSAGE_LUA_WANDER_BUY, on_wander_buy)
register_message_handler(const.CS_MESSAGE_LUA_WANDER_HOLD, on_wander_hold)
register_message_handler(const.CS_MESSAGE_LUA_WANDER_FREE, on_wander_free)
register_message_handler(const.SS_MESSAGE_LUA_USER_LOGOUT, on_logout)

imp_store.__message_handler = {}
imp_store.__message_handler.on_wander_buy = on_wander_buy
imp_store.__message_handler.on_wander_hold = on_wander_hold
imp_store.__message_handler.on_wander_free = on_wander_free
imp_store.__message_handler.on_logout = on_logout

return imp_store