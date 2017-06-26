--------------------------------------------------------------------
-- 文件名:	ranking_player.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/1/5
-- 描  述:	排行榜成员
--------------------------------------------------------------------
local net_work = require "basic/net"
local send_to_game = net_work.forward_message_to_game
local send_to_client = net_work.send_to_client
local const = require "Common/constant"
local flog = require "basic/log"
local send_to_global = net_work.forward_message_to_global
local dungeon_hegemon = require "global_ranking/dungeon_hegemon"
local pet_rank = require "global_ranking/pet_rank"
local pet_generate = require "global_ranking/pet_generate"
local player_rank = require "global_ranking/player_rank"
local onlineuser = require "global_ranking/ranking_online_user"
local center_server_manager = require "center_server_manager"

local ranking_player = {}
ranking_player.__index = ranking_player

setmetatable(ranking_player, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function ranking_player.__ctor(self)
end


function ranking_player.on_ranking_player_init(self, input)
    self.session_id = tonumber(input.session_id)
    self.actor_id = input.actor_id
    return true
end

function ranking_player.on_ranking_player_logout(self,input)
    onlineuser.del_user(input.actor_id)
end

function ranking_player.on_message(self, key_action, input)
    if key_action == const.GR_MESSAGE_LUA_GAME_RPC then
        local func_name = input.func_name
        if func_name == nil or self[func_name] == nil then
            func_name = func_name or "nil"
            flog("error", "ranking_player.on_message GR_MESSAGE_LUA_GAME_RPC: no func_name  "..func_name)
            return
        end
        flog("info", "GR_MESSAGE_LUA_GAME_RPC func_name "..func_name)
        self[func_name](self, input)
    end
end

function ranking_player.get_dungeon_hegemon(self, input)
    local chapter_ids = input.chapter_ids
    local dungeon_id = input.dungeon_id
    local dungeon_type = input.dungeon_type
    local output = dungeon_hegemon.get_dungeon_hegemon(dungeon_id, chapter_ids, dungeon_type)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GET_DUNGEON_HEGEMON , output)
end

function ranking_player.clear_dungeon_hegemon(self, input)
    dungeon_hegemon.clear_dungeon_hegemon()
end

function ranking_player.update_dungeon_hegemon(self, input)
    local player = input.player
    local chapter_id = input.chapter_id
    local dungeon_id = input.dungeon_id
    local time = input.time
    local rank = dungeon_hegemon.update_dungeon_hegemon(player, chapter_id, dungeon_id, time)
    if rank ~= nil then
        local output = {func_name = "GetDungeonHegemon", rank = rank, dungeon_id = dungeon_id, chapter_id = chapter_id}
        send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
        if rank == 1 then
            local data = {func_name = "get_dungeon_hegemon", dungeon_type = "main_dungeon", dungeon_id = dungeon_id, actor_id = self.actor_id}
            send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, data)
        end
    end
end

function ranking_player.update_team_dungeon_hegemon(self, input)
    local team = input.team
    local dungeon_id = input.dungeon_id
    local time = input.time
    local rank = dungeon_hegemon.update_team_dungeon_hegemon(team, dungeon_id, time)
    if rank ~= nil then
        local output = {func_name = "GetTeamDungeonHegemon", rank = rank, dungeon_id = dungeon_id}
        for _, player in pairs(team.members) do
            send_to_client(player.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
        end
        if rank == 1 then
            local data = {func_name = "get_dungeon_hegemon", dungeon_type = "team_dungeon", dungeon_id = dungeon_id }
            for _, player in pairs(team.members) do
                data.actor_id = player.actor_id
                center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT, data)
            end
        end
    end
end

function ranking_player.update_to_pet_rank_list(self, input)
    flog("syzDebug", "update_to_pet_rank_list "..table.serialize(input))
    local base = input.base
    local quality = input.quality
    local pet_score = input.pet_score
    local owner_id = input.owner_id
    local owner_name = input.owner_name
    local pet_id = input.pet_id
    local entity_id = input.entity_id
    local pet_name = input.pet_name
    local highest_property_rank, pet_score_rank = pet_rank.update_to_pet_rank_list(base, quality, pet_score, pet_id, owner_name, owner_id, entity_id, pet_name)
    local pet_rank_info = {[entity_id] = {highest_property_rank = highest_property_rank, pet_score_rank = pet_score_rank}}
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {func_name = "refresh_pet_rank_info", pet_rank_info = pet_rank_info,actor_id=self.actor_id})
end

function ranking_player.get_pet_rank_list(self, input)
    local pet_id = input.pet_id
    local rank_name = input.rank_name
    local entity_id = input.pet_uid
    local self_data = input.self_data
    local rank_list = pet_rank.get_pet_rank_list(pet_id, rank_name)
    self_data.self_index = pet_rank.get_pet_rank_with_rank_name(pet_id, entity_id, rank_name) or -1
    local output = {func_name = "GetPetRankListRet", rank_list = rank_list, self_data = self_data}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function ranking_player.get_pet_rank_info(self, input)
    local pet_list = input.pet_list
    local pet_rank_info = {}
    for _, pet in pairs(pet_list) do
        local highest_property_rank, pet_score_rank = pet_rank.get_pet_rank_info(pet.pet_id, pet.entity_id)
        pet_rank_info[pet.entity_id] = {highest_property_rank = highest_property_rank, pet_score_rank = pet_score_rank}
    end
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {func_name = "refresh_pet_rank_info", pet_rank_info = pet_rank_info,actor_id=self.actor_id})
end

function ranking_player.remove_pet_info_from_list(self, input)
    local pet_id = input.pet_id
    local entity_id = input.pet_uid
    pet_rank.remove_pet_info_from_list(pet_id, entity_id)
end

function ranking_player.generate_new_pet(self, input)
    local type = pet_generate.get_new_pet_type()
    input.func_name = "generate_new_pet_with_type"
    input.pet_create_type = type
    input.actor_id = self.actor_id
    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, input)
end


function ranking_player.hide_name_from_rank_list(self, input)
    local rank_set_name = input.rank_set_name
    local class = input.class
    local is_hide = input.is_hide
    local hide_number = player_rank.hide_name_from_rank_list(rank_set_name, is_hide)
    local output = {func_name = "HideMyNameRet", hide_number = hide_number, result = 0}
    if class == "pet" then
        output.func_name = "HideMyPetNameRet"
    end
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function ranking_player.get_hide_name_number(self, input)
    local rank_set_name = input.rank_set_name
    local class = input.class
    local rank_name = input.rank_name
    local vocation = input.vocation
    local hide_number = player_rank.get_hide_name_number(rank_set_name)
    local output = {func_name = "GetHideNameNumber", hide_number = hide_number, rank_name = rank_name, class=class , vocation=vocation}
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC , output)
end

ranking_player.on_player_session_changed = require("helper/global_common").on_player_session_changed

function ranking_player.gm_hegemon_dispense_rewards(self, input)
    dungeon_hegemon.gm_hegemon_dispense_rewards()
end

return ranking_player