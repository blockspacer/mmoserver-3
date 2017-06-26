--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/15 0015
-- Time: 20:01
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local onlinerole = require "global/global_online_user"
local data_base = require "basic/db_mongo"
local system_friends_chat = require "data/system_friends_chat"
local string_format = string.format
local common_char_chinese_config = require "configs/common_char_chinese_config"
local string_utf8len = require("basic/scheme").string_utf8len
local table = table

local FRIEND_NAME_TO_FLAG = const.FRIEND_NAME_TO_FLAG
local friend_parameter = system_friends_chat.Parameter
local FRIEND_VALUE_UPDATE_REASON = const.FRIEND_VALUE_UPDATE_REASON

local params = {}
local imp_global_friend = {}
imp_global_friend.__index = imp_global_friend

setmetatable(imp_global_friend, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_global_friend.__params = params

--[[firends[id] = {actor_id,actor_name,vocation,sex,level,frined_value,mood,offlinetime}]]--
--blacklist = {actor_id,actor_name,vocation,sex,level,frined_value,mood,offlinetime,pre_flag}}
function imp_global_friend.__ctor(self)
    self.friends = {}
    self.applicants = {}
    self.blacklist = {}
    self.enemys = {}
    self.friend_messages = {}
    --self.query_player_data_operation[callback_id]={actor_id,func}
    self.query_player_data_operation = {}
    self.update_receive_flower_count = {}
    self.search_callback = {}
end

local function _db_callback_update_friends_data(caller, status)
    if status == false then
        flog("error", "global _db_callback_update_friends_data : save fail ")
        return
    end
end

local function _db_callback_offline_player_data(self, status, playerdata,callback_id)
    if self.query_player_data_operation[callback_id] ~= nil then
        if status == false or playerdata == nil then
            flog("warn","find global offline player data fail,actor id:"..self.query_player_data_operation[callback_id].actor_id)
        else
            local __data = self.query_player_data_operation[callback_id]
            if self.query_player_data_operation[callback_id].func ~= nil then
                if self.query_player_data_operation[callback_id].isChat == true then
                    self.query_player_data_operation[callback_id].func(self,__data.actor_id,playerdata,__data.data,__data.attach)
                elseif self.query_player_data_operation[callback_id].isGivingGift == true then
                    self.query_player_data_operation[callback_id].func(self,__data.actor_id,playerdata,__data.item_name,__data.item_id,__data.item_count,__data.friend_value,__data.flower_count)
                else
                    self.query_player_data_operation[callback_id].func(self,__data.actor_id,playerdata)
                end
            end
        end
        self.query_player_data_operation[callback_id] = nil
    end
end

local function get_online_friend_info(self,other,dict)
    if other ~= nil then
        dict.actor_name = other:get("actor_name")
        dict.sex = other:get("sex")
        dict.vocation = other:get("vocation")
        dict.level = other:get("level")
        dict.mood = ""
        dict.offlinetime = 0
        return true
    end
    return false
end

local function get_offline_friend_info(self,player_data,dict)
    if player_data ~= nil then
        dict.actor_name = player_data.actor_name or ""
        dict.sex = player_data.sex or 1
        dict.vocation = player_data.vocation or 1
        dict.level = player_data.level or 1
        dict.mood = ""
        dict.offlinetime = player_data.offlinetime or 0
        return true
    end
    return false
end

local function is_in_other_blacklist_offline(self,player_data)
    if player_data ~= nil and player_data.friends ~= nil and player_data.friends.blacklist ~= nil and player_data.friends.blacklist[self:get("actor_id")] ~= nil then
        return true
    end
    return false
end

local function is_same_country_online(self,other)
    if other == nil then
        return false
    end
    if other:get("country") == self:get("country") then
        return true
    end
    return false
end

local function is_same_country_offline(self,player_data)
    if player_data == nil then
        return false
    end
    if player_data ~= nil and player_data.country ~= nil and self:get("country") == player_data.country then
        return true
    end
    return false
end

local function is_full_offline(self,player_data,operation)
    if player_data ~= nil then
        if player_data.friends == nil then
            return true
        end
        local p = 0
        local count = 0
        if operation == "friend" then
            p = friend_parameter[2].Value
            for i,_ in pairs(player_data.friends.friends) do
                count = count + 1
            end
        elseif operation == "enemy" then
            p = friend_parameter[5].Value
            for i,_ in pairs(player_data.friends.enemys) do
                count = count + 1
            end
        elseif operation == "applicant" then
            p = friend_parameter[13].Value
            for i,_ in pairs(player_data.friends.applicants) do
                count = count + 1
            end
        elseif operation == "blacklist" then
            p = friend_parameter[4].Value
            for i,_ in pairs(player_data.friends.blacklist) do
                count = count + 1
            end
        end
        if p <= count then
            return true
        else
            return false
        end
    end
    return true
end

local function is_friend_offline(self,player_data)
    if player_data.friends == nil or player_data.friends.friends == nil or player_data.friends.friends[self:get("actor_id")] == nil then
         return false
    end
    return true
end

local function is_applicant_offline(self,player_data)
    if player_data.friends == nil or player_data.friends.applicants == nil or player_data.friends.applicants[self:get("actor_id")] == nil then
         return false
    end
    return true
end

local function is_enemy_offline(self,player_data)
    if player_data.friends == nil or player_data.friends.enemys == nil or player_data.friends.enemys[self:get("actor_id")] == nil then
        return false
    end
    return true
end

--计算新的好友值
local function get_new_friend_value(self,value,addon,reason)
    local new_value = value
    if addon > 0 then
        --非道具原因增加友好值受到限制
        if value >= friend_parameter[9].Value and reason ~= FRIEND_VALUE_UPDATE_REASON.prop then
            return new_value
        end
    end
    if reason == FRIEND_VALUE_UPDATE_REASON.blacklist then
        --加入黑名单好友值直接为1
        new_value = 1
    else
        new_value = value + addon
    end

    if new_value < 1 then
        new_value = 1
    elseif new_value > friend_parameter[18].Value then
        new_value = friend_parameter[18].Value
    end
    return new_value
end

local function update_offline_friend_value(self,actor_id,player_data,new_value)
    if player_data ~= nil then
        if player_data.friends == nil or player_data.friends.friends == nil or player_data.friends.friends[self:get("actor_id")] == nil then
            return
        end
        player_data.friends.friends[self:get("actor_id")].friend_value = new_value
    end
end

--获取对方说话时间
local function get_other_talk_time_offline(self,player_data)
    local self_actor_id = self:get("actor_id")
    if player_data ~= nil then
        if player_data.friends == nil or player_data.friends.friends == nil or player_data.friends.friends[self_actor_id] == nil or player_data.friends.friends[self_actor_id].talktime == nil then
            return 0
        end
        return player_data.friends.friends[self_actor_id].talktime
    end
    return 0
end

local function add_friend(self,actor_id)
    local friend = onlinerole.get_user(actor_id)
    if friend == nil then
        return
    end

    self.friends[actor_id] = {}
    self.friends[actor_id].actor_id = actor_id
    self.friends[actor_id].actor_name = friend:get("actor_name")
    self.friends[actor_id].sex = friend:get("sex")
    self.friends[actor_id].level = friend:get("level")
    self.friends[actor_id].vocation = friend:get("vocation")
    self.friends[actor_id].mood = ""
    self.friends[actor_id].friend_value = 1
    self.friends[actor_id].offlinetime = 0
    self.friends[actor_id].talktime = 0
end

local function add_applicant(self,actor_id)
    local applicant = onlinerole.get_user(actor_id)
    if applicant == nil then
        return
    end

    self.applicants[actor_id] = {}
    self.applicants[actor_id].actor_id = actor_id
    self.applicants[actor_id].actor_name = applicant:get("actor_name")
    self.applicants[actor_id].sex = applicant:get("sex")
    self.applicants[actor_id].level = applicant:get("level")
    self.applicants[actor_id].vocation = applicant:get("vocation")
    self.applicants[actor_id].mood = ""
    self.applicants[actor_id].friend_value = 1
    self.applicants[actor_id].offlinetime = 0
end

local function add_enemy(self,actor_id)
    local enemy = onlinerole.get_user(actor_id)
    if enemy == nil then
        return
    end
    self.enemys[actor_id] = {}
    self.enemys[actor_id].actor_id = actor_id
    self.enemys[actor_id].friend_value = 1
    self.enemys[actor_id].actor_name = enemy:get("actor_name")
    self.enemys[actor_id].sex = enemy:get("sex")
    self.enemys[actor_id].level = enemy:get("level")
    self.enemys[actor_id].vocation = enemy:get("vocation")
    self.enemys[actor_id].mood = ""
    self.enemys[actor_id].offlinetime = 0
end

local function write_data_to_client(self,dict,actor_id,data)
    dict.actor_id = data[actor_id].actor_id
    dict.actor_name = data[actor_id].actor_name
    dict.sex = data[actor_id].sex
    dict.vocation = data[actor_id].vocation
    dict.level = data[actor_id].level
    dict.friend_value = data[actor_id].friend_value
    dict.mood = data[actor_id].mood
    dict.offlinetime = data[actor_id].offlinetime
end

local function write_friends_to_client(self,dict)
    dict.friends = {}
    for i,v in pairs(self.friends) do
        dict.friends[i] = {}
        write_data_to_client(self,dict.friends[i],i,self.friends)
        dict.friends[i].team_id = self.friends[i].team_id
    end
end

local function write_applicants_to_client(self,dict)
    dict.applicants = {}
    for i,v in pairs(self.applicants) do
        dict.applicants[i] = {}
        write_data_to_client(self,dict.applicants[i],i,self.applicants)
    end
end

local function write_blacklist_to_client(self,dict)
    dict.blacklist = {}
    for i,v in pairs(self.blacklist) do
        dict.blacklist[i] = {}
        write_data_to_client(self,dict.blacklist[i],i,self.blacklist)
    end
end

local function write_enemys_to_client(self,dict)
    dict.enemys = {}
    for i,v in pairs(self.enemys) do
        dict.enemys[i] = {}
        write_data_to_client(self,dict.enemys[i],i,self.enemys)
    end
end

local function update_offline_player_friends_info(self,actor_id,player_data,operation)
    local self_id = self:get("actor_id")
    if player_data ~= nil then
        if operation == "add_friend" then
            if player_data.friends == nil then
                player_data.friends = {}
            end

            if player_data.friends.friends == nil then
                player_data.friends.friends = {}
            end

            player_data.friends.friends[self_id] = {}
            player_data.friends.friends[self_id].actor_id = self_id
            player_data.friends.friends[self_id].friend_value = 1
            player_data.friends.friends[self_id].talktime = 0
            data_base.db_update_doc(0, _db_callback_update_friends_data, "global_player", {actor_id = actor_id}, player_data, 1, 0)
        elseif operation == "delete_friend" then
            if player_data.friends ~= nil and player_data.friends.friends ~= nil and player_data.friends.friends[self_id] ~= nil then
                player_data.friends.friends[self_id] = nil
            end
            data_base.db_update_doc(0, _db_callback_update_friends_data, "global_player", {actor_id = actor_id}, player_data, 1, 0)
        elseif operation == "apply_friend" then
            if player_data.friends == nil then
                player_data.friends = {}
                player_data.friends.applicants = {}
            elseif player_data.friends.applicants == nil then
                player_data.friends.applicants = {}
            end
            player_data.friends.applicants[self_id] = {}
            player_data.friends.applicants[self_id].actor_id = self_id
            player_data.friends.applicants[self_id].friend_value = 1
            data_base.db_update_doc(0, _db_callback_update_friends_data, "global_player", {actor_id = actor_id}, player_data, 1, 0)
        elseif operation == "add_enemy" then
            --添加仇人时，把自己从对方好友列表删除
            if player_data.friends ~= nil then
                local dirty = false
                if player_data.friends.friends ~= nil and player_data.friends.friends[self_id] ~= nil then
                    player_data.friends.friends[self_id] = nil
                    dirty = true
                end
                if player_data.friends.applicants ~= nil and player_data.friends.applicants[self_id] ~= nil then
                    player_data.friends.applicants[self_id] = nil
                    dirty = true
                end
                if dirty then
                    data_base.db_update_doc(0, _db_callback_update_friends_data, "global_player", {actor_id = actor_id}, player_data, 1, 0)
                end
            end
        end
        return 0
    end
    return const.error_no_player
end

local function update_offline_player_chat_info(self,player_data,actor_id,actor_name,sex,vocation,level,msg_time,data,attach)
    if player_data ~= nil then
        if player_data.friends == nil then
            player_data.friends = {}
        end
        if player_data.friends.messages == nil then
            player_data.friends.messages = {}
        end
        if player_data.friends.messages[actor_id] == nil then
            player_data.friends.messages[actor_id] = {}
        end
        if attach == nil then
            table.insert(player_data.friends.messages[actor_id],{actor_id=actor_id,actor_name=actor_name,sex=sex,vocation=vocation,level=level,msg_time=msg_time,data=data})
        else
            table.insert(player_data.friends.messages[actor_id],{actor_id=actor_id,actor_name=actor_name,sex=sex,vocation=vocation,level=level,msg_time=msg_time,data=data,attach=attach})
        end
    end
end

function imp_global_friend.on_get_friend(self,input,syn_data)
    if input.flag == nil then
        return
    end
    self:imp_global_friend_send_friends_to_client(input.flag)
end

local function write_search_data_to_client(data,dict)
    dict.actor_id = data.actor_id
    dict.actor_name = data.actor_name
    dict.sex = data.sex
    dict.vocation = data.vocation
    dict.level = data.level
end

local function _search_offline_actor_name_callback(self,status,data,callback_id)
    if status == 0 or table.isEmptyOrNil(data) then
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_SEARCH,{result=0,search_results=self.search_callback[callback_id].search_results})
        self.search_callback[callback_id] = nil
        return
    end
    if data.actor_id ~= self.actor_id then
        self.search_callback[callback_id].search_results[data.actor_id] = {}
        write_search_data_to_client(data,self.search_callback[callback_id].search_results[data.actor_id])
    end
    self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_SEARCH,{result=0,search_results=self.search_callback[callback_id].search_results})
    self.search_callback[callback_id] = nil
end

function imp_global_friend.on_search_friend(self,input,syn_data)
    local result = 0
    if input.search_string == nil or string.len(input.search_string) < 2 or string_utf8len(input.search_string) < 2 or (string.len(input.search_string) > 24 and string_utf8len(input.search_string) > const.PLAYER_NAME_MAX_LENTH ) then
        result = const.error_friend_search_length
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_SEARCH,{result=result})
        return
    end
    if string.find(input.search_string,"[%[%]]") ~= nil then
        result = const.error_search_include_illegal_char
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_SEARCH,{result=result})
        return
    end
    local search_result_id = {}
    search_result_id = onlinerole.search_user_by_name(input.search_string)
    --直接搜的玩家id
    search_result_id[input.search_string] = true
    local search_results = {}
    local actor_id = self:get("actor_id")
    for aid,_ in pairs(search_result_id) do
        if aid ~= actor_id then
            local e = onlinerole.get_user(aid)
            if e ~= nil then
                search_results[aid] = {}
                write_search_data_to_client(e,search_results[aid])
            end
        end
    end
    local callback_id = data_base.db_find_one(self, _search_offline_actor_name_callback, "global_player", {actor_name = input.search_string}, {actor_name = 1, actor_id = 1,sex=1,vocation=1,level=1})
    self.search_callback[callback_id] = {}
    self.search_callback[callback_id].search_results = search_results
end

local function update_offline_player_applicants(self,actor_id,player_data)
    local result = 0
    --是否同一阵营
    if not is_same_country_offline(self,player_data) then
        result = const.error_friend_not_same_country
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
        return
    end

    --对方好友是否已满
    if is_full_offline(self,player_data,"friend") then
        result = const.error_friend_is_full
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
        return
    end

    --对方的申请列表是否已满
    if is_full_offline(self,player_data,"applicant") then
        result = const.error_friend_applicant_is_full
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
        return
    end

    --是否在他的申请列表中
    if is_applicant_offline(self,player_data) then
        result = const.error_friend_in_their_applicants
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
        return
    end

    --我是否是对方仇人
    if is_enemy_offline(self,player_data) then
        result = const.error_friend_in_their_enemys
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
        return
    end

    result = update_offline_player_friends_info(self,actor_id,player_data,"apply_friend")
    if result ~= 0 then
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
        return
    end
    self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
end

function imp_global_friend.on_apply_friend(self,input,syn_data)
    local result = 0
    if input.apply_actor_id == nil or input.apply_actor_id == self:get("actor_id") then
        return
    end

    --双方是否好友
    if self:imp_global_friend_is_friend(input.apply_actor_id) then
        result = const.error_friend_in_your_friends
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
        return
    end

    --对方是否在我的申请列表
    if self:imp_global_friend_is_applicant(input.apply_actor_id) then
        result = const.error_friend_in_your_applicants
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
        return
    end

    --对方是否我的仇人
    if self:imp_global_friend_is_enemy(input.apply_actor_id) then
        result = const.error_friend_in_your_enemys
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
        return
    end

    local invitee = onlinerole.get_user(input.apply_actor_id)
    if invitee == nil then
        --玩家不在线
        local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = input.apply_actor_id}, {})
        self.query_player_data_operation[callback_id] = {}
        self.query_player_data_operation[callback_id].actor_id = input.apply_actor_id
        self.query_player_data_operation[callback_id].func = update_offline_player_applicants
    else
        --是否同阵营
        if not is_same_country_online(self,invitee) then
            result = const.error_friend_not_same_country
            self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
            return
        end

        --对方申请列表是否已满
        if invitee:imp_global_friend_is_full("applicant") then
            result = const.error_friend_applicant_is_full
            self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
            return
        end

        --对方好友列表是否已满
        if invitee:imp_global_friend_is_full("friend") then
            result = const.error_friend_is_full
            self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
            return
        end

        --我是否在对方申请列表
        if invitee:imp_global_friend_is_applicant(self.actor_id) then
            result = const.error_friend_in_their_applicants
            self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
            return
        end

        --我是否是对方仇人
        if invitee:imp_global_friend_is_enemy(self.actor_id) then
            result = const.error_friend_in_their_enemys
            self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
            return
        end

        --加入对方的申请列表，并推送给对方
        invitee:imp_global_friend_add_applicant(self:get("actor_id"))
        invitee:imp_global_friend_send_friends_to_client("applicants")
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_APPLY,{result=result})
    end
end

local function update_offline_player_friends(self,actor_id,player_data)
    local result = 0
    --是否同一阵营
    if not is_same_country_offline(self,player_data) then
        flog("tmlDebug","is not same country!")
        return
    end

    --对方好友是否已满
    if is_full_offline(self,player_data,"friend") then
        flog("tmlDebug","his friend is full!")
        return
    end

    --我是否是对方仇人
    if is_enemy_offline(self,player_data) then
        flog("tmlDebug","i am his enemy!")
        return
    end

    result = update_offline_player_friends_info(self,actor_id,player_data,"add_friend")
    if result ~= 0 then
        return
    end
    self:imp_global_friend_add_friend_offline(actor_id,player_data)
    self:on_accept_friend_ret(player_data.actor_name)
    local result_accept = {}
    write_applicants_to_client(self,result_accept)
    write_friends_to_client(self,result_accept)
    self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_ACCEPT,{result=result,contracts=result_accept})
end

function imp_global_friend.on_accept_friend(self,input,syn_data)
    local result = 0
    if input.accept == nil or input.actor_ids == nil or #input.actor_ids == 0 then
        return
    end
    local friend = nil
    for _,v in pairs(input.actor_ids) do
        if input.accept == true then
            if not self:imp_global_friend_is_full("friend") and not self:imp_global_friend_is_enemy(v) then
                friend = onlinerole.get_user(v)
                if friend ~= nil then
                    if not friend:imp_global_friend_is_enemy(self:get("actor_id")) and is_same_country_online(self,friend) and not friend:imp_global_friend_is_full("friend") then
                        self:imp_global_friend_add_friend(v)
                        self:on_accept_friend_ret(friend.actor_name)
                        friend:imp_global_friend_add_friend(self:get("actor_id"))
                        friend:imp_global_friend_send_friends_to_client("friends")
                        friend:on_accept_friend_ret(self.actor_name)
                    end
                else
                    --对方不在线
                    local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = v}, {})
                    self.query_player_data_operation[callback_id] = {}
                    self.query_player_data_operation[callback_id].actor_id = v
                    self.query_player_data_operation[callback_id].func = update_offline_player_friends
                end
            end
        end
        self.applicants[v] = nil
    end

    local result_accept = {}
    write_friends_to_client(self,result_accept)
    write_applicants_to_client(self,result_accept)
    self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_ACCEPT,{result=result,contracts=result_accept})
end

local function delete_offline_player_friends(self,actor_id,player_data)
    update_offline_player_friends_info(self,actor_id,player_data,"delete_friend")
end

function imp_global_friend.on_delete_friend(self,input,syn_data)
    local result = 0
    if input.delete_actor_id == nil then
        return
    end
    local delete_actor_id = input.delete_actor_id
    local friend = onlinerole.get_user(delete_actor_id)
    if friend == nil then
        --对方不在线
        self:imp_global_friend_delete_friend(delete_actor_id)
        local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = delete_actor_id}, {})
        self.query_player_data_operation[callback_id] = {}
        self.query_player_data_operation[callback_id].actor_id = delete_actor_id
        self.query_player_data_operation[callback_id].func = delete_offline_player_friends
    else
        self:imp_global_friend_delete_friend(delete_actor_id)
        friend:imp_global_friend_delete_friend(self:get("actor_id"))
        friend:imp_global_friend_send_friends_to_client("friends")
    end
    local delete_result = {}
    write_friends_to_client(self,delete_result)
    self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_DELETE,{result=result,contracts=delete_result})
end

local function update_offline_blacklist_info(self,actor_id,player_data)
    local result = 0
    self.blacklist[actor_id] = {}
    self.blacklist[actor_id].actor_id = actor_id
    self.blacklist[actor_id].friend_value = 1
    get_offline_friend_info(self,player_data,self.blacklist[actor_id])
    --更新好友值
    if self:imp_global_friend_is_friend(actor_id) then
        local new_value = get_new_friend_value(self,self.friends[actor_id].friend_value,0,FRIEND_VALUE_UPDATE_REASON.blacklist)
        self:imp_global_friend_update_friend_value(actor_id,new_value)
        update_offline_friend_value(self,actor_id,player_data,new_value)
        data_base.db_update_doc(0, _db_callback_update_friends_data, "global_player", {actor_id = actor_id}, player_data, 1, 0)
    end
    self:on_add_blacklist_ret(player_data.actor_name)
    local results = {}
    write_blacklist_to_client(self,results)
    self:send_message_to_client(const.SC_MESSAGE_LUA_BLACKLIST_ADD,{result=result,contracts=results})
end

function imp_global_friend.on_add_blacklist(self,input,syn_data)
    local result = 0
    if input.blacklist_actor_id == nil then
        return
    end

    local blacklist_actor_id = input.blacklist_actor_id

    if self:imp_global_friend_is_full("blacklist") then
        result = const.error_friend_blacklist_is_full
        self:send_message_to_client(const.SC_MESSAGE_LUA_BLACKLIST_ADD,{result=result})
        return
    end

    local other = onlinerole.get_user(blacklist_actor_id)
    if other ~= nil then
        self.blacklist[blacklist_actor_id] = {}
        self.blacklist[blacklist_actor_id].actor_id = blacklist_actor_id
        self.blacklist[blacklist_actor_id].friend_value = 1
        get_online_friend_info(self,other,self.blacklist[blacklist_actor_id])
        --更新好友值
        if self:imp_global_friend_is_friend(blacklist_actor_id) then
            local new_value = get_new_friend_value(self,self.friends[blacklist_actor_id].friend_value,0,FRIEND_VALUE_UPDATE_REASON.blacklist)
            self:imp_global_friend_update_friend_value(blacklist_actor_id,new_value)
            other:imp_global_friend_update_friend_value(self:get("actor_id"),new_value)
        end
        local results = {}
        write_blacklist_to_client(self,results)
        self:send_message_to_client(const.SC_MESSAGE_LUA_BLACKLIST_ADD,{result=result,contracts=results})
        self:on_add_blacklist_ret(other.actor_name)
    else
        local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = blacklist_actor_id}, {})
        self.query_player_data_operation[callback_id] = {}
        self.query_player_data_operation[callback_id].actor_id = blacklist_actor_id
        self.query_player_data_operation[callback_id].func = update_offline_blacklist_info
    end
end

function imp_global_friend.on_delete_blacklist(self,input,syn_data)
    local result = 0
    if input.delete_actor_id == nil then
        return
    end
    local delete_actor_id = input.delete_actor_id
    self:imp_global_friend_delete_blacklist(delete_actor_id)
    local results = {}
    write_blacklist_to_client(self,results)
    self:send_message_to_client(const.SC_MESSAGE_LUA_BLACKLIST_DELETE,{result=result,contracts = results})
end

local function update_offline_enemys_info(self,actor_id,player_data)
    local result = 0
    self.enemys[actor_id] = {}
    self.enemys[actor_id].actor_id = actor_id
    self.enemys[actor_id].friend_value = 1
    if get_offline_friend_info(self,player_data,self.enemys[actor_id]) then
        update_offline_player_friends_info(self,actor_id,player_data,"add_enemy")
        self:imp_global_friend_delete_friend(actor_id)
        self:imp_global_friend_delete_applicant(actor_id)
        local results = {}
        write_enemys_to_client(self,results)
        write_friends_to_client(self,results)
        write_applicants_to_client(self,results)
        self:send_message_to_client(const.SC_MESSAGE_LUA_ENEMY_ADD,{result=result,contracts=results})
    end
end

function imp_global_friend.on_add_enemy(self,input,syn_data)
    local result = 0
    if input.enemy_actor_id == nil then
        return
    end
    local enemy_actor_id = input.enemy_actor_id
    if self:imp_global_friend_is_full("enemy") then
        result = const.error_friend_enemy_is_full
        self:send_message_to_client(const.SC_MESSAGE_LUA_BLACKLIST_ADD,{result=result})
        return
    end

    local enemy = onlinerole.get_user(enemy_actor_id)
    if enemy ~= nil then
        if not is_same_country_online(self,enemy) then
            result = const.error_friend_not_same_country
            self:send_message_to_client(const.SC_MESSAGE_LUA_ENEMY_ADD,{result=result})
            return
        end
        enemy:imp_global_friend_delete_friend(self:get("actor_id"))
        enemy:imp_global_friend_delete_applicant(self:get("actor_id"))
        enemy:imp_global_friend_send_friends_to_client("all")
        self:imp_global_friend_delete_friend(enemy_actor_id)
        self:imp_global_friend_delete_applicant(enemy_actor_id)
        self.enemys[enemy_actor_id] = {}
        self.enemys[enemy_actor_id].actor_id = enemy_actor_id
        self.enemys[enemy_actor_id].friend_value = 1
        get_online_friend_info(self,enemy,self.enemys[enemy_actor_id])
        local results = {}
        write_enemys_to_client(self,results)
        write_friends_to_client(self,results)
        write_applicants_to_client(self,results)
        self:send_message_to_client(const.SC_MESSAGE_LUA_ENEMY_ADD,{result=result,contracts=results})
    else
        local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = enemy_actor_id}, {})
        self.query_player_data_operation[callback_id] = {}
        self.query_player_data_operation[callback_id].actor_id = enemy_actor_id
        self.query_player_data_operation[callback_id].func = update_offline_enemys_info
    end

end

function imp_global_friend.on_delete_enemy(self,input,syn_data)
    local result = 0
    if input.enemy_actor_id == nil then
        return
    end
    local enemy_actor_id = input.enemy_actor_id
    self:imp_global_friend_delete_enemy(enemy_actor_id)
    local results = {}
    write_enemys_to_client(self,results)
    self:send_message_to_client(const.SC_MESSAGE_LUA_ENEMY_DELETE,{result=result,contracts=results})
end

local function update_offline_friend_chat(self,actor_id,player_data,data,attach)
    local result = 0
    local time = _get_now_time_second()
    if is_in_other_blacklist_offline(self,player_data) then
        result = const.error_friend_in_their_blacklist
        self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_CHAT , {result = result})
        return
    end
    self:imp_global_friend_send_friend_chat(actor_id,self:get("actor_id"),self:get("actor_name"),self:get("sex"),self:get("vocation"),self:get("level"),time,data,attach)
    update_offline_player_chat_info(self,player_data,self:get("actor_id"),self:get("actor_name"),self:get("sex"),self:get("vocation"),self:get("level"),time,data,attach)
    --说话时间
    local talk = false
    if self.friends[actor_id] ~= nil then
        local current_time = os.date("*t", time)
        local start_time = os.time({year=current_time.year, month=current_time.month, day=current_time.day, hour=0,min=0,sec=0,isdst=false})
        local end_time = os.time({year=current_time.year, month=current_time.month, day=current_time.day, hour=23,min=59,sec=59,isdst=false})
        --我今天没跟对方说过话
        if self.friends[actor_id].talktime == nil or self.friends[actor_id].talktime == 0 or self.friends[actor_id].talktime < start_time then
            --对方说话时间
            local other_talk_time = get_other_talk_time_offline(self,player_data)
            --对方已对我说过话了，增加好友值
            if other_talk_time >= start_time then
                local new_value = get_new_friend_value(self,self.friends[actor_id].friend_value,1,FRIEND_VALUE_UPDATE_REASON.talk)
                self:imp_global_friend_update_friend_value(actor_id,new_value)
                update_offline_friend_value(self,actor_id,player_data,new_value)
            end
        end
        self.friends[actor_id].talktime = time
    end
    data_base.db_update_doc(0, _db_callback_update_friends_data, "global_player", {actor_id = actor_id}, player_data, 1, 0)
end

function imp_global_friend.on_friend_chat(self,input,syn_data)
    local result = 0
    if input.chat_friend_id == nil or input.data == nil or input.chat_friend_id == self.actor_id then
        return
    end

    local chat_friend_id = input.chat_friend_id

    local time = _get_now_time_second()

    local player = onlinerole.get_user(chat_friend_id)
    if player ~= nil then
        if player:imp_global_friend_is_blacklist(self:get("actor_id")) then
            result = const.error_friend_in_their_blacklist
            self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_CHAT , {result = result})
            return
        end
        self:imp_global_friend_send_friend_chat(chat_friend_id,self:get("actor_id"),self:get("actor_name"),self:get("sex"),self:get("vocation"),self:get("level"),time,input.data,input.attach)
        player:imp_global_friend_send_friend_chat(self:get("actor_id"),self:get("actor_id"),self:get("actor_name"),self:get("sex"),self:get("vocation"),self:get("level"),time,input.data,input.attach)
        --说话时间
        local talk = false
        if self.friends[chat_friend_id] ~= nil then
            local current_time = os.date("*t", time)
            local start_time = os.time({year=current_time.year, month=current_time.month, day=current_time.day, hour=0,min=0,sec=0,isdst=false})
            local end_time = os.time({year=current_time.year, month=current_time.month, day=current_time.day, hour=23,min=59,sec=59,isdst=false})
            --我今天没跟对方说过话
            if self.friends[chat_friend_id].talktime == nil or self.friends[chat_friend_id].talktime == 0 or self.friends[chat_friend_id].talktime < start_time then
                --对方说话时间
                local other_talk_time = player:imp_global_friend_get_talktime(self:get("actor_id"))
                --对方已对我说过话了，增加好友值
                if other_talk_time >= start_time then
                    local new_value = get_new_friend_value(self,self.friends[chat_friend_id].friend_value,1,FRIEND_VALUE_UPDATE_REASON.talk)
                    self:imp_global_friend_update_friend_value(chat_friend_id,new_value)
                    player:imp_global_friend_update_friend_value(self:get("actor_id"),new_value)
                end
            end
            self.friends[chat_friend_id].talktime = time
        end
    else
        --对方不在线
        local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = chat_friend_id}, {})
        self.query_player_data_operation[callback_id] = {}
        self.query_player_data_operation[callback_id].actor_id = chat_friend_id
        self.query_player_data_operation[callback_id].func = update_offline_friend_chat
        self.query_player_data_operation[callback_id].isChat = true
        self.query_player_data_operation[callback_id].data = input.data
        self.query_player_data_operation[callback_id].attach = input.attach
    end
end

local function init_query_friend_info(self,actor_id,player_data)
    get_offline_friend_info(self,player_data,self.friends[actor_id])
end

local function init_query_applicant_info(self,actor_id,player_data)
    get_offline_friend_info(self,player_data,self.applicants[actor_id])
end

local function init_query_blacklist_info(self,actor_id,player_data)
    get_offline_friend_info(self,player_data,self.blacklist[actor_id])
end

local function init_query_enemy_info(self,actor_id,player_data)
    get_offline_friend_info(self,player_data,self.enemys[actor_id])
end

local function update_receive_flower_count_callback(self, status, playerdata,callback_id)
    if status == false or playerdata == nil then
        flog("error","imp_global_friend update_receive_flower_count_callback,actor id:"..self.update_receive_flower_count[callback_id].actor_id)
    end
    self.update_receive_flower_count[callback_id] = nil
end

local function gift_giving_to_offline_friend(self,actor_id,player_data,item_name,item_id,item_count,friend_value,flower_count)
    local result = 0
    local time = _get_now_time_second()
    --通知消息
    local chat_data = string_format(common_char_chinese_config.get_back_text(2135002),self:get("actor_name"),player_data.actor_name,item_name,item_count)
    update_offline_player_chat_info(self,player_data,self:get("actor_id"),self:get("actor_name"),self:get("sex"),self:get("vocation"),self:get("level"),time,chat_data,nil)
    --更新好友值
    flog("tmlDebug","friend_value:"..friend_value)
    local new_value = get_new_friend_value(self,self.friends[actor_id].friend_value,friend_value,FRIEND_VALUE_UPDATE_REASON.prop)
    flog("tmlDebug","friend_value:"..new_value)
    self:imp_global_friend_update_friend_value(actor_id,new_value)
    update_offline_friend_value(self,actor_id,player_data,new_value)
    data_base.db_update_doc(0, _db_callback_update_friends_data, "global_player", {actor_id = actor_id}, player_data, 1, 0)
    --返回Game及客户端
    self:imp_global_friend_send_friends_to_client("friends")
    self:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_global_giving_gift",result=result,item_count=item_count,item_id=item_id,flower_count=flower_count})
    local callback_id = data_base.db_find_and_modify(self,update_receive_flower_count_callback,"actor_info",{actor_id=actor_id},{["$inc"]={receive_friend_flower_count=flower_count}},{},0)
    self.update_receive_flower_count[callback_id] = {}
    self.update_receive_flower_count[callback_id].actor_id = actor_id
end

function imp_global_friend.on_giving_gift(self,input,sync_data)
    local result = 0
    if input.friend_value == nil or input.receive_actor_id == nil or input.item_name == nil or input.item_count == nil then
        return
    end

    local receive_actor_id = input.receive_actor_id

    if self:imp_global_friend_is_friend(receive_actor_id) == false then
        result = const.error_friend_not_friend
        self:send_message_to_client(const.SC_MESSAGE_LUA_GAME_RPC,{result=result})
        return
    end

    local friend = onlinerole.get_user(receive_actor_id)
    if friend ~= nil then
        local new_value = get_new_friend_value(self,self.friends[receive_actor_id].friend_value,input.friend_value,FRIEND_VALUE_UPDATE_REASON.prop)
        self:imp_global_friend_update_friend_value(receive_actor_id,new_value)
        friend:imp_global_friend_update_friend_value(self:get("actor_id"),new_value)
        friend:imp_global_friend_send_friends_to_client("friends")
        local chat_data = string_format(common_char_chinese_config.get_back_text(2135002),self:get("actor_name"),friend:get("actor_name"),input.item_name,input.item_count)
        friend:imp_global_friend_send_friend_chat(self:get("actor_id"),self:get("actor_id"),self:get("actor_name"),self:get("sex"),self:get("vocation"),self:get("level"),_get_now_time_second(),chat_data,nil)
        self:imp_global_friend_send_friends_to_client("friends")
        self:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_global_giving_gift",result=result,item_count=input.item_count,item_id=input.item_id,flower_count=input.flower_count})
        friend:send_message_to_game(const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_global_receive_gift",result=result,flower_count=input.flower_count})
    else
        --对方不在线
        local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = receive_actor_id}, {})
        self.query_player_data_operation[callback_id] = {}
        self.query_player_data_operation[callback_id].actor_id = receive_actor_id
        self.query_player_data_operation[callback_id].item_name = input.item_name
        self.query_player_data_operation[callback_id].item_count = input.item_count
        self.query_player_data_operation[callback_id].friend_value = input.friend_value
        self.query_player_data_operation[callback_id].item_id = input.item_id
        self.query_player_data_operation[callback_id].isGivingGift = true
        self.query_player_data_operation[callback_id].flower_count = input.flower_count
        self.query_player_data_operation[callback_id].func = gift_giving_to_offline_friend
    end
end

function imp_global_friend.imp_global_friend_init_from_dict(self, dict)
    local friend = nil
    local friend_info = table.get(dict, "friends", {})
    if friend_info.friends ~= nil then
        for i,v in pairs(friend_info.friends) do
            self.friends[i] = {}
            self.friends[i].actor_id = i
            self.friends[i].friend_value = friend_info.friends[i].friend_value or 0
            self.friends[i].talktime = friend_info.friends[i].talktime or 0
            friend = onlinerole.get_user(i)
            if friend ~= nil then
                get_online_friend_info(self,friend,self.friends[i])
            else
                --对方不在线
                local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = i}, {})
                self.query_player_data_operation[callback_id] = {}
                self.query_player_data_operation[callback_id].actor_id = i
                self.query_player_data_operation[callback_id].func = init_query_friend_info
            end
        end
    end

    if friend_info.applicants ~= nil then
        for i,v in pairs(friend_info.applicants) do
            self.applicants[i] = {}
            self.applicants[i].actor_id = i
            self.applicants[i].friend_value = friend_info.applicants[i].friend_value
            friend = onlinerole.get_user(i)
            if friend ~= nil then
                get_online_friend_info(self,friend,self.applicants[i])
            else
                --对方不在线
                local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = i}, {})
                self.query_player_data_operation[callback_id] = {}
                self.query_player_data_operation[callback_id].actor_id = i
                self.query_player_data_operation[callback_id].func = init_query_applicant_info
            end
        end
    end

    if friend_info.blacklist ~= nil then
        for i,v in pairs(friend_info.blacklist) do
            self.blacklist[i] = {}
            self.blacklist[i].actor_id = i
            self.blacklist[i].pre_flag = friend_info.blacklist[i].pre_flag
            self.blacklist[i].friend_value = friend_info.blacklist[i].friend_value
            friend = onlinerole.get_user(i)
            if friend ~= nil then
                get_online_friend_info(self,friend,self.blacklist[i])
            else
                --对方不在线
                local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = i}, {})
                self.query_player_data_operation[callback_id] = {}
                self.query_player_data_operation[callback_id].actor_id = i
                self.query_player_data_operation[callback_id].func = init_query_blacklist_info
            end
        end
    end

    if friend_info.enemys ~= nil then
        for i,v in pairs(friend_info.enemys) do
            self.enemys[i] = {}
            self.enemys[i].actor_id = i
            self.enemys[i].friend_value = friend_info.enemys[i].friend_value
            friend = onlinerole.get_user(i)
            if friend ~= nil then
                get_online_friend_info(self,friend,self.enemys[i])
            else
                --对方不在线
                local callback_id = data_base.db_find_one(self, _db_callback_offline_player_data, "global_player", {actor_id = i}, {})
                self.query_player_data_operation[callback_id] = {}
                self.query_player_data_operation[callback_id].actor_id = i
                self.query_player_data_operation[callback_id].func = init_query_enemy_info
            end
        end
    end

    if friend_info.messages ~= nil then
        self.friend_messages = friend_info.messages
    end
end

function imp_global_friend.imp_global_friend_write_to_dict(self, dict)
    dict.friends = {}
    dict.friends.friends = {}
    for _,v in pairs(self.friends) do
        dict.friends.friends[v.actor_id] = {}
        dict.friends.friends[v.actor_id].actor_id = v.actor_id
        dict.friends.friends[v.actor_id].friend_value = v.friend_value or 1
        dict.friends.friends[v.actor_id].talktime = v.talktime
    end

    dict.friends.applicants = {}
    for _,v in pairs(self.applicants) do
        dict.friends.applicants[v.actor_id] = {}
        dict.friends.applicants[v.actor_id].actor_id = v.actor_id
        dict.friends.applicants[v.actor_id].friend_value = v.friend_value
    end

    dict.friends.blacklist = {}
    for _,v in pairs(self.blacklist) do
        dict.friends.blacklist[v.actor_id] = {}
        dict.friends.blacklist[v.actor_id].actor_id = v.actor_id
        dict.friends.blacklist[v.actor_id].friend_value = v.friend_value
    end

    dict.friends.enemys = {}
    for _,v in pairs(self.enemys) do
        dict.friends.enemys[v.actor_id] = {}
        dict.friends.enemys[v.actor_id].actor_id = v.actor_id
        dict.friends.enemys[v.actor_id].friend_value = v.friend_value
    end
end

function imp_global_friend.imp_global_friend_write_to_sync_dict(self, dict)
    write_friends_to_client(self,dict)
    write_applicants_to_client(self,dict)
    write_blacklist_to_client(self,dict)
    write_enemys_to_client(self,dict)
end

--好友
function imp_global_friend.imp_global_friend_is_friend(self,actor_id)
    flog("tmlDebug","actor_id "..actor_id)
    flog("tmlDebug","self.friends "..table.serialize(self.friends))
    if self.friends[actor_id] ~= nil then
        return true
    end
    return false
end

--陌生人
function imp_global_friend.imp_global_friend_is_stranger(self,actor_id)
    if self.strangers[actor_id] ~= nil then
        return true
    end
    return false
end

--申请者
function imp_global_friend.imp_global_friend_is_applicant(self,actor_id)
    if self.applicants[actor_id] ~= nil then
        return true
    end
    return false
end

--黑名单
function imp_global_friend.imp_global_friend_is_blacklist(self,actor_id)
    if self.blacklist[actor_id] ~= nil then
        return true
    end
    return false
end

--仇人
function imp_global_friend.imp_global_friend_is_enemy(self,actor_id)
    if self.enemys[actor_id] ~= nil then
        return true
    end
    return false
end

--新增申请者
function imp_global_friend.imp_global_friend_add_applicant(self,actor_id)
    local applicant = onlinerole.get_user(actor_id)
    if applicant == nil then
        return
    end

    --加入申请列表
    add_applicant(self,actor_id)
end

--删除申请者
function imp_global_friend.imp_global_friend_delete_applicant(self,actor_id)
    if self.applicants[actor_id] ~= nil then
        self.applicants[actor_id] = nil
    end
end

--新增好友
function imp_global_friend.imp_global_friend_add_friend(self,actor_id)
    if self:imp_global_friend_is_friend(actor_id) == false then
        add_friend(self,actor_id)
    end
end

--新增不在线好友
function imp_global_friend.imp_global_friend_add_friend_offline(self,actor_id,playerdata)
    if self:imp_global_friend_is_friend(actor_id) == false then
        self.friends[actor_id] = {}
        self.friends[actor_id].actor_id = actor_id
        get_offline_friend_info(self,playerdata,self.friends[actor_id])
        self.friends[actor_id].friend_value = 1
        self.friends[actor_id].talktime = 0
    end
end

function imp_global_friend.imp_global_friend_delete_friend(self,actor_id)
    if self.friends[actor_id] ~= nil then
        self.friends[actor_id] = nil
    end
end

function imp_global_friend.imp_global_friend_delete_blacklist(self,actor_id)
    if self.blacklist[actor_id] ~= nil then
        self.blacklist[actor_id] = nil
    end
end

function imp_global_friend.imp_global_friend_add_enemy(self,actor_id)
    return add_enemy(self,actor_id)
end

function imp_global_friend.imp_global_friend_delete_enemy(self,actor_id)
    if self.enemys[actor_id] ~= nil then
        self.enemys[actor_id] = nil
    end
end

function imp_global_friend.imp_global_friend_send_friends_to_client(self,flag)
    local return_friends = {}
    if flag == "all" then
        self:imp_global_friend_write_to_sync_dict(return_friends)
        self:imp_global_friend_offline_messages(return_friends)
    elseif flag == "friends" then
        write_friends_to_client(self,return_friends)
    elseif flag == "applicants" then
        write_applicants_to_client(self,return_friends)
    elseif flag == "blacklist" then
        write_blacklist_to_client(self,return_friends)
    elseif flag == "enemys" then
        write_enemys_to_client(self,return_friends)
    end
    self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_GET , {result = 0,contracts = return_friends})
end

function imp_global_friend.imp_global_friend_send_friend_chat(self,other,actor_id,actor_name,sex,vocation,level,msg_time,data,attach)
    local messages = {}
    messages.friend_msg = {}
    messages.friend_msg[other] = {}
    if attach == nil then
        table.insert(messages.friend_msg[other],{actor_id=actor_id,actor_name=actor_name,sex=sex,vocation=vocation,level=level,msg_time=msg_time,data=data})
    else
        table.insert(messages.friend_msg[other],{actor_id=actor_id,actor_name=actor_name,sex=sex,vocation=vocation,level=level,msg_time=msg_time,data=data,attach=attach})
    end

    self:send_message_to_client(const.SC_MESSAGE_LUA_FRIEND_CHAT , {result = 0,messages=messages})
end

function imp_global_friend.imp_global_friend_offline_messages(self,dict)
    dict.offline_messages = {}
    if not table.isEmptyOrNil(self.friend_messages) then
        dict.offline_messages.friend_msg = self.friend_messages
        self.friend_messages = {}
    end
end

function imp_global_friend.imp_global_friend_update_offlinetime(self,actor_id,offlinetime)
    if self.friends[actor_id] ~= nil then
        self.friends[actor_id].offlinetime = offlinetime
    end
    if self.applicants[actor_id] ~= nil then
        self.applicants[actor_id].offlinetime = offlinetime
    end
    if self.enemys[actor_id] ~= nil then
        self.enemys[actor_id].offlinetime = offlinetime
    end
    if self.blacklist[actor_id] ~= nil then
        self.blacklist[actor_id].offlinetime = offlinetime
    end
end

function imp_global_friend.imp_global_friend_main_reds(self,dict)
    if not table.isEmptyOrNil(self.friend_messages) then
        dict.offline_message = true
    else
        dict.offline_message = false
    end
    if not table.isEmptyOrNil(self.applicants) then
        dict.friend_applicants = true
    else
        dict.friend_applicants = false
    end
end

function imp_global_friend.imp_global_friend_is_full(self,operation)
    local p = 0
    local count = 0
    if operation == "friend" then
        p = friend_parameter[2].Value
        for i,_ in pairs(self.friends) do
            count = count + 1
        end
    elseif operation == "enemy" then
        p = friend_parameter[5].Value
        for i,_ in pairs(self.enemys) do
            count = count + 1
        end
    elseif operation == "applicant" then
        p = friend_parameter[13].Value
        for i,_ in pairs(self.applicants) do
            count = count + 1
        end
    elseif operation == "blacklist" then
        p = friend_parameter[4].Value
        for i,_ in pairs(self.blacklist) do
            count = count + 1
        end
    end
    if p <= count then
        return true
    end
    return false
end

--更新与actor_id的好友值
function imp_global_friend.imp_global_friend_update_friend_value(self,actor_id,new_value)
    if self.friends[actor_id] ~= nil then
        self.friends[actor_id].friend_value = new_value
    end
end

function imp_global_friend.imp_global_friend_get_talktime(self,actor_id)
    if self.friends[actor_id] ~= nil then
        return self.friends[actor_id].talktime
    end
    return 0
end

function imp_global_friend.on_killer_player_update_friend_value(self,input)
    if input.killer_id == nil then
        return
    end

    local killer = onlinerole.get_user(input.killer_id)
    if killer == nil then
        flog("tmlDebug","imp_global_friend.on_killer_player_update_friend_value killer offline!")
        return
    end

    if self:imp_global_friend_is_friend(input.killer_id) == false then
        self:imp_global_friend_add_enemy(input.killer_id)
        self:imp_global_friend_delete_applicant(input.killer_id)
        self:imp_global_friend_send_friends_to_client("all")
        killer:imp_global_friend_delete_applicant(self.actor_id)
        self:imp_global_friend_send_friends_to_client("applicants")
    else
        self:imp_global_friend_update_friend_value(input.killer_id,1)
        self:imp_global_friend_send_friends_to_client("friends")
        killer:imp_global_friend_update_friend_value(self.actor_id,1)
        killer:imp_global_friend_send_friends_to_client("friends")
    end
end

function imp_global_friend.on_global_join_team(self,input)
    if input.team_id == nil then
        return
    end
    local all_user = onlinerole.get_all_user()
    for _,player in pairs(all_user) do
        player:player_join_team(self.actor_id,input.team_id)
    end
end

function imp_global_friend.player_join_team(self,actor_id,team_id)
    if self.friends[actor_id] ~= nil then
        self.friends[actor_id].team_id = team_id
    end
end

function imp_global_friend.on_global_left_team(self,input)
    local all_user = onlinerole.get_all_user()
    for _,player in pairs(all_user) do
        player:player_left_team(self.actor_id)
    end
end

function imp_global_friend.player_left_team(self,actor_id)
    if self.friends[actor_id] ~= nil then
        self.friends[actor_id].team_id = nil
    end
end

function imp_global_friend.on_accept_friend_ret(self,actor_name)
    self:send_message_to_client(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnAcceptFriendRet",actor_name=actor_name})
end

function imp_global_friend.on_add_blacklist_ret(self,actor_name)
    self:send_message_to_client(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnAddBlacklistRet",actor_name=actor_name})
end

return imp_global_friend

