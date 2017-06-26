--------------------------------------------------------------------
-- 文件名:	country_player.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/9
-- 描  述:	国家成员
--------------------------------------------------------------------
local net_work = require "basic/net"
local send_to_game = net_work.forward_message_to_game
local send_to_client = net_work.send_to_client
local const = require "Common/constant"
local flog = require "basic/log"
local country_donation = require "global_country/country_donation"
local send_to_global = net_work.forward_message_to_global
local center_server_manager = require "center_server_manager"
local onlineuser = require "global_country/country_online_user"
local country_war = require "global_country/country_war"
local country_election = require "global_country/country_election"
local pvp_country_config = require "configs/pvp_country_config"
local common_char_chinese_config = require "configs/common_char_chinese_config"
local broadcast_message = require("basic/net").broadcast_message
local get_time_str_from_sec = require("basic/scheme").get_time_str_from_sec
local is_command_cool_down = require("helper/command_cd").is_command_cool_down

local country_player = {}
country_player.__index = country_player

setmetatable(country_player, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function country_player.__ctor(self)
end


function country_player.on_country_player_init(self, input)
    self.session_id = tonumber(input.session_id)
    self.actor_id = input.actor_id
    local output = country_war.player_init_data()
    if output ~= nil then
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    return true
end

country_player.on_player_session_changed = require("helper/global_common").on_player_session_changed

function country_player.on_message(self, key_action, input)
    if key_action == const.GC_MESSAGE_LUA_GAME_RPC then
        local func_name = input.func_name
        if func_name == nil or self[func_name] == nil then
            func_name = func_name or "nil"
            flog("error", "country_player.on_message GT_MESSAGE_LUA_GAME_RPC: no func_name  "..func_name)
            return
        end
        flog("info", "GT_MESSAGE_LUA_GAME_RPC func_name "..func_name)
        self[func_name](self, input)
    end
end

function country_player.donate_goods(self, input)
    local actor_id = input.actor_id
    local country = input.country
    local new_donation = input.donation + input.coin_num
    local fund_addtion = input.coin_num
    local actor_name = input.actor_name
    local new_weekly_donation = input.weekly_donation + input.coin_num
    local info_in_total, info_in_weekly, affected_guy, weekly_affected_guy, country_fund = country_donation.country_player_donation(actor_id, country, new_donation, fund_addtion, actor_name, new_weekly_donation)
    for _, v in pairs(affected_guy) do
        local rpc_data = {}
        rpc_data.func_name = "NobleRankChangeRet"
        rpc_data.noble_rank = v.new_noble_rank
        rpc_data.donation_rank = v.new_rank
        rpc_data.actor_id = v.actor_id
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, rpc_data)
    end

    for _, v in pairs(weekly_affected_guy) do
        local rpc_data = {}
        rpc_data.func_name = "WeeklyRankChangeRet"
        rpc_data.weekly_noble_rank = v.new_weekly_noble_rank
        rpc_data.weekly_donation_rank = v.new_weekly_rank
        rpc_data.actor_id = v.actor_id
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, rpc_data)
    end

    local output = {result = 0, func_name = "DonateGoodsRet" }
    output.country_fund = country_fund
    output.noble_rank = info_in_total.noble_rank
    output.donation_rank = info_in_total.donation_rank
    output.donation = info_in_total.donation
    output.weekly_donation = info_in_weekly.weekly_donation
    output.weekly_noble_rank = info_in_weekly.weekly_noble_rank
    output.weekly_donation_rank = info_in_weekly.weekly_donation_rank
    output.actor_id = self.actor_id
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.get_donation_list(self, input)
    local country = input.country
    local start_index = input.start_index
    local end_index = input.end_index
    local actor_id = input.actor_id
    local list_type = input.type
    local old_noble_rank = input.noble_rank
    local donation = input.donation
    local result, reply_list, donation_rank, country_fund, next_level_need = country_donation.get_donation_list(country, start_index, end_index, actor_id, list_type, old_noble_rank, donation)
    local output = {result = result, func_name = "GetDonationListRet" }
    if result == 0 then
        output.country_fund = country_fund
        output.rank_list = reply_list
        output.donation_rank = donation_rank
        output.next_level_need = next_level_need
        output.type = list_type
    end
    output.actor_id = self.actor_id
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.get_noble_rank(self, input)
    local country = input.country
    local actor_id = input.actor_id
    local donation = input.donation
    local weekly_donation = input.weekly_donation
    local noble_rank, donation_rank = country_donation.reget_noble_rank(country, actor_id, donation)
    local weekly_noble_rank, weekly_donation_rank = country_donation.reget_weekly_noble_rank(country, actor_id, weekly_donation)
    local output = {result = 0, func_name = "get_noble_rank_ret" }
    output.noble_rank = noble_rank
    output.donation_rank = donation_rank
    output.actor_id = self.actor_id
    output.weekly_noble_rank = weekly_noble_rank
    output.weekly_donation_rank = weekly_donation_rank
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.get_country_basic(self, input)
    local country = input.country
    local actor_id = input.actor_id
    local donation = input.donation
    local noble_rank, donation_rank, country_fund, declaration = country_donation.get_basic(country, actor_id, donation)
    local salary = country_election.get_salary_value(actor_id, country)
    local office_id = country_election.get_player_office_id(actor_id, country)
    local pay_right = pvp_country_config.has_right_to_pay_salary(office_id)
    local output = {result = 0, func_name = "GetCountryBasicRet" }
    output.noble_rank = noble_rank
    output.donation_rank = donation_rank
    output.country_fund = country_fund
    output.declaration = declaration
    output.actor_id = self.actor_id
    output.salary = salary
    output.pay_right = pay_right
    send_to_game( input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.change_country_declaration(self, input)
    local country = input.country
    local actor_id = input.actor_id
    local content = input.content
    country_donation.set_declaration(country, content)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "ChangeCountryDeclarationRet", country = country, content = content})
end

function country_player.on_country_player_logout(self,input)
    onlineuser.del_user(input.actor_id)
end

function country_player.on_being_attack(self,input)
    local monster_scene_id = input.monster_scene_id
    local monster_order = input.monster_order
    local attacker_id = input.actor_id
    local damage = input.damage
    local attacker_name = input.attacker_name
    local is_player = input.is_player
    local attacker_level = input.attacker_level
    country_war.on_being_attack(monster_scene_id, monster_order, attacker_id, damage, attacker_name, is_player, attacker_level)
end

function country_player.get_country_war_basic_info(self, input)
    local self_war_score = input.country_war_score
    local basic_info = country_war.get_country_war_basic_info()
    local output = {func_name = "GetCountryWarBasicInfoRet" }
    output.self_war_score = self_war_score
    output.basic_info = basic_info
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.kill_player_in_country_war(self, input)
    local killer_id = input.killer_id
    local killer_name = input.killer_name
    local hatred_list = input.hatred_list
    local country = input.country
    local dead_id = input.dead_id
    local dead_name = input.dead_name
    local killer_level = input.killer_level
    local deal_level = input.deal_level
    country_war.kill_player_in_country_war(killer_id, killer_name, hatred_list, country, dead_id, dead_name, killer_level, deal_level)
end

function country_player.get_detail_battle_achievement_list(self, input)
    local actor_id = input.actor_id
    local country = input.country

    local output = {func_name = "GetDetailBattleAchievementListRet"}
    local result, info = country_war.get_detail_battle_achievement_list()
    output.result = result
    if result ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    output.info = info
    output.self_data = country_war.get_self_battle_achievement(actor_id, country)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.transport_fleet_be_killed(self, input)
    local killer_id = input.killer_id
    local killer_name = input.killer_name
    local hatred_list = input.hatred_list
    local country = input.country
    local dead_name = input.dead_name
    local killer_level = input.killer_level
    country_war.transport_fleet_be_killed(killer_id, killer_name, hatred_list, country, dead_name, killer_level)
end

function country_player.transport_fleet_get_target(self, input)
    local name = input.name
    local country = input.country
    country_war.transport_fleet_get_target(name, country)
end

function country_player.gm_start_country_war(self, input)
    local last_time = input.last_time
    country_war.gm_start_country_war(last_time)
end

function country_player.on_add_hp(self, input)
    local monster_scene_id = input.monster_scene_id
    local hp_persent = input.hp_persent
    local callback_table = input.callback_table
    local actor_id = input.actor_id
    local result = country_war.on_add_hp(monster_scene_id, hp_persent)

    callback_table.result = result
    callback_table.actor_id = actor_id
    send_to_game( input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, callback_table)
end

function country_player.on_add_arrow(self, input)
    local monster_scene_id = input.monster_scene_id
    local arrow_num = input.arrow_num
    local callback_table = input.callback_table
    local actor_id = input.actor_id
    local max_arrow_num = input.max_arrow_num
    local result = country_war.on_add_arrow(monster_scene_id, arrow_num, max_arrow_num)

    callback_table.actor_id = actor_id
    callback_table.result = result
    send_to_game( input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, callback_table)
end



--------------------官职-----------------------------------
local function _create_system_direct_message(ui_text_name, ...)
    local msg = common_char_chinese_config.get_configed_ui_text(ui_text_name, ...)
    local output = {func_name = "SystemDirectMessage", msg = msg }
    return output
end

function country_player.gm_start_qualification_office_candidate(self, input)
    country_election.gm_start_qualification_office_candidate()
end

function country_player.gm_start_count_votes(self, input)
    country_election.gm_start_count_votes()
end

function country_player.get_election_basic_info(self, input)
    local actor_id = input.actor_id
    local self_vote_num = input.self_vote_num
    local country = input.country

    local election_state = country_election.get_current_election_state()
    local current_time = _get_now_time_second()
    local output
    if election_state == "nomination" then
        local sec_to_vote = pvp_country_config.remaining_time_to_vote(current_time)
        local time_to_vote = get_time_str_from_sec(sec_to_vote)
        local optional_office, candidate_number, choosed_office = country_election.get_election_basic_info(actor_id, country)
        output = {func_name = "GetElectionBasicInfoRet", optional_office = optional_office,
            candidate_number = candidate_number, choosed_office = choosed_office, time_to_vote = time_to_vote}
    elseif election_state == "vote" then
        local sec_to_count = pvp_country_config.remaining_time_to_count(current_time)
        local time_to_count = get_time_str_from_sec(sec_to_count)
        local candidate_list = country_election.get_candidate_list(country)
        output = {func_name = "GetCandidateListRet", candidate_list = candidate_list, self_vote_num = self_vote_num,
            time_to_count = time_to_count}
    else
        local sec_to_nomination = pvp_country_config.remaining_time_to_nomination(current_time)
        local time_to_nomination = get_time_str_from_sec(sec_to_nomination)

        local sec_to_vote = pvp_country_config.remaining_time_to_vote(current_time)
        local time_to_vote = get_time_str_from_sec(sec_to_vote)

        local sec_to_count = pvp_country_config.remaining_time_to_count(current_time)
        local time_to_count = get_time_str_from_sec(sec_to_count)
        output = {func_name = "ElectionTimeTable", time_to_nomination = time_to_nomination, time_to_vote = time_to_vote, time_to_count = time_to_count}
    end

    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.participate_in_election(self, input)
    local actor_id = input.actor_id
    local office_id = input.office_id
    local actor_name = input.actor_name
    local is_cancel = input.is_cancel
    local war_rank = input.war_rank
    local country = input.country
    local result = country_election.participate_in_election(actor_id, office_id, actor_name, is_cancel, war_rank, country)
    local output = {func_name = "ParticipateInElectionRet", result = result, office_id = office_id }
    if result == 0 then
        local optional_office, candidate_number, choosed_office = country_election.get_election_basic_info(actor_id, country)
        output.optional_office = optional_office
        output.candidate_number = candidate_number
        output.choosed_office = choosed_office
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.modify_participate_declaration(self, input)
    local actor_id = input.actor_id
    local declaration = input.declaration
    local country = input.country
    local result = country_election.modify_participate_declaration(actor_id, declaration, country)
    local output = {func_name = "ModifyParticipateDeclarationRet", result = result }
    if result == 0 then
        output.candidate_list = country_election.get_candidate_list(country)
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.get_candidate_list(self, input)
    local self_vote_num = input.self_vote_num
    local country = input.country
    local candidate_list = country_election.get_candidate_list(country)
    local output = {func_name = "GetCandidateListRet", candidate_list = candidate_list, self_vote_num = self_vote_num}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.vote_for_candidate(self, input)
    local actor_id = input.actor_id
    local candidate_player_id = input.candidate_player_id
    local vote_num = input.vote_num
    local self_vote_num = input.self_vote_num
    local country = input.country
    local result = country_election.vote_for_candidate(candidate_player_id, vote_num, country)
    local output = {func_name = "VoteForCandidateRet", result = result }

    if result ~= 0 then
        local output_game = {}
        output_game.func_name = "on_vote_for_candidate_failed"
        output_game.actor_id = actor_id
        output_game.vote_num = input.vote_num
        send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, output_game)
    else
        output.self_vote_num = self_vote_num
        output.candidate_list = country_election.get_candidate_list(country)
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.get_current_officers(self, input)
    local country = input.country
    local actor_id = input.actor_id
    local current_officers = country_election.get_current_officers(country)
    local cd_list = country_election.get_office_skill_cd(actor_id, country)
    --[[for skill_name, sec in pairs(cd_list) do
        cd_list[skill_name] = get_time_str_from_sec(sec)
    end]]

    local output = {func_name = "GetCurrentOfficersRet", current_officers = current_officers, cd_list = cd_list}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.get_history_officers(self, input)
    local index = input.index
    local country = input.country
    local history_officers, real_index, max_index = country_election.get_history_officers(index, country)
    local output = {func_name = "GetHistoryOfficersRet", history_officers = history_officers, index = real_index, max_index = max_index}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.give_like_to_history_officer(self, input)
    local index = input.index
    local officer_id = input.officer_id
    local country = input.country
    local result = country_election.give_like_to_history_officer(index, officer_id, country)
    local output = {func_name = "GiveLikeToHistoryOfficerRet", result = result }
    if result == 0 then
        local history_officers, real_index = country_election.get_history_officers(index, country)
        output.history_officers = history_officers
        output.index = real_index
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.country_shop_discount(self, input)
    local officer_actor_id = input.officer_actor_id
    local officer_actor_name = input.officer_actor_name
    local country = input.country
    local make_sure = input.make_sure
    local result, discount_info = country_election.country_shop_discount(officer_actor_id, officer_actor_name, country, make_sure)
    local output = {func_name = "CountryShopDiscountRet", result = result, discount_info = discount_info}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    if result == 0 then
        output = _create_system_direct_message("start_country_shop_discount")
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
        country_player.get_current_officers(self, {actor_id = officer_actor_id, country = country})
    end
end

function country_player.office_total_skill(self, input)
    local actor_id = input.actor_id
    local country = input.country
    local actor_name = input.actor_name

    local result = country_election.office_total_skill(actor_id, country, actor_name)
    local output = {func_name = "OfficeTotalSkillRet", result = result}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    if result == 0 then
        output = _create_system_direct_message("start_country_total_buff")
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
        country_player.get_current_officers(self, {actor_id = actor_id, country = country})
    end
end

function country_player.office_halo_skill(self, input)
    local actor_id = input.actor_id
    local country = input.country

    local office_id = country_election.get_player_office_id(actor_id, country)
    local result, skill_id = country_election.office_halo_skill(office_id, country)

    local output = {result = result, func_name = "OfficeHaloSkillRet" }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    if result == 0 then
        output.func_name = "on_cast_office_skill"
        output.actor_id = actor_id
        output.skill_id = skill_id
        send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, output)

        output = _create_system_direct_message("start_halo_skill")
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
        country_player.get_current_officers(self, {actor_id = actor_id, country = country})
    end
end

function country_player.on_war_rank_upgrade(self, input)
    local actor_id = input.actor_id
    local war_rank = input.war_rank
    local country = input.country
    country_election.on_war_rank_upgrade(actor_id, country, war_rank)
end

function country_player.gm_change_election_state(self, input)
    local state = input.state
    country_election.gm_change_election_state(state)
end

function country_player.add_country_fund(self, input)
    local country = input.country
    local count = input.count
    country_donation.add_country_fund(country, count)
end

function country_player.pay_salary(self, input)
    local player_id = input.actor_id
    local country = input.country
    local player_name = input.actor_name
    local country_fund = country_donation.get_country_fund(country)

    local result, total_salary = country_election.pay_salary(player_id, country, country_fund, player_name)
    if result == 0 then
        country_donation.remove_country_fund(country, total_salary)

        local output = _create_system_direct_message("salary_is_paid")
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
        country_player.get_current_officers(self, {actor_id = player_id, country = country})
    end
    local salary = country_election.get_salary_value(player_id, country)
    country_fund = country_donation.get_country_fund(country)
    local output = {result = result, func_name = "PaySalaryRet", salary = salary, country_fund = country_fund}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.gm_clear_election_data(self, input)
    country_election.gm_clear_election_data()
end

function country_player.get_salary(self, input)
    local actor_id = input.actor_id
    local country = input.country
    local result, salary = country_election.get_salary(actor_id, country)
    local output = {result = result, func_name = "GetSalaryRet", salary = salary}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    if result == 0 then
        output.func_name = "get_item_from_global"
        output.actor_id = actor_id
        local rewards = {[const.RESOURCE_NAME_TO_ID.bind_coin] = salary }
        output.rewards = rewards
        send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, output)
    end
end

function country_player.gm_become_officer(self, input)
    local office_id = input.office_id
    local actor_id = input.actor_id
    local actor_name = input.actor_name
    local country = input.country
    country_election.gm_become_officer(office_id, actor_id, actor_name, country)

    local current_officers = country_election.get_current_officers(country)
    local output = {func_name = "GetCurrentOfficersRet", current_officers = current_officers}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function country_player.country_player_call_together(self, input)
    local player_id = input.actor_id
    local country = input.country
    local player_name = input.actor_name
    local result, position_info = country_election.country_player_call_together(player_id, country, player_name)
    local output = {func_name = "CountryPlayerCallTogetherRet", result = result }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    if result == 0 then
        broadcast_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "CallTogetherByOfficer", position_info = position_info}, country)

        country_player.get_current_officers(self, {actor_id = player_id, country = country})
    end
end

function country_player.pre_respond_to_call_together(self, input)
    local player_id = input.actor_id
    local country = input.country
    local caller_id = input.caller_id

    local result = country_election.respond_to_call_together(player_id, country, caller_id, true)
    local output = {func_name = "PreRespondToCallTogetherRet", result = result, caller_id = caller_id}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end


function country_player.respond_to_call_together(self, input)
    local player_id = input.actor_id
    local country = input.country
    local caller_id = input.caller_id

    local result = country_election.respond_to_call_together(player_id, country, caller_id)
    local output = {func_name = "RespondToCallTogetherRet", result = result }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    if result == 0 then
        local data = {}
        data.func_name = "on_give_officer_position_to_responder"
        data.actor_id = caller_id
        data.responder_id = player_id
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)
    end
end

function country_player.get_refresh_skill_cd_money_need(self, input)
    local actor_id = input.actor_id
    local country = input.country
    local skill_name = input.skill_name
    local is_buy = input.is_buy
    local result, money_need = country_election.get_refresh_skill_cd_money_need(actor_id, country, skill_name)

    if is_buy then
        local output = {func_name = "RefreshSkillCdWithMoneyRet"}
        local FAULT_TOLERANT_CD = 5         --容错cd
        local cd_result = is_command_cool_down(self.actor_id, "refresh_skill_cd", FAULT_TOLERANT_CD)
        if cd_result ~= 0 then
            output.result = cd_result
            return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
        end

        if result ~= 0 then
            output.result = result
            return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
        end

        local data = {func_name = "remove_refresh_skill_cd_money", money_need = money_need, skill_name = skill_name }
        data.actor_id = actor_id
        send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, data)
    else
        local output = {func_name = "GetRefreshSkillCdMoneyNeedRet", result = result, money_need = money_need, skill_name = skill_name}
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
end

function country_player.refresh_office_skill_cd(self, input)
    local actor_id = input.actor_id
    local country = input.country
    local skill_name = input.skill_name
    local result = country_election.refresh_office_skill_cd(actor_id, country, skill_name)
    if result ~= 0 then
        flog("error", "refresh_office_skill_cd failed")
    end
    local output = {func_name = "RefreshSkillCdWithMoneyRet", result = result }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
    country_player.get_current_officers(self, {actor_id = actor_id, country = country})
end

function country_player.gm_clear_skill_cd(self, input)
    local actor_id = input.actor_id
    local country = input.country

    country_election.gm_clear_skill_cd(actor_id, country)
    country_player.get_current_officers(self, {actor_id = actor_id, country = country})
end

return country_player