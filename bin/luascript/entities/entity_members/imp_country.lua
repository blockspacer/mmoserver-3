--------------------------------------------------------------------
-- 文件名:	imp_country.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/9 0009
-- 描  述:	玩家的国家模块
--------------------------------------------------------------------

local const = require "Common/constant"
local flog = require "basic/log"
local scheme_noble_rank = require("data/pvp_country").NobleRank
local scheme_weekly_noble_rank = require("data/pvp_country").NobleRank2
local scheme_war_rank = require("data/pvp_country").Rank
local daily_refresher = require("helper/daily_refresher")
local weekly_refresher = require("helper/weekly_refresher")
local scheme_basic = require "basic/scheme"
local pvp_country_config = require "configs/pvp_country_config"
local onlinerole = require "onlinerole"
local game_id = _get_serverid()

local DAILY_REFRESH_HOUR,DAILY_REFRESH_MIN = scheme_basic.get_time_from_string(require("data/pvp_country").Parameter[1].Value)   --每日刷新时间
local WEEKLY_REFRESH_DAY = require("data/pvp_country").Parameter[9].Value        --周榜刷新日
WEEKLY_REFRESH_DAY = math.floor(tonumber(WEEKLY_REFRESH_DAY))
local WEEKLY_REFRESH_HOUR,WEEKLY_REFRESH_MIN = scheme_basic.get_time_from_string(require("data/pvp_country").Parameter[10].Value)  --每周刷新时间
local SAUL_BUFF_CONSUME_RATE = require("data/pvp_country").Parameter[4].Value    --战魂buff消耗速率
SAUL_BUFF_CONSUME_RATE = math.floor(tonumber(SAUL_BUFF_CONSUME_RATE))
local MAX_WAR_RANK = require("data/pvp_country").Parameter[8].Value         --当前开放最高战阶
MAX_WAR_RANK = math.floor(tonumber(MAX_WAR_RANK))
local NO_PRESTIGE_INTERVAL = require("data/pvp_country").Parameter[2].Value         --杀死同一玩家不获取声望的间隔
NO_PRESTIGE_INTERVAL = math.floor(tonumber(NO_PRESTIGE_INTERVAL) / 1000)
local scheme_plunder_prestige = require("data/pvp_country").PlunderPrestige
local ATTENUATION = require("data/pvp_country").Parameter[6].Value         --威望衰减参数，百分制。
ATTENUATION = tonumber(ATTENUATION) / 100
local BATTLE_SAUL_SKILL_ID = '513'
local feats_from_kill_formula = require("configs/common_parameter_formula_config").feats_from_kill_formula

local params = {
    prestige = {db = true, sync = true},                                   --威望值
    donation = {db = true, sync = true},                                   --捐献值
    weekly_donation = {db = true, sync = true},                            --周捐献值
    donation_rank = {db = true, sync = true},                              --捐献排名
    weekly_donation_rank = {db = true, sync = true},                       --周捐献排名
    noble_rank = {db = true, sync = true, default = const.LAST_NOBLE_RANK}, --爵位
    weekly_noble_rank = {db = true, sync = true},                          --周捐献等级（类似于爵位）
    war_rank = {db = true, sync = true, default = 1},                      --战阶
    is_get_war_rank_reward = {db = true, sync=true, default = false},      --是否领取战阶奖励
    dead_times_today = {db = true, sync = false},                           --今日战死次数
    prestige_get_today = {db = true, sync = false},                         --今日获得的威望值
    battle_saul_remain_time = {db = false, sync = true, default = false},   --战魂buff状态剩余时间
    spritual_weekly_addition = {db = true, sync = false},                   --周榜灵力增益
    spritual_total_addition = {db = true, sync = false},                    --总榜灵力增益
    self_vote_num = {db = true, sync = false},                              --已获得的选票数
}

local imp_country = {}
imp_country.__index = imp_country

setmetatable(imp_country, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_country.__params = params

function imp_country.__ctor(self)
    self.kill_list = {}
    self.liked_officer_list = {}
end

local function _daily_refresh(self)
    flog("info", "imp_country.lua  _daily_refresh")
    self:_set("is_get_war_rank_reward", false)
    self:_set("dead_times_today", 0)
    if self.war_rank < MAX_WAR_RANK then
        local upgrade_need = scheme_war_rank[self.war_rank + 1].RequirePrestige
        while self.prestige > upgrade_need do
            local next_war_rank_config = scheme_war_rank[self.war_rank + 1]
            if self.level < next_war_rank_config.Lv then
                break
            end

            self:_set("prestige", self.prestige - upgrade_need)
            self:_set("war_rank", self.war_rank + 1)
            upgrade_need = scheme_war_rank[self.war_rank + 1].RequirePrestige
            self:update_player_value_to_rank_list("war_rank")

            if next_war_rank_config.Salary > 0 then
                local output = {func_name = "on_war_rank_upgrade", war_rank = self.war_rank, actor_id = self.actor_id, country = self.country}
                self:send_message_to_country_server(output)
            end
        end
    end
    self:_set("prestige_get_today", 0)
end

local function _weekly_refresh(self)
    self.weekly_donation = 0
    self.weekly_donation_rank = -1
    self.weekly_noble_rank = -1
end

local function _election_refresh(self)
    self.self_vote_num = 0
end

--根据dict初始化
function imp_country.imp_country_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.liked_officer_list = dict.liked_officer_list or {}

    local current_time = _get_now_time_second()
    dict.country_daily_last_refresh_time = dict.country_daily_last_refresh_time or current_time
    self.country_daily_refresher = daily_refresher(_daily_refresh, dict.country_daily_last_refresh_time, DAILY_REFRESH_HOUR, DAILY_REFRESH_MIN)
    self.country_daily_refresher:check_refresh(self)

    dict.country_weekly_last_refresh_time = dict.country_weekly_last_refresh_time or current_time
    self.country_weekly_refresher = weekly_refresher(_weekly_refresh, dict.country_weekly_last_refresh_time, 2, WEEKLY_REFRESH_HOUR, WEEKLY_REFRESH_MIN)
    self.country_weekly_refresher:check_refresh(self)

    dict.election_last_refresh_time = dict.election_last_refresh_time or current_time
    local election_wday, election_hour, election_min = pvp_country_config.get_count_votes_time()
    self.election_refresher = weekly_refresher(_election_refresh, dict.election_last_refresh_time, election_wday, election_hour, election_min)
    self.election_refresher:check_refresh(self)
end

function imp_country.imp_country_init_from_other_game_dict(self,dict)
    self:imp_country_init_from_dict(dict)
end

function imp_country.imp_country_write_to_dict(self, dict)
    self.country_daily_refresher:check_refresh(self)
    self.country_weekly_refresher:check_refresh(self)
    self.election_refresher:check_refresh(self)
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
    dict.liked_officer_list = self.liked_officer_list

    dict.country_daily_last_refresh_time = self.country_daily_refresher:get_last_refresh_time()
    dict.country_weekly_last_refresh_time = self.country_weekly_refresher:get_last_refresh_time()
    dict.election_last_refresh_time = self.election_refresher:get_last_refresh_time()
end

function imp_country.imp_country_write_to_other_game_dict(self,dict)
    self:imp_country_write_to_dict(dict)
end

function imp_country.imp_country_write_to_sync_dict(self, dict)
    self.country_daily_refresher:check_refresh(self)
    self.country_weekly_refresher:check_refresh(self)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
end

function imp_country.on_donate_goods(self, input, syn_data)
    self.country_weekly_refresher:check_refresh(self)
    if input.coin_num == nil then
        flog("error", "imp_country.on_donate_goods : coin_num is nil")
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_item_not_enough, func_name = "DonateGoodsRet"})
    end
    if not self:is_enough_by_id(const.RESOURCE_NAME_TO_ID.bind_coin, input.coin_num) then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_item_not_enough, func_name = "DonateGoodsRet"})
    end
    self:remove_resource("coin", input.coin_num)
    self:imp_assets_write_to_sync_dict(syn_data)
    input.func_name = "donate_goods"
    input.donation = self.donation
    input.weekly_donation = self.weekly_donation
    input.actor_id = self.actor_id
    input.country = self.country
    input.actor_name = self.actor_name
    self:send_message_to_country_server(input)
end

local function _check_spritual(self, noble_rank, weekly_noble_rank)
    local need_recalc = false
    if noble_rank ~= nil then
        local new_addition = scheme_noble_rank[noble_rank].Gain
        self.spritual_total_addition = new_addition
        need_recalc = true
    end

    if weekly_noble_rank ~= nil then
        local new_weekly_addition = scheme_weekly_noble_rank[weekly_noble_rank].Gain
        self.spritual_weekly_addition = new_weekly_addition
        need_recalc = true
    end

    if need_recalc then
        self:recalc()
        local info = {}
        self:imp_property_write_to_sync_dict(info)
        self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
    end
end

function imp_country.DonateGoodsRet(self, input)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
    if input.result == 0 then
        _check_spritual(self, input.noble_rank, input.weekly_noble_rank)
        self.donation = input.donation
        self.noble_rank = input.noble_rank
        self.donation_rank = input.donation_rank

        self.weekly_donation = input.weekly_donation
        self.weekly_noble_rank = input.weekly_noble_rank
        self.weekly_donation_rank = input.weekly_donation_rank
    end
end


function imp_country.NobleRankChangeRet(self, input, sync_data)
    _check_spritual(self, input.noble_rank)
    self.noble_rank = input.noble_rank
    self.donation_rank = input.donation_rank
    self:imp_country_write_to_sync_dict(sync_data)
    self:imp_property_write_to_sync_dict(sync_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
end

function imp_country.WeeklyRankChangeRet(self, input, sync_data)
    _check_spritual(self, nil, input.weekly_noble_rank)
    self.weekly_noble_rank = input.weekly_noble_rank
    self.weekly_donation_rank = input.weekly_donation_rank
    self:imp_country_write_to_sync_dict(sync_data)
    self:imp_property_write_to_sync_dict(sync_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
end


function imp_country.on_get_war_rank_reward(self, input, syn_data)
    self.country_daily_refresher:check_refresh(self)
    if self.is_get_war_rank_reward then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetWarRankRewardRet", result = const.error_war_rank_reward_is_getted})
    end
    self:_set("is_get_war_rank_reward", true)
    local scheme_data = scheme_war_rank[self.war_rank]
    local rewards = {}
    for i = 1, 4 do
        local rwd = scheme_data["Reward"..i]
        if rwd ~= nil and rwd[1] ~= nil then
            rewards[rwd[1]] = rwd[2]
        end
    end
    self:add_new_rewards(rewards)
    local reply = {func_name = "GetWarRankRewardRet", rewards = rewards, result = 0}
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, reply)
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards)
    self:imp_assets_write_to_sync_dict(syn_data)
end


function imp_country.on_get_battle_saul(self, input, syn_data)
    self.country_daily_refresher:check_refresh(self)
    local upgrade_need = scheme_war_rank[self.war_rank + 1].RequirePrestige
    local saul_buff_consume_value = upgrade_need * SAUL_BUFF_CONSUME_RATE / 100
    if self.prestige < saul_buff_consume_value then
        return self:send_message( const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetBattleSaulRet", result = const.error_prestige_is_not_enough})
    end

    local entity_manager = self:get_entity_manager()
    local puppet = entity_manager.GetPuppet(self.actor_id)
    local skill_manager = puppet.skillManager
    local buff = skill_manager:FindBuff(BATTLE_SAUL_SKILL_ID)
    if buff ~= nil then
        return self:send_message( const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetBattleSaulRet", result = const.error_is_on_battle_saul})
    end
    self:_set("prestige", self.prestige - saul_buff_consume_value)
    skill_manager:AddBuff(BATTLE_SAUL_SKILL_ID)
    buff = skill_manager:FindBuff(BATTLE_SAUL_SKILL_ID)
    self.battle_saul_remain_time = math.floor(buff.remain_time)
    return self:send_message( const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "GetBattleSaulRet", result = 0, prestige = self.prestige, battle_saul_remain_time = self.battle_saul_remain_time})
end

function imp_country.on_get_donation_list(self, input, syn_data)
    self.country_weekly_refresher:check_refresh(self)
    input.func_name = "get_donation_list"
    input.actor_id = self.actor_id
    input.country = self.country
    local list_type = input.type or "total"

    if list_type == "total" then
        input.noble_rank = self.noble_rank
        input.donation = self.donation
    elseif list_type == "weekly" then
        input.noble_rank = self.weekly_noble_rank
        input.donation = self.weekly_donation
    else
        list_type = list_type or "nil"
        flog("error", "imp_country.on_get_donation_list : no type "..list_type)
    end
    self:send_message_to_country_server(input)
end

function imp_country.GetDonationListRet(self, input, syn_data)
    if input.result == 0 then
        if input.type == "total" then
            self.donation_rank = input.donation_rank
        elseif input.type == "weekly" then
            self.weekly_donation_rank = input.donation_rank
        else
            input.type = input.type or 'nil'
            flog("error", "imp_country.GetDonationListRet type error "..input.type)
        end
        self:imp_country_write_to_sync_dict(input)
        input.actor_name = self.actor_name
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
end

local function on_player_login(self, input, syn_data)
    if self.noble_rank ~= -1 then
        local input = {}
        input.func_name = "get_noble_rank"
        input.country = self.country
        input.actor_id = self.actor_id
        input.donation = self.donation
        input.weekly_donation = self.weekly_donation
        self:send_message_to_country_server(input)
    end
end

function imp_country.get_noble_rank_ret(self, input, syn_data)
    if input.result == 0 then
        _check_spritual(self, input.noble_rank, input.weekly_noble_rank)
        self.noble_rank = input.noble_rank
        self.donation_rank = input.donation_rank

        self.weekly_noble_rank = input.weekly_noble_rank
        self.weekly_donation_rank = input.weekly_donation_rank
    end
end

local function _on_be_killed(self, same_kill)
    self:_inc("dead_times_today")
    local output = {func_name = "BeKilledRet"}
    if same_kill then
        output.lost_prestige = 0
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return 0
    end
    local data_index = #scheme_plunder_prestige
    for i, v in ipairs(scheme_plunder_prestige) do
        if self.dead_times_today < v.Deathlowerlimit then
            data_index = i - 1
            break
        end
    end
    if data_index < 1 or data_index > #scheme_plunder_prestige then
        flog("error", "error in imp_country _on_be_killed: get wrong data_index "..data_index)
        return 0
    end
    local up_limit = scheme_plunder_prestige[data_index].Plunderuplimit
    local low_limit = scheme_plunder_prestige[data_index].Plunderlowlimit
    local rand_lost = math.random(low_limit, up_limit)
    local real_lost = rand_lost
    if self.prestige <= rand_lost then
        real_lost = self.prestige
    else
        real_lost = rand_lost
    end
    self:_dec("prestige", real_lost)

    local output = {func_name = "BeKilledRet"}
    output.prestige_lost = real_lost
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    return real_lost
end

function imp_country.imp_country_on_kill_player(self, enemy)
    if self:is_in_arena_scene() then    --竞技场不加声望
        return
    end
    if self.country == enemy.country then  --同阵营不加声望
        return
    end
    if enemy.type ~= const.ENTITY_TYPE_PLAYER then
        flog("error", "imp_country_on_kill_player: enemy is not player")
        return
    end

    local time_now = _get_now_time_second()
    local last_kill_time = self.kill_list[enemy.actor_id]
    local eneme_prestige_lost = 0
    local real_get = 0
    if last_kill_time ~= nil and time_now - last_kill_time < NO_PRESTIGE_INTERVAL then
        eneme_prestige_lost = _on_be_killed(enemy, true)
        real_get = 0
    else
        self.kill_list[enemy.actor_id] = time_now
        eneme_prestige_lost = _on_be_killed(enemy, false)
        local base_prestige = scheme_war_rank[enemy.war_rank].KillPrestige
        local scheme_data = scheme_war_rank[self.war_rank]
        local addition = scheme_data.PrestigeAddition / 100
        real_get = (eneme_prestige_lost + base_prestige)*(1 + addition)
        if self.prestige_get_today > scheme_data.PrestigeDecrease then      --每日威望达到一定值开始乘以衰减比例
            real_get = math.floor(real_get * ATTENUATION)
        end
    end
    self:_inc("prestige", real_get)
    local output = {func_name = "KillPlayerRet", prestige_get = real_get}
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)

    local feats_get = feats_from_kill_formula(real_get)
    self:add_resource("feats", feats_get)
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, {[const.RESOURCE_NAME_TO_ID.feats] = feats_get})
    self:send_system_message_by_id(const.SYSTEM_MESSAGE_ID.get_prestige, {}, {}, feats_get)

    local bag_dict = {}
    self:imp_assets_write_to_sync_dict(bag_dict)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE , bag_dict)

    self:finish_activity("pvp_fight")
end

function imp_country.on_get_country_basic(self)
    self.country_daily_refresher:check_refresh(self)
    self.country_weekly_refresher:check_refresh(self)
    local input = {}
    input.func_name = "get_country_basic"
    input.actor_id = self.actor_id
    input.country = self.country
    input.donation = self.donation
    self:send_message_to_country_server(input)
end

function imp_country.GetCountryBasicRet(self, input, syn_data)
    if input.result == 0 then
        self.noble_rank = input.noble_rank
        self.donation_rank = input.donation_rank
        input.country = self.country
        
        local try_func = function ()
            local skill_manager = self:get_entity_manager().GetPuppet(self.actor_id).skillManager
            local buff = skill_manager:FindBuff(BATTLE_SAUL_SKILL_ID)
            if buff ~= nil then
                self.battle_saul_remain_time = math.floor(buff.remain_time)
            else
                self.battle_saul_remain_time = 0
            end
        end
        local err_handler = function ()
            flog("error", "GetCountryBasicRet : FindBuff fail")
        end
        xpcall(try_func, err_handler)

        self:imp_country_write_to_sync_dict(input)
        self:imp_property_write_to_sync_dict(syn_data)
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, input)
end

function imp_country.on_change_country_declaration(self, input)
    input.func_name = "change_country_declaration"
    input.actor_id = self.actor_id
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.gm_war_rank_reward_reget(self)
    self:_set("is_get_war_rank_reward", false)
end

function imp_country.gm_set_war_rank(self, war_rank)
    self:_set("war_rank", war_rank)
    local war_rank_config = scheme_war_rank[self.war_rank + 1]
    if war_rank_config~= nil and war_rank_config.Salary > 0 then
        local output = {func_name = "on_war_rank_upgrade", war_rank = self.war_rank, actor_id = self.actor_id, country = self.country}
        self:send_message_to_country_server(output)
    end
end

function imp_country.gm_set_player_prestige(self, value)
    self:_set("prestige", value)
end

function imp_country.gm_start_qualification_office_candidate(self)
    local output = {func_name = "gm_start_qualification_office_candidate"}
    self:send_message_to_country_server(output)
end

function imp_country.gm_start_count_votes(self)
    local output = {func_name = "gm_start_count_votes"}
    self:send_message_to_country_server(output)
end

function imp_country.on_participate_in_election(self, input)
    input.func_name = "participate_in_election"
    input.actor_id = self.actor_id
    input.actor_name = self.actor_name
    input.war_rank = self.war_rank
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_get_election_basic_info(self, input)
    input.func_name = "get_election_basic_info"
    input.actor_id = self.actor_id
    input.self_vote_num = self.self_vote_num
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_modify_participate_declaration(self, input)
    input.func_name = "modify_participate_declaration"
    input.actor_id = self.actor_id
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_get_candidate_list(self, input)
    self.election_refresher:check_refresh(self)
    input.func_name = "get_candidate_list"
    input.self_vote_num = self.self_vote_num
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_vote_for_candidate(self, input)
    self.election_refresher:check_refresh(self)
    local vote_num = input.vote_num
    if self.self_vote_num < vote_num then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "VoteForCandidateRet", result = const.error_vote_number_not_enough})
    end
    self.self_vote_num = self.self_vote_num - vote_num
    input.func_name = "vote_for_candidate"
    input.self_vote_num = self.self_vote_num
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_vote_for_candidate_failed(self, input)
    local vote_num = input.vote_num
    self.self_vote_num = self.self_vote_num + vote_num
end

function imp_country.on_get_current_officers(self, input)
    input.func_name = "get_current_officers"
    input.actor_id = self.actor_id
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_get_history_officers(self, input)
    input.func_name = "get_history_officers"
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_give_like_to_history_officer(self, input)
    local index = input.index
    local officer_id = input.officer_id

    self.liked_officer_list[index] = self.liked_officer_list[index] or {}
    if self.liked_officer_list[index][officer_id] == 1 then
        local output = {func_name = "GiveLikeToHistoryOfficerRet"}
        output.result = const.error_history_officer_you_have_liked
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    self.liked_officer_list[index][officer_id] = 1
    input.func_name = "give_like_to_history_officer"
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_country_shop_discount(self, input)
    input.func_name = "country_shop_discount"
    input.officer_actor_id = self.actor_id
    input.officer_actor_name = self.actor_name
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_office_total_skill(self, input)
    input.func_name = "office_total_skill"
    input.actor_id = self.actor_id
    input.country = self.country
    input.actor_name = self.actor_name
    self:send_message_to_country_server(input)
end

local function add_buff_to_all_country_player(input)
    local country = input.country
    local buff_id = input.buff_id
    local all_user = onlinerole.get_all_user()
    for _, player in pairs(all_user) do
        if player.country == country then
            local entity_manager = player:get_entity_manager()
            local puppet = entity_manager.GetPuppet(player.actor_id)
            local skill_manager = puppet.skillManager
            skill_manager:AddBuff(buff_id)
        end
    end
end

function imp_country.on_office_halo_skill(self, input)
    input.func_name = "office_halo_skill"
    input.actor_id = self.actor_id
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.on_cast_office_skill(self, input)
    local skill_id = input.skill_id
    local puppet = self:get_puppet()
    local skillManager = puppet.skillManager
    if skillManager.skills[SlotIndex.Slot_OfficeSkill] == nil then
        skillManager:AddSkill(SlotIndex.Slot_OfficeSkill, tostring(skill_id), 1)
    end
    puppet:CastSkillToSky(SlotIndex.Slot_OfficeSkill)
end

function imp_country.gm_force_refresh_daily_data(self)
    _daily_refresh(self)
end

function imp_country.gm_change_election_state(self, state)
    if state == "reset" then
        state = nil
    end
    local output = {func_name = "gm_change_election_state", state = state}
    self:send_message_to_country_server(output)
end

function imp_country.on_pay_salary(self, input)
    input.func_name = "pay_salary"
    input.actor_id = self.actor_id
    input.country = self.country
    input.actor_name = self.actor_name
    self:send_message_to_country_server(input)
end

function imp_country.gm_clear_election_data(self)
    local output = {func_name = "gm_clear_election_data"}
    self:send_message_to_country_server(output)
end

function imp_country.on_get_salary(self, input)
    input.func_name = "get_salary"
    input.actor_id = self.actor_id
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.add_salary(self, input)
    local salary = input.salary
    local rewards = {[const.RESOURCE_NAME_TO_ID.coin] = salary}
    self:add_new_rewards(rewards)
    self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards)
end

function imp_country.gm_become_officer(self, office_id)
    local output = {func_name = "gm_become_officer" }
    output.office_id = office_id
    output.actor_id = self.actor_id
    output.actor_name = self.actor_name
    output.country = self.country
    self:send_message_to_country_server(output)
end

function imp_country.on_country_player_call_together(self, input)
    local result = self:is_operation_allowed("call_together")
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "CountryPlayerCallTogetherRet"})
    end

    local output = {func_name = "country_player_call_together" }
    output.actor_id = self.actor_id
    output.country = self.country
    output.actor_name = self.actor_name
    output.scene_id = self:get_aoi_scene_id()

    self:send_message_to_country_server(output)
end

function imp_country.on_give_officer_position_to_responder(self, input)
    local responder_id = input.responder_id

    local x,y,z = self:get_pos()
    local position = {}
    position.x, position.y, position.z = self.pos_to_client(x, y, z)

    local scene_id = self:get_aoi_scene_id()
    local output = {func_name = "transport_to_officer", position = position, target_game_id = game_id, target_scene_id = scene_id}
    self:send_message_to_player_game(responder_id, output)
end

function imp_country.on_pre_respond_to_call_together(self, input)
    local result = self:is_operation_allowed("mini_map_teleportation")
    local output = {result = result, func_name = "PreRespondToCallTogetherRet"}
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    if self.actor_id == input.caller_id then
        output.result = const.error_cannot_repond_yourself
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    input.func_name = "pre_respond_to_call_together"
    input.actor_id = self.actor_id
    input.country = self.country

    self:send_message_to_country_server(input)
end

function imp_country.on_respond_to_call_together(self, input)
    local result = self:is_operation_allowed("mini_map_teleportation")
    local output = {result = result, func_name = "RespondToCallTogetherRet"}
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    if self.actor_id == input.caller_id then
        output.result = const.error_cannot_repond_yourself
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    input.func_name = "respond_to_call_together"
    input.actor_id = self.actor_id
    input.country = self.country

    self:send_message_to_country_server(input)
end

function imp_country.transport_to_officer(self, input)
    local position = input.position
    local target_scene_id = input.target_scene_id
    local target_game_id = input.target_game_id

    local x = position.x / 100
    local y = position.y / 100
    local z = position.z / 100

    flog("info", string.format("transport_to_officer game_now %d", game_id))
    flog("info", string.format("transport_to_officer scene %d, game %d, x %f, y %f, z %f", target_scene_id, target_game_id, x, y, z))
    if game_id ~= target_game_id then
        flog("info", string.format("on_response_convene scene %d, game %d, x %f, y %f, z %f", target_scene_id, target_game_id, x, y, z))
        local result = self:on_response_convene(target_scene_id, target_game_id, x, y, z)
        if result ~= 0 then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name = "RespondToCallTogetherRet", result = result})
        end
    elseif self.scene_id ~= target_scene_id then
        self.posX = x
        self.posY = y
        self.posZ = z
        self.scene_id = target_scene_id
        self:load_scene(0, target_scene_id)
    else
        local client_pos = {0,0,0}
        client_pos[1], client_pos[2], client_pos[3] = position.x, position.y, position.z
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name = "MoveToAppointPos", result = 0, pos = client_pos})
    end
end

function imp_country.on_get_refresh_skill_cd_money_need(self, input)
    input.func_name = "get_refresh_skill_cd_money_need"
    input.actor_id = self.actor_id
    input.country = self.country
    input.is_buy = false
    self:send_message_to_country_server(input)
end

function imp_country.on_refresh_skill_cd_with_money(self, input)
    input.func_name = "get_refresh_skill_cd_money_need"
    input.actor_id = self.actor_id
    input.country = self.country
    input.is_buy = true
    self:send_message_to_country_server(input)
end

function imp_country.remove_refresh_skill_cd_money(self, input)
    local money_need = input.money_need
    if not self:is_resource_enough("ingot", money_need) then
        return const.error_ingot_not_enough
    end
    self:remove_resource("ingot", money_need)
    input.func_name = "refresh_office_skill_cd"
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country.gm_clear_skill_cd(self)
    local output = {func_name = "gm_clear_skill_cd"}
    output.actor_id = self.actor_id
    output.country = self.country
    self:send_message_to_country_server(output)
end

register_message_handler(const.CS_MESSAGE_LUA_LOGIN, on_player_login)
register_server_message_handler(const.OG_ADD_BUFF_TO_ALL_COUNTRY_PLAYER, add_buff_to_all_country_player)

imp_country.__message_handler = {}
imp_country.__message_handler.on_player_login = on_player_login

return imp_country