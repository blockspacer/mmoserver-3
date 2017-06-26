--------------------------------------------------------------------
-- 文件名:	faction_player.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/2/17
-- 描  述:	帮会成员
--------------------------------------------------------------------
local net_work = require "basic/net"
local send_to_game = net_work.forward_message_to_game
local send_to_client = net_work.send_to_client
local const = require "Common/constant"
local flog = require "basic/log"
local send_to_global = net_work.forward_message_to_global
local broadcast_message = net_work.broadcast_message
local faction_factory = require "global_faction/faction_factory"
local center_server_manager = require "center_server_manager"
local db_hiredis = require "basic/db_hiredis"
local data_base = require "basic/db_mongo"
local onlineuser = require "global_faction/faction_online_user"

local FIRST_FACTION_VISUAL_ID = 100000


local faction_player = {}
faction_player.__index = faction_player

setmetatable(faction_player, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function faction_player.__ctor(self)

end


function faction_player.on_faction_player_init(self, input)
    self.session_id = tonumber(input.session_id)
    self.actor_id = input.actor_id
    self.game_id = input.game_id
    self.faction_id = input.faction_id
    if input.faction_id ~= 0 then
        faction_factory.on_faction_player_init(input.faction_id,self.actor_id)
    end
    return true
end

function faction_player.on_faction_player_logout(self,input)
    onlineuser.del_user(input.actor_id)
end

function faction_player.on_faction_player_game_id_change(self,input)
    self.game_id = input.actor_game_id
end

function faction_player.on_message(self, key_action, input)
    if key_action == const.GF_MESSAGE_LUA_GAME_RPC then
        local func_name = input.func_name
        if func_name == nil or self[func_name] == nil then
            func_name = func_name or "nil"
            flog("error", "faction_player.on_message GF_MESSAGE_LUA_GAME_RPC: no func_name  "..func_name)
            return
        end
        flog("info", "GF_MESSAGE_LUA_GAME_RPC func_name "..func_name)
        self[func_name](self, input)
    end
end

local function send_to_all_member_game(members, data)
    for id , _ in pairs(members) do
        data.actor_id = id
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)
    end
end

local function send_to_all_member_client(members, data)
    for id , _ in pairs(members) do
        --center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, data)
        local player = onlineuser.get_user(id)
        if player ~= nil then
            send_to_client(player.session_id, const.SC_MESSAGE_LUA_GAME_RPC , data)
        end
    end
end

local function _make_player_from_info(info)
    local player = {}
    player.actor_id = info.actor_id
    player.actor_name = info.actor_name
    player.level = info.level
    player.vocation = info.vocation
    player.country = info.country
    player.sex = info.sex
    player.total_power = info.total_power
    return player
end


local function _db_callback_insert_name(self, status)
    local output = {func_name = "CreateFactionRet"}
    if status == 0 then
        flog("syzDebug", "_db_callback_insert_name faction name overlap ")
        self.create_faction_info = nil
        output.result = const.error_faction_name_overlaps
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
    local id = db_hiredis.incr("faction_visual_id")

    local faction_name = self.create_faction_info.faction_name
    local declaration = self.create_faction_info.declaration
    local creater = self.create_faction_info.creater
    self.create_faction_info = nil

    local output = {func_name = "CreateFactionRet"}
    if id == nil then
        flog("error", "_get_faction_visual_id get id fail!")
        output.result = const.error_server_error
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    local rst, faction_info = faction_factory.create_faction(creater, faction_name, declaration, id + FIRST_FACTION_VISUAL_ID)
    output.result = rst
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
    local rpc_data = {func_name = "create_faction_success", faction_info = faction_info, actor_id = creater.actor_id}
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, rpc_data)
end

function faction_player.create_faction(self, input)
    local self_info = input.self_info
    local faction_name = input.faction_name
    local declaration = input.declaration

    local creater = _make_player_from_info(self_info)
    local output = {func_name = "CreateFactionRet"}
    if self.create_faction_info ~= nil then
        output.result = const.error_waiting_for_last_command_result
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    self.create_faction_info = {faction_name = faction_name, declaration = declaration, creater = creater }
    data_base.db_insert_doc(self, _db_callback_insert_name, "faction_name_info", {faction_name = faction_name})
 end

function faction_player.dissolve_faction(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id
    local rst, members = faction_factory.dissolve_faction(faction_id, operater_id)

    local output = {func_name = "DissolveFactionRet", result = rst}
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    send_to_all_member_client(members, {func_name = "FactionBeDissolved"})
    send_to_all_member_game(members, {func_name = "leave_faction", is_traitor = false})
    --通知竞技场服务器更改玩家帮派名字
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.arena_service, const.SA_MESSAGE_LUA_GAME_ARENA_RPC, {func_name="player_union_name_change",members=table.copy(members),union_name=""})
end

function faction_player.apply_join_faction(self, input)
    local faction_id = input.faction_id
    local self_info = input.self_info

    local player = _make_player_from_info(self_info)
    local rst = faction_factory.apply_join_faction(faction_id, player)
    local output = {func_name = "ApplyJoinFactionRet", result = rst, faction_id = faction_id}

    return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.one_key_apply_join_faction(self, input)
    local self_info = input.self_info
    local faction_id_list = input.faction_id_list

    local result_list = {}
    for _, faction_id in pairs(faction_id_list) do
        local player = _make_player_from_info(self_info)
        local rst = faction_factory.apply_join_faction(faction_id, player)
        result_list[faction_id] = rst
    end

    local output = {func_name = "OneKeyApplyJoinFactionRet", result = 0, result_list = result_list}
    return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.reply_apply_join_faction(self, input)
    local faction_id = input.faction_id
    local player_id = input.player_id
    local is_agree = input.is_agree
    local operater_id = input.operater_id

    local rst, apply_list = faction_factory.reply_apply_join_faction(faction_id, operater_id, player_id, is_agree)
    local output = {func_name = "ReplyApplyJoinFactionRet", result = rst , apply_list = apply_list}
    if rst ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)

    if not is_agree then
        return
    end
    local rpc_data = {}
    rpc_data.func_name = "PlayerJoinFaction"
    rpc_data.actor_id = player_id
    rpc_data.faction_id = faction_id
    --center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, rpc_data)
    local player = onlineuser.get_user(player_id)
    if player ~= nil then
        send_to_client(player.session_id, const.SC_MESSAGE_LUA_GAME_RPC , rpc_data)
    end
    local _, faction_info = faction_factory.get_basic_faction_info(faction_id)
    rpc_data.faction_name = faction_info.faction_name
    rpc_data.func_name = "join_faction"
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, rpc_data)
end

function faction_player.one_key_reply_all(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id
    local is_agree = input.is_agree

    local rst, new_members = faction_factory.one_key_reply_all(faction_id, operater_id, is_agree)
    local output = {func_name = "OneKeyReplyAllRet", result = rst }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)

    local result, apply_list = faction_factory.get_faction_apply_list(faction_id, operater_id)
    output = {func_name = "GetFactionApplyListRet", result = result, apply_list = apply_list }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    send_to_all_member_client(new_members, {func_name = "PlayerJoinFaction", faction_id = faction_id})

    local _, faction_info = faction_factory.get_basic_faction_info(faction_id)
    send_to_all_member_game(new_members, {func_name = "join_faction", faction_id = faction_id, faction_name = faction_info.faction_name})
end

function faction_player.kick_faction_member(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id
    local member_id = input.member_id

    local rst = faction_factory.kick_faction_member(faction_id, operater_id, member_id)
    local rst_get_member, members = faction_factory.get_faction_members_info(faction_id)
    local output = {func_name = "KickFactionMemberRet", result = rst , members = members}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    if rst ~= 0 then
        return
    end
    local rpc_data = {}
    rpc_data.func_name = "PlayerBeKicked"
    rpc_data.actor_id = member_id
    --center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, rpc_data)
    local player = onlineuser.get_user(member_id)
    send_to_client(player.session_id, const.SC_MESSAGE_LUA_GAME_RPC , rpc_data)
    rpc_data.func_name = "leave_faction"
    rpc_data.is_traitor = false
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, rpc_data)
end

function faction_player.be_invited_to_faction(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id
    local operater_name = input.operater_name
    local member_info = input.member_info
    local member_id = input.member_id

    local new_member = _make_player_from_info(member_info)
    local rst, faction_name = faction_factory.invite_faction_member(faction_id, operater_id, new_member)
    local rpc_data = {result = rst, func_name = "InviteFactionMemberRet", actor_id = operater_id}
    --center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, rpc_data)
    local player = onlineuser.get_user(operater_id)
    send_to_client(player.session_id, const.SC_MESSAGE_LUA_GAME_RPC , rpc_data)

    if rst == 0 then
        local output = {}
        output.func_name = "BeInvitedToFaction"
        output.inviter_id = operater_id
        output.inviter_name = operater_name
        output.inviter_faction_id = faction_id
        output.inviter_faction_name = faction_name
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
end

function faction_player.reply_faction_invite(self, input)
    local faction_id = input.faction_id
    local player_id = input.player_id
    local is_agree = input.is_agree

    local rst = faction_factory.reply_faction_invite(faction_id, player_id, is_agree)
    local output = {func_name = "ReplyFactionInviteRet", result = rst , faction_id = faction_id, is_agree = is_agree}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    if rst ~= 0 or not is_agree then
        return
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , {func_name = "PlayerJoinFaction", faction_id = faction_id})

    local _, faction_info = faction_factory.get_basic_faction_info(faction_id)
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {func_name = "join_faction", faction_id = faction_id,actor_id=self.actor_id, faction_name = faction_info.faction_name})
end

function faction_player.member_leave_faction(self, input)
    local faction_id = input.faction_id
    local member_id = input.member_id

    local rst = faction_factory.member_leave_faction(faction_id, member_id)
    local output = {func_name = "MemberLeaveFactionRet", result = rst , faction_id = faction_id }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    if rst ~= 0 then
        return
    end
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {func_name = "leave_faction", is_traitor = true,actor_id=self.actor_id})
end

function faction_player.get_faction_apply_list(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id

    local result, apply_list = faction_factory.get_faction_apply_list(faction_id, operater_id)
    local output = {func_name = "GetFactionApplyListRet", result = result, apply_list = apply_list }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.set_declaration(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id
    local new_declaration = input.new_declaration

    local result, faction_info = faction_factory.set_declaration(faction_id, new_declaration, operater_id)
    local output = {func_name = "SetDeclarationRet", result = result, faction_info = faction_info }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.set_enemy_faction(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id
    local enemy_faction_id = input.enemy_faction_id

    local result, faction_info = faction_factory.set_enemy_faction(faction_id, enemy_faction_id, operater_id)
    local output = {func_name = "SetEnemyFactionRet", result = result, faction_info = faction_info }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.get_faction_members_info(self, input)
    local faction_id = input.faction_id

    local result, members = faction_factory.get_faction_members_info(faction_id)
    local output = {func_name = "GetFactionMembersInfoRet", result = result, members = members}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.faction_player_login(self, input)
    local faction_id = input.faction_id
    local player_id = input.player_id
    local self_info = input.self_info

    local is_changed, new_faction_id = faction_factory.faction_player_login(faction_id, player_id, self_info)
    if is_changed then
        if new_faction_id == 0 then
            send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {func_name = "leave_faction", is_traitor = false,actor_id=self.actor_id})
        else
            local rst, faction_info = faction_factory.get_basic_faction_info(new_faction_id)
            if faction_info == nil then
                flog("error", string.format("faction_info is nil , rst %d, faction_id %d",rst , new_faction_id))
                return
            end
            send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {func_name = "join_faction", faction_id = new_faction_id,actor_id=self.actor_id, faction_name = faction_info.faction_name})
        end
    end
end

function faction_player.faction_player_logout(self, input)
    local faction_id = input.faction_id
    local player_id = input.player_id

    faction_factory.faction_player_logout(faction_id, player_id)
end

function faction_player.change_position(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id
    local member_id = input.member_id
    local position = input.position

    local result, members = faction_factory.change_position(faction_id, operater_id, member_id, position)
    local output = {func_name = "ChangePositionRet", result = result, members = members }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.get_faction_list(self, input)
    local start_index = input.start_index
    local end_index = input.end_index
    local country = input.country

    local result, info_list = faction_factory.get_faction_list(start_index, end_index, country)
    local output = {func_name = "GetFactionListRet", result = result, info_list = info_list }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.get_random_faction_list(self, input)
    local list_length = input.list_length
    local country = input.country

    local result, info_list = faction_factory.get_random_faction_list(list_length, country)
    local output = {func_name = "GetRandomFactionListRet", result = result, info_list = info_list }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.search_faction(self, input)
    local search_str = input.search_str
    local country = input.country

    local result, info_list = faction_factory.search_faction(search_str, country)
    local output = {func_name = "SearchFactionRet", result = result, info_list = info_list }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.buy_faction_on_top(self, input)
    local faction_id = input.faction_id
    local country = input.country

    local expire_time = faction_factory.buy_faction_on_top(faction_id, country)
    local output = {func_name = "BuyFactionOnTopRet", result = 0, expire_time = expire_time}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.get_basic_faction_info(self, input)
    local faction_id = input.faction_id

    local result, faction_info = faction_factory.get_basic_faction_info(faction_id)
    local output = {func_name = "GetBasicFactionInfoRet", result = result, faction_info = faction_info}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.add_faction_fund(self, input)
    local faction_id = input.faction_id
    local count = input.count

    faction_factory.add_faction_fund(faction_id, count)
end

local function _db_callback_change_name(param, status)
    local output = {func_name = "ChangeFactionNameRet"}
    if status == 0 then
        flog("syzDebug", "_db_callback_insert_name faction name overlap ")
        output.result = const.error_faction_name_overlaps
        return send_to_client(param.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    local result, faction_info = faction_factory.change_faction_name(param.faction_id, param.operater_id, param.new_faction_name)
    local output = {func_name = "ChangeFactionNameRet", result = result, faction_info = faction_info}
    send_to_client(param.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)

    local result, members = faction_factory.get_faction_members_info(param.faction_id)
    if result ~= 0 then
        return
    end
    send_to_all_member_game(members, {func_name = "change_faction_name", faction_name = param.new_faction_name})
    --通知竞技场服务器更改玩家帮派名字
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.arena_service, const.SA_MESSAGE_LUA_GAME_ARENA_RPC, {func_name="player_union_name_change",members=table.copy(members),union_name=param.new_faction_name})
end

function faction_player.change_faction_name(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id
    local new_faction_name = input.faction_name

    local param = {faction_id = faction_id, operater_id = operater_id, new_faction_name= new_faction_name, session_id = self.session_id}
    data_base.db_insert_doc(param, _db_callback_change_name, "faction_name_info", {faction_name = new_faction_name})
end

function faction_player.get_faction_rank_list(self, input)
    local faction_id = input.faction_id
    local key = input.rank_name
    local start_index = input.start_index
    local end_index = input.end_index
    local output = {func_name = "GetFactionRankListRet", rank_name = key }
    local result, rank_list, self_data = faction_factory.get_faction_rank_list(faction_id, key, start_index, end_index)
    output.result = result
    output.rank_list = rank_list
    output.self_data = self_data
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.on_faction_member_chat(self,input)
    flog("tmlDebug","faction_player.on_faction_member_chat input.faction_id "..input.faction_id)
    local members = faction_factory.get_faction_members(input.faction_id)
    if members == nil then
        return
    end

    local player = nil
    for i=1,#members,1 do
        player = onlineuser.get_user(members[i])
        if player ~= nil then
            send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {func_name = "on_faction_member_chat", data=input.data,actor_id=player.actor_id})
        end
    end
end

function faction_player.transfer_chief(self, input)
    local faction_id = input.faction_id
    local operater_id = input.operater_id
    local member_id = input.member_id

    local result, members = faction_factory.transfer_chief(faction_id, operater_id, member_id)
    local output = {func_name = "TransferChiefRet", result = result, members = members }
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function faction_player.on_query_faction_scene_gameid(self,input)
    local faction_id = input.faction_id
    local result = 0
    local faction_scene_gameid = faction_factory.get_faction_scene_gameid(faction_id)
    if faction_scene_gameid == nil then
        result = const.error_faction_scene_not_start
    end
    input.func_name = "on_query_faction_scene_gameid_ret"
    input.faction_scene_gameid = faction_scene_gameid
    input.result = result
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, input)
end

function faction_player.on_query_faction_building(self,input)
    local result, building = faction_factory.on_query_faction_building(input.faction_id,input.building_id,input.actor_id)
    if building ~= nil then
        building.investment_count = input.investment_count
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , {func_name="OnQueryFactionBuildingRet",result=result,building=building,building_id=input.building_id})
end

function faction_player.on_investment_faction_building(self,input)
    local result, building = faction_factory.on_investment_faction_building(input.faction_id,input.building_id,input.actor_id,input.investment_type,input.investment_count,input.actor_name)
    if result ~= 0 then
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , {func_name="OnInvestmentFactionBuildingRet",result=result,building_id=input.building_id})
    else
        building.investment_count = input.investment_count
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , {func_name="OnInvestmentFactionBuildingRet",result=result,building=building,building_id=input.building_id})
    end
    send_to_game(input.game_id,const.OG_MESSAGE_LUA_GAME_RPC,{building_id=input.building_id,investment_type=input.investment_type,func_name="on_investment_faction_building_ret",result=result,actor_id=input.actor_id})
end

function faction_player.on_upgrade_faction_building(self,input)
    local result, building = faction_factory.on_upgrade_faction_building(input.faction_id,input.building_id,input.actor_id)
    if building ~= nil then
        building.investment_count = input.investment_count
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , {func_name="OnUpgradeFactionBuildingRet",result=result,building=building,building_id=input.building_id})
end

function faction_player.send_message_to_game(self,data)
    send_to_game(self.game_id, const.OG_MESSAGE_LUA_GAME_RPC, data)
end

faction_player.on_player_session_changed = require("helper/global_common").on_player_session_changed

return faction_player