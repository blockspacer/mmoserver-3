--------------------------------------------------------------------
-- 文件名:	imp_assets.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/08
-- 描  述:	资产模块(包括道具、经验、宠物等)
--------------------------------------------------------------------
local flog = require "basic/log"
local create_inventory = require "entities/items/inventory"
local const = require "Common/constant"
local normal_transcript = require("data/challenge_main_dungeon").NormalTranscript
local item_scheme = require("data/common_item").Item
local resource_name_to_id = const.RESOURCE_NAME_TO_ID
local level_scheme = require("data/common_levels").Level
local scheme_param = require("data/common_parameter_formula").Parameter
local daily_refresher = require("helper/daily_refresher")
local tili_price_table = require("data/challenge_main_dungeon").PurchasePower
local item_effect_manager = require "entities/items/item_effect_manager"
local common_item_config = require "configs/common_item_config"
local mail_helper = require "global_mail/mail_helper"
local math = require "math"
local string_format = string.format
local tonumber = tonumber
local math_floor = math.floor
local drop_manager = require("helper/drop_manager")
local no_dungeon_drop_manager = drop_manager("no_dungeon")
local anger_rate_scheme = require("data/common_scene").AngerRate
local recreate_scheme_table_with_key = require("basic/scheme").recreate_scheme_table_with_key
local levels_scheme_original = require("data/common_levels").Level
local levels_scheme = recreate_scheme_table_with_key(levels_scheme_original, "Level")
local get_sequence_index = require("basic/scheme").get_sequence_index
local _get_now_time_second = _get_now_time_second
local monster_type_scheme = require("data/common_fight_base").Type
local common_parameter_formula_config = require "configs/common_parameter_formula_config"

local TILI_BUY_COUNT = require("data/challenge_main_dungeon").Parameter[12].Value[1]
local SECOND_PER_TILI = scheme_param[21].Parameter     --每点体力增长所用的秒数
local LEVEL_MANUAL_UPGRADE = scheme_param[23].Parameter     --升到此等级开始手动升级
local LEVEL_CEIL = scheme_param[1].Parameter     --当前版本等级上限
local DECAY_RATE = scheme_param[44].Parameter     --衰减比例
DECAY_RATE = DECAY_RATE / 100


local params = {
    tili_last_refresh_time = {db = true, sync = true },
    tili_ceil = {db = true, sync = true, default= level_scheme[1].Vit },
    tili_buy_times = {db = true, sync = true},                                --每日体力购买次数
    kill_boss_score = {db = true, sync = false} ,                             --杀死boss积分
    wealth = {},                                                              --财富值
}

local imp_assets = {}--[[]]
imp_assets.__index = imp_assets

setmetatable(imp_assets, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_assets.__params = params

function imp_assets.__ctor(self)
    self.inventory = create_inventory()
    self.assets_refresher = nil
    self.drug_cds = {}
end


local function on_bag_get_all(self, input, syn_data)
    self:check_fashion_validity()
    --self:send_message(const.SC_MESSAGE_LUA_BAG_GET_ALL, {result = 0})
    self:imp_assets_write_to_sync_dict(syn_data)
    self:imp_equipment_write_to_sync_dict(syn_data)
end

local function on_item_use(self, input, syn_data)
    if input.item_pos == nil or input.count == nil then
        return
    end
    local item = self:get_item_by_pos(input.item_pos)
    if item == nil or item.cnt < input.count then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = const.error_item_not_enough})
        return
    end

    if input.item_id ~= nil and input.item_id ~= item.id then
        return
    end

    local item_config = common_item_config.get_item_config(item.id)
    if self.level < item_config.LevelLimit then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="UseBagItemReply",result=const.error_level_not_enough})
        return
    end

    local result = item_effect_manager.effect(item.id,self,self,input.count)
    flog("tmlDebug","imp_assets.on_item_use error:"..result)
    if result == 0 then
        self.inventory:remove_item_by_pos(input.item_pos, input.count)
        self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = result})
        self:imp_assets_write_to_sync_dict(syn_data)

        if item_config ~= nil then
            if item_config.Type == const.TYPE_SEAL_ENERGY then
                self:imp_seal_write_to_sync_dict(syn_data,true)
            elseif item_config.Type == const.TYPE_CLEAR_PK_VALUE then
                self:imp_pk_write_to_sync_dict(syn_data)
            elseif item_config.Type == const.TYPE_SCALE_MODEL or item_config.Type == const.TYPE_DISGUISE_MODEL or item_config.Type == const.TYPE_STEALTHY_CHARACTER then
                self:imp_player_write_to_sync_dict(syn_data)
            end
        end
    elseif result ~= const.error_data then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = result})
    else
        flog("tmlDebug","imp_assets.on_item_use error_data:")
    end
end

local function on_item_split(self, input, syn_data)
    local item_pos = input.item_pos
    local count = input.count
    if count <= 0 then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_SPLIT, {result = const.error_count_can_not_negative})
    end
    local item = self.inventory:get_item_by_pos(item_pos)
    if item == nil then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_SPLIT, {result = const.error_no_item_in_pos})
    end
    local last_num = item:get_count() - count
    if last_num <= 0 then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_SPLIT, {result = const.error_split_number_out_range})
    end
    local first_empty = self.inventory:get_first_empty()
    if first_empty == nil then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_SPLIT, {result = const.error_no_empty_cell})
    end
    local item_id = item:get_id()
    self.inventory:clear_by_pos(item_pos)
    local result = self.inventory:add_item_by_pos(item_pos, item_id, last_num)
    if result ~= 0 then
        flog("error", "on_item_split add_item_by_pos error "..result)
    end
    result = self.inventory:add_item_by_pos(first_empty, item_id, count)
    if result ~= 0 then
        flog("error", "on_item_split add_item_by_id error "..result)
    end

    self:send_message(const.SC_MESSAGE_LUA_ITEM_SPLIT, {result = result})
    self:imp_assets_write_to_sync_dict(syn_data)
end

local function on_item_sell(self, input, syn_data)
    local item_pos_list = input.item_pos_list

    local result = 0
    local total_price = 0
    for i, v in pairs(item_pos_list) do
        local item = self.inventory:get_item_by_pos(v)
        if item == nil then
            result = const.error_no_item_in_pos
            break
        end
        local item_id = item:get_id()
        if item_scheme[item_id] == nil then
            flog("error", "on_item_sell: no item "..item_id)
            result = const.error_item_id_not_match
            break
        end

        local price = item_scheme[item_id].Price
        local can_recycle = item_scheme[item_id].CanRecycle
        if can_recycle ~= 1 then
            result = const.error_item_can_not_sell
            break
        end
        local count = item:get_count()
        total_price = total_price + price * count
    end

    --flog("error", "on_item_sell: total_price"..total_price)
    self:send_message(const.SC_MESSAGE_LUA_ITEM_SELL, {result = result})
    if result == 0 then
        for i, v in pairs(item_pos_list) do
            local del_item = self.inventory:clear_by_pos(v)
            if del_item.attrib.Quality >= const.RARE_GOODS_LEVEL then
                if del_item.uid ~= nil then
                    flog("salog", string_format("Equipment %d sold uid %s", del_item.id, del_item.uid), self.actor_id)
                else
                    flog("salog", string_format("Item %d sold count %s", del_item.id, del_item.cnt), self.actor_id)
                end
            end
        end

        self:add_resource("bind_coin", total_price)
    end

    self:imp_assets_write_to_sync_dict(syn_data)
end

local function on_bag_arrange(self, input, syn_data)
    local result = self.inventory:arrange()
    self:send_message(const.SC_MESSAGE_LUA_BAG_ARRANGE, {result = result})
    self:imp_assets_write_to_sync_dict(syn_data)
end

local function on_cell_unlock(self, input, syn_data)
    local result = self.inventory:unlock_cell(input.cell_pos)
    if result == 0 then
        self:imp_assets_write_to_sync_dict(syn_data)
    end
    self:send_message(const.SC_MESSAGE_LUA_UNLOCK_CELL, {result = result})
end

local function _calc_tili(self)
    local delta_time = _get_now_time_second() - self.tili_last_refresh_time

    --体力计算
    local tili_addition = math_floor(delta_time / SECOND_PER_TILI)
    local truly_addition = tili_addition
    local new_tili = self.inventory:get_resource("tili") + truly_addition
    if new_tili >= self.tili_ceil then
        truly_addition = self.tili_ceil - self.inventory:get_resource("tili")
        if truly_addition < 0 then
            truly_addition = 0
        end
    end
    self.inventory:add_resource("tili", truly_addition)
    self.tili_last_refresh_time = self.tili_last_refresh_time + tili_addition * SECOND_PER_TILI
end

local function _get_tili_price(buy_times)
    buy_times = buy_times + 1
    local price
    for i, v in ipairs(tili_price_table) do
        if buy_times < v.LowerLimit then
            price = tili_price_table[i - 1].CostIngot
            break
        end
    end
    if price == nil then
        price = tili_price_table[#tili_price_table].CostIngot
    end
    return price
end

local function on_tili_buy(self, input, syn_data)
    _calc_tili(self)
    self.dungeon_refresher:check_refresh(self)
    local tili_item_id = const.RESOURCE_NAME_TO_ID.tili
    local ingot_item_id = const.RESOURCE_NAME_TO_ID.ingot

    local price = _get_tili_price(self.tili_buy_times)
    if self:is_enough_by_id(ingot_item_id, price) then
        self.tili_buy_times = self.tili_buy_times + 1
        self:remove_item_by_id(ingot_item_id, price)
        self:add_new_rewards({[tili_item_id] = TILI_BUY_COUNT})
        self:send_message(const.SC_MESSAGE_LUA_TILI_BUY , {result = 0})
        self:imp_assets_write_to_sync_dict(syn_data)
    else
        self:send_message(const.SC_MESSAGE_LUA_TILI_BUY , {result = const.error_item_not_enough})
    end
end

--处理玩家升级时的一些属性处理
local function _player_level_up(self)
    self:imp_chat_upgrade_level()
    self:arena_player_level_up()
    self:update_task_when_player_level_up()
    self:recalc()
    self:_set("tili_ceil", level_scheme[self.level].Vit)
    self:update_player_value_to_rank_list("level")
    local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:SetLevel(self.level)
    end
    flog("salog", "Player level up "..self.level, self.actor_id)
end

local function on_manual_level_up(self, input, syn_data)
    if self.level >= LEVEL_CEIL then
        self:send_message(const.SC_MESSAGE_LUA_LEVEL_UP , {result = const.error_level_reach_ceil})
        return
    end

    local exp = self.inventory:get_resource("exp")
    local level_exp = level_scheme[self.level].Exp
    if exp >= level_exp then
        self.inventory:remove_resource("exp", level_exp)
        self:_set("level", self.level + 1)
        _player_level_up(self)
        self:imp_assets_write_to_sync_dict(syn_data)
        self:imp_property_write_to_sync_dict(syn_data)
        self:send_message(const.SC_MESSAGE_LUA_LEVEL_UP , {result = 0})
    else
        self:send_message(const.SC_MESSAGE_LUA_LEVEL_UP , {result = const.error_exp_not_enough})
    end
end

local function _refresh_data(self)
    flog("syzDebug", "imp_assets  _refresh_data")
    self.tili_buy_times = 0
    self.kill_boss_score = 0
end

--根据dict初始化
function imp_assets.imp_assets_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.inventory:init_from_dict(dict)
    self.wealth = self.inventory:get_resource("coin")
    _calc_tili(self)
    self.kill_boss_score = math.ceil(self.kill_boss_score)

    if dict.assets_last_refresh_time == nil then
        dict.assets_last_refresh_time = _get_now_time_second()
    end
    self.assets_refresher = daily_refresher(_refresh_data, dict.assets_last_refresh_time, const.REFRESH_HOUR)
    self.assets_refresher:check_refresh(self)
end

function imp_assets.imp_assets_init_from_other_game_dict(self,dict)
    self:imp_assets_init_from_dict(dict)
end

function imp_assets.imp_assets_write_to_dict(self, dict)
    _calc_tili(self)
    self.assets_refresher:check_refresh(self)
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
    self.inventory:write_to_dict(dict)
    dict.assets_last_refresh_time = self.assets_refresher:get_last_refresh_time()
end

function imp_assets.imp_assets_write_to_other_game_dict(self,dict)
    self:imp_assets_write_to_dict(dict)
end

function imp_assets.imp_assets_write_to_sync_dict(self, dict, only_res)
    _calc_tili(self)
    self.assets_refresher:check_refresh(self)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end

    dict.drug_cds = table.copy(self.drug_cds)
    self.inventory:write_to_dict(dict, only_res)
end

function imp_assets.get_main_dungeon_win_reward(self, dungeon_id)
    if type(dungeon_id) == "string" then
        dungeon_id = tonumber(dungeon_id)
    end
    local dun_data = normal_transcript[dungeon_id]
    if dun_data == nil then
        flog("error", "Dungeon id "..dungeon_id.." not exist!")
        return
    end
    local rewards = {}
    for i = 1, 4 do
        local rwd = dun_data["Reward"..i]
        if not table.isEmptyOrNil(rwd) then
            rewards[rwd[1]] = rwd[2]
        end
    end
    return rewards
end

local function _get_exp(self, count, is_from_monster)
    local exp_current = self.inventory:get_resource("exp")
    local exp = exp_current + count
    local level_exp = level_scheme[self.level].Exp
    local is_level_up = false
    while exp > level_exp do
        if self.level >= LEVEL_MANUAL_UPGRADE then   --大于手动升级等级不自动升级
            break
        end
        exp = exp - level_exp
        self:_set("level", self.level + 1)
        level_exp = level_scheme[self.level].Exp
        is_level_up = true
    end

    if exp_current < exp then
        self:add_resource("exp", exp - exp_current)
    else
        self:remove_resource("exp", exp_current - exp)
    end
    if is_level_up then
        _player_level_up(self)
    end
end

local function _before_add_item(self, items)
    for id, count in pairs(items) do
        if id == resource_name_to_id.tili then
            _calc_tili(self)
        elseif id == resource_name_to_id.faction_fund then
            local input = {func_name = "add_faction_fund", count = count, faction_id = self.faction_id}
            self:send_message_to_faction_server(input)
        elseif id == resource_name_to_id.vote_num then
            items[id] = nil
            self.self_vote_num = self.self_vote_num + count
        elseif id == resource_name_to_id.country_fund then
            local input = {func_name = "add_country_fund", count = count, country = self.country}
            self:send_message_to_country_server(input)
        end
    end
end

local function _after_add_item(self, items, last_items)
    for id, count in pairs(items) do
        if id == resource_name_to_id.exp then
            _get_exp(self, 0)
        elseif id == resource_name_to_id.coin then
            self.wealth = self.inventory:get_resource("coin")
            self:update_player_value_to_rank_list("wealth")
            flog("salog", string_format("Coin get %d, ingot current:", count, self.wealth), self.actor_id)
        end

        local item_config = common_item_config.get_item_config(id)
        if item_config.Quality >= const.RARE_GOODS_LEVEL then
            local resource_name = const.RESOURCE_ID_TO_NAME[id]
            if resource_name ~= nil then
                flog("salog", string_format("Resource %s get %d, current:", resource_name, count, self.inventory:get_resource(resource_name)), self.actor_id)
            else
                flog("salog", string_format("Item %d get %d", id, count), self.actor_id)
            end
        end
    end

    -- 剩下未入背包的邮件发送
    if not table.isEmptyOrNil(last_items) then
        local player_id = self.actor_id
        local attachment = {}
        for item_id, count in pairs(last_items) do
            table.insert(attachment, {item_id = item_id, count = count})
        end
        mail_helper.send_mail(player_id, const.MAIL_IDS.OVER_FLOW_ITEMS, attachment,_get_now_time_second(),{})
    end

    --更新任务信息
    self:update_task_collect()
end

function imp_assets.add_new_rewards(self, rewards)
    _before_add_item(self, rewards)

    local result, last_items= self.inventory:add_new_rewards(rewards, self.actor_id)

    _after_add_item(self, rewards, last_items)
    return result
end

function imp_assets.get_item_by_pos(self, pos)
    return self.inventory:get_item_by_pos(pos)
end

function imp_assets.clear_by_pos(self, pos)
    return self.inventory:clear_by_pos(pos)
end

function imp_assets.add_item(self, pos, new_item)
    return self.inventory:add_item(pos, new_item)
end

function imp_assets.get_first_empty(self)
    return self.inventory:get_first_empty()
end

function imp_assets.gm_add_item(self, item_id, item_count, syn_data)
    local rewards = {[item_id] = item_count}
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards)
    self:add_new_rewards(rewards)
    self:imp_assets_write_to_sync_dict(syn_data)
end

function imp_assets.gm_set_resource(self, name, value, syn_data)
    local cur_value = self.inventory:get_resource(name)
    if cur_value < value then
        self:add_resource(name, value - cur_value)
    else
        self:remove_resource(name, cur_value - value)
    end
    self:imp_assets_write_to_sync_dict(syn_data)
    return 0
end

function imp_assets.gm_set_player_level(self, level, syn_data)
    flog("syzDebug", "imp_assets.gm_set_player_level "..level)
    if level > LEVEL_CEIL then
        return
    end
    self:_set("level", level)
    _player_level_up(self)
    self:imp_property_write_to_sync_dict(syn_data)
end

function imp_assets.is_enough_by_id(self, item_id, count)
    if const.RESOURCE_ID_TO_NAME[item_id] == "tili" then
        _calc_tili(self)
    end

    return self.inventory:is_enough_by_id(item_id, count)
end

function imp_assets.remove_item_by_id(self, item_id, count)
    if item_id == resource_name_to_id.tili then
        _calc_tili(self)
    end

    local rst = self.inventory:remove_item_by_id(item_id, count, self.actor_id)
    if rst ~= 0 then
        flog("error", string_format("imp_assets.remove_item_by_id fail %d = %d, rst %d", item_id, count, rst))
    end

    if item_id == resource_name_to_id.coin then
        self.wealth = self.inventory:get_resource("coin")
        self:update_player_value_to_rank_list("wealth")
        flog("salog", string_format("Coin use %d, ingot current:", count, self.wealth), self.actor_id)
    end

    local item_config = common_item_config.get_item_config(item_id)
    if item_config.Quality >= const.RARE_GOODS_LEVEL then
        local resource_name = const.RESOURCE_ID_TO_NAME[item_id]
        if resource_name ~= nil then
            flog("salog", string_format("Resource %s remove %d, current:", resource_name, count, self.inventory:get_resource(resource_name)), self.actor_id)
        else
            flog("salog", string_format("Item %d remove %d", item_id, count), self.actor_id)
        end
    end
    --更新任务信息
    self:update_task_collect()
end

function imp_assets.add_item_by_id(self, item_id, count)
    self:add_new_rewards({[item_id] = count})
    return
end

function imp_assets.remove_item_by_pos(self, pos, count)
    return self.inventory:remove_item_by_pos(pos, count)
end

function imp_assets.is_resource_enough(self, resource_name, count)
    local item_id = const.RESOURCE_NAME_TO_ID[resource_name]
    return self:is_enough_by_id(item_id, count)
end

function imp_assets.remove_resource(self, resource_name, count)
    local item_id = const.RESOURCE_NAME_TO_ID[resource_name]
    return self:remove_item_by_id(item_id, count)
end

function imp_assets.add_resource(self, resource_name, count)
    local item_id = const.RESOURCE_NAME_TO_ID[resource_name]
    return self:add_item_by_id(item_id, count)
end

function imp_assets.get_item_count_by_id(self,item_id)
    return self.inventory:get_item_count_by_id(item_id)
end

function imp_assets.get_empty_slot_number(self)
    return self.inventory:get_empty_slot_number()
end

function imp_assets.is_all_cost_enough(self, cost)
    local items_lack = {}
    local is_enough = true
    for item_id, count in pairs(cost) do
        if not self:is_enough_by_id(item_id, count) then
            is_enough = false
            table.insert(items_lack, item_id)
        end
    end

    return is_enough, items_lack
end

function imp_assets.add_new_transport_banner(self,item_id,scene_id,posX,posY,posZ)
    return self.inventory:add_new_transport_banner(item_id,scene_id,posX,posY,posZ)
end

function imp_assets.use_transport_banner(self,pos)
    return self.inventory:use_transport_banner(pos)
end

function imp_assets.on_user_transport_banner(self,input,sync_data)
    if input.item_pos == nil then
        return
    end
    if self:is_in_normal_scene() == false then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = const.error_locate_in_dungeon})
        return
    end
    local result,scene_id,x,y,z = self:use_transport_banner(input.item_pos)
    if result ~= 0 then
        if result ~= const.error_data then
            self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = result})
            return
        end
        return
    end
    if scene_id == nil or x == nil or y == nil or z == nil then
        return
    end
    local scene = normal_scene_manager.find_scene(scene_id)
    if scene == nil then
        return
    end
    if self.scene_id == scene_id then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",random_transport = true,posX=x,posY=y,posZ=z})
    else
        self.scene_id = scene_id
        self.posX = x/100
        self.posY = y/100
        self.posZ = z/100
        local info = {}
        self:imp_player_write_to_sync_dict(info)
        self:imp_assets_write_to_sync_dict(info)
        self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
        self:player_enter_common_scene()
    end
end

function imp_assets.on_user_nil_transport_banner(self,input,sync_data)
    if input.item_pos == nil or input.item_id == nil then
        return
    end
    local item = self:get_item_by_pos(input.item_pos)
    if item == nil or item.cnt < 1 then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = const.error_item_not_enough})
        return
    end
    if input.item_id ~= nil and input.item_id ~= item.id then
        return
    end
    if self:get_empty_slot_number() < 1 then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = const.error_no_empty_cell})
        return
    end
    if item.attrib.Type ~= const.TYPE_NIL_TRANSPORT_BANNER then
        return
    end
    local banner_id = tonumber(item.attrib.Para2)
    if self:is_in_normal_scene() == true then
        local scene_id = self:get_aoi_scene_id()
        local x,y,z = self:get_pos()
        if input.posX ~= nil and input.posX ~= nil and input.posX ~= nil and input.scene_id ~= nil and input.scene_id == scene_id then
            x = input.posX
            y = input.posY
            z = input.posZ
        end
        x = math_floor(x*100)
        y = math_floor(y*100)
        z = math_floor(z*100)
        self:add_new_transport_banner(banner_id,scene_id,x,y,z)
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",locate_position = true,scene_id=scene_id,posX=x,posY=y,posZ=z})
    else
        self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = const.error_locate_in_dungeon})
        return
    end
    self:remove_item_by_pos(input.item_pos,1)
    self:imp_assets_write_to_sync_dict(sync_data)
end

function imp_assets.is_item_addable(self, item_id, count)
    return self.inventory:is_item_addable(item_id, count)
end

function imp_assets.on_use_effect_item(self,input,sync_data)
    if input.item_pos == nil or input.posX == nil or input.posY == nil or input.posZ == nil then
        return
    end
    local item = self:get_item_by_pos(input.item_pos)
    if item == nil or item.cnt < 1 then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = const.error_item_not_enough})
        return
    end

    if item.attrib.Type ~= const.TYPE_EFFECT_ITEM then
        return
    end
    self:play_item_effect(item.attrib.Para1,tonumber(item.attrib.Para2),input.posX,input.posY,input.posZ)
    self:remove_item_by_pos(input.item_pos,1)
    self:imp_assets_write_to_sync_data(sync_data)
end

function imp_assets.on_giving_gift_to_friend(self,input,sync_data)
    if input.item_id == nil or input.item_count == nil or input.item_count < 1 or input.actor_id == nil then
        return
    end
    local item_config = common_item_config.get_item_config(input.item_id)
    if item_config == nil or item_config.Type ~= const.TYPE_FRIEND_VALUE then
        return
    end
    if self:get_item_count_by_id(input.item_id) < input.item_count then
        self:send_message(const.SC_MESSAGE_LUA_ITEM_USE, {result = const.error_item_not_enough})
        return
    end
    flog("info",string_format("imp_assets.on_giving_gift_to_friend %s(%s) giving gift(%d,%d) %s",self.actor_name,self.actor_id,input.item_id,input.item_count,input.actor_id))
    local friend_value = math_floor(tonumber(item_config.Para1))
    local flower_count = math_floor(tonumber(item_config.Para2))
    self:send_message_to_friend_server({func_name="on_giving_gift",receive_actor_id=input.actor_id,flower_count=flower_count*input.item_count,friend_value=friend_value*input.item_count,item_id=input.item_id,item_count=input.item_count,item_name=common_item_config.get_item_name(input.item_id)})
end

local function _exp_of_monster(monster_level, monster_type, exp_percent, scene_exp_rate)
    local config = levels_scheme[monster_level]
    local base_exp = config.Moster
    local exp_cnt = base_exp * scene_exp_rate
    local monster_type_rate = monster_type_scheme[monster_type].exp
    if monster_type_rate == nil then
        flog("error", "error monster_type "..monster_type)
    end
    exp_cnt = exp_cnt * monster_type_rate / 100
    exp_cnt = exp_cnt * exp_percent / 100
    return exp_cnt
end


local function _get_exp_from_monster(self, monster_level, monster_type, exp_percent, monster_id)
    local exp_cnt = _exp_of_monster(monster_level, monster_type, exp_percent, self.kill_monster_exp_rate)

    local config = levels_scheme[self.level]
    local pet_exp = config.PetkillExp
    self:fight_pet_get_exp(pet_exp)

    if self.exp_from_monster_daily > config.ExpMax then
        exp_cnt = exp_cnt * DECAY_RATE
    end

    if self.exp_from_monster_daily > config.ExpMaxMax then
        exp_cnt = 0
        self:send_system_message_by_id(const.SYSTEM_MESSAGE_ID.monster_exp_max, nil, nil)
        return
    end

    exp_cnt = math_floor(exp_cnt)
    _get_exp(self, exp_cnt)

    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, {[const.RESOURCE_NAME_TO_ID.exp] = exp_cnt})
    self:imp_chat_get_monster_exp(exp_cnt)
    self.exp_from_monster_daily = exp_cnt + self.exp_from_monster_daily

    self:imp_activity_kill_monster(monster_type, monster_id)
end

local function _share_exp_to_team_members(self, monster_level, monster_type, monster_id)
    local team_members_number = self:get_team_members_number()
    if team_members_number > 1 then
        local exp_percent = common_parameter_formula_config.team_member_get_exp(100, team_members_number)
        local team_members = self:get_team_members()

        local input_data = {func_name = "on_get_exp_from_team_member", exp_percent = exp_percent, monster_level = monster_level, monster_type= monster_type, monster_id = monster_id}
        for id, _ in pairs(team_members) do
            local player = self:get_online_user(id)
            if id ~= self.actor_id and player ~= nil and self:get_aoi_scene_id() == player:get_aoi_scene_id() then
                player:on_get_exp_from_team_member(input_data)
            end
        end
    end
end

function imp_assets.get_exp_from_monster(self, monster_level, monster_type, monster_id)
    local puppet = self:get_puppet()
    local exp_percent = 100
    if puppet ~= nil then
        exp_percent = SkillAPI.ChangeBattleExp(puppet, 100)
    else
        flog("error", "imp_assets.get_exp_from_monster find puppet fail!")
    end

    _get_exp_from_monster(self, monster_level, monster_type, exp_percent, monster_id)

    _share_exp_to_team_members(self, monster_level, monster_type, monster_id)
end

function imp_assets.on_remote_get_exp_from_monster(self, input)
    local monster_level = input.monster_level
    local monster_type = input.monster_type
    local exp_percent = input.exp_percent
    local monster_id = input.monster_id
    _get_exp_from_monster(self, monster_level, monster_type, exp_percent, monster_id)

    _share_exp_to_team_members(self, monster_level, monster_type, monster_id)
end

function imp_assets.on_get_exp_from_team_member(self, input)
    local exp_percent = input.exp_percent
    local monster_level = input.monster_level
    local monster_type = input.monster_type
    local monster_id = input.monster_id

    _get_exp_from_monster(self, monster_level, monster_type, exp_percent, monster_id)
end

function imp_assets.get_drop_manager(self)
    return no_dungeon_drop_manager
end


function imp_assets.on_get_monster_drop(self, input)
    if not self:enable_get_reward(self.dungeon_in_playing) then
        return
    end
    local drop_data = input.drop_data
    local dungeon_type = self:get_dungeon_type(self.dungeon_in_playing)

    local item_id = drop_data.item_id
    local count = drop_data.count
    local rewards = {[item_id] = count }
    self:add_new_rewards(rewards)
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards)
    self:broadcast_to_aoi_include_self(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "PickDropRet", result = 0, drop_entity_id = drop_data.id, actor_id = self.actor_id, position = drop_data.position})

    if drop_data.boss_reward then
        self.assets_refresher:check_refresh(self)
        local price = self.get_item_price(drop_data.item_id, const.RESOURCE_NAME_TO_ID.ingot)
        self.kill_boss_score = math.ceil(self.kill_boss_score + price)
    end
end

function imp_assets.get_boss_anger_value(self, anger_value)
    self.assets_refresher:check_refresh(self)

    local rate_index = get_sequence_index(anger_rate_scheme, "BossScore", self.kill_boss_score)
    local rate = anger_rate_scheme[rate_index].Rate
    anger_value = math.floor(anger_value * rate / 100)
    return anger_value
end

function imp_assets.gm_add_player_equipment(self,syn_data)
    local rewards = {[2001] = 1,[2002] = 1,[2003] = 1,[2004] = 1,[2005] = 1,[2006] = 1,[2007] = 1,[2008] = 1,[2009] = 1,[2010] = 1,[2011] = 1,[2012] = 1,[2013] = 1,[2014] = 1,[2015] = 1,[2016] = 1,[2017] = 1,[2018] = 1,[2019] = 1,[2020] = 1,[2021] = 1,[2022] = 1,[2023] = 1,[2024] = 1,[2025] = 1,[2026] = 1}
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards)
    self:add_new_rewards(rewards)
    self:imp_assets_write_to_sync_dict(syn_data)
end

function imp_assets.get_item_from_global(self, input)
    local rewards = input.rewards
    self:add_new_rewards(rewards)
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards)
end

register_message_handler(const.CS_MESSAGE_LUA_BAG_GET_ALL, on_bag_get_all)
register_message_handler(const.CS_MESSAGE_LUA_ITEM_USE, on_item_use)
register_message_handler(const.CS_MESSAGE_LUA_ITEM_SPLIT, on_item_split)
register_message_handler(const.CS_MESSAGE_LUA_ITEM_SELL, on_item_sell)
register_message_handler(const.CS_MESSAGE_LUA_BAG_ARRANGE, on_bag_arrange)
register_message_handler(const.CS_MESSAGE_LUA_UNLOCK_CELL, on_cell_unlock)
register_message_handler(const.CS_MESSAGE_LUA_TILI_BUY, on_tili_buy)
register_message_handler(const.CS_MESSAGE_LUA_LEVEL_UP, on_manual_level_up)

imp_assets.__message_handler = {}
imp_assets.__message_handler.on_bag_get_all = on_bag_get_all
imp_assets.__message_handler.on_item_use = on_item_use
imp_assets.__message_handler.on_item_split = on_item_split
imp_assets.__message_handler.on_item_sell = on_item_sell
imp_assets.__message_handler.on_bag_arrange = on_bag_arrange
imp_assets.__message_handler.on_cell_unlock = on_cell_unlock
imp_assets.__message_handler.on_tili_buy = on_tili_buy
imp_assets.__message_handler.on_manual_level_up = on_manual_level_up

--test
if false then
    flog("syzDebug", "11111111111111")
    local a = CreateImpAssets()
    a:get_main_dungeon_win_reward(190)
    local b = CreateImpAssets()
    b:get_main_dungeon_win_reward(1)
end


return imp_assets