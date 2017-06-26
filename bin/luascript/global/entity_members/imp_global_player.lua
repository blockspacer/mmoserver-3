--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/15 0015
-- Time: 14:09
-- To change this template use File | Settings | File Templates.
--
local const = require "Common/constant"
local flog = require "basic/log"
local onlinerole = require "global/global_online_user"
local data_base = require "basic/db_mongo"
local center_server_manager = require "center_server_manager"

local params = {
    actor_id = {db = true},
    session_id = {},
    src_game_id = {},
    level = {db = true,default = 1},
    actor_name = {db = true,default = ""},
    vocation = {db = true},
    country = {db = true},
    sex = {db = true,default = 1},
    offlinetime = {db = true,default = 0},
    donate_flower_count = {db=true,default=0},
    receive_flower_count = {db=true,default=0}
}

local imp_global_player = {}
imp_global_player.__index = imp_global_player

setmetatable(imp_global_player, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})
imp_global_player.__params = params

function imp_global_player.on_update_player_info(self, input, syn_data)
    if input.actor_id ~= nil then
        self.actor_id = input.actor_id
    end
    if input.level ~= nil then
        self.level = input.level
    end
    if input.actor_name ~= nil then
        self.actor_name = input.actor_name
    end
    if input.vocation ~= nil then
        self.vocation = input.vocation
    end
    if input.country ~= nil then
        self.country = input.country
    end
    if input.sex ~= nil then
        self.sex = input.sex
    end
end

function imp_global_player.on_reds(self,input,syn_data)
    --现在只有好友红点消息
    local reds = {}
    self:imp_global_friend_main_reds(reds)
    reds.func_name = "on_reds"
    self:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,reds)
end



local function _db_callback_get_actor(self, status, playerdata,callback_id)
    local result = 0
    local player_info = {}
    if status == 0 or table.isEmptyOrNil(playerdata) then
        flog("tmlDebug","gloabl on_query_player_info,can not find actor!")
        result = const.error_no_player
        self:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_reply_query_player_info",result=result,player_info=player_info})
        return
    end

    player_info.actor_id = playerdata.actor_id
    player_info.actor_name = playerdata.actor_name
    player_info.level = playerdata.level
    player_info.sex = playerdata.sex
    player_info.vocation = playerdata.vocation
    player_info.equipments = table.get(playerdata, "equipments", {})
    if playerdata.team_id == nil or playerdata.team_id == 0 then
        self:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_reply_query_player_info",result=result,player_info=player_info})
    else
        center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.team_service,const.GT_MESSAGE_LUA_GAME_RPC,{func_name="on_query_player_info_team_member_count",result=result,player_info=player_info,team_id=playerdata.team_id})
    end
    return 0
end

function imp_global_player.on_query_player_info(self,input,syn_data)
    local result = 0
    if input.query_actor_id == nil then
        return
    end
    local player = onlinerole.get_user(input.query_actor_id)
    if player ~= nil then
        player:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_global_query_player_info",queryer_actor_id=input.actor_id})
    else
        flog("tmlDebug","global on_query_player_info,actor_id:"..input.query_actor_id)
        data_base.db_find_one(self, _db_callback_get_actor, "actor_info", {actor_id = input.query_actor_id}, {})
    end
end

function imp_global_player.on_global_query_player_info(self,input,syn_data)
    local player = onlinerole.get_user(input.queryer_actor_id)
    if player ~= nil then
        player:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_reply_query_player_info",result=input.result,player_info=input.player_info})
    end
end

function imp_global_player.__ctor(self)

end

function imp_global_player.imp_global_player_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
end

function imp_global_player.imp_global_player_write_to_dict(self, dict)
    self.offlinetime = _get_now_time_second()
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
end

function imp_global_player.imp_global_player_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
end

function imp_global_player.on_friend_player_game_id_change(self,input)
    flog("tmlDebug","imp_global_player.on_friend_player_game_id_change")
    self.src_game_id = input.actor_game_id
end

function imp_global_player.player_change_name(self,input)
    local old_name = self.actor_name
    self.actor_name = input.new_name
    onlinerole.player_change_name(input.new_name,input.actor_id,old_name)
end

return imp_global_player

