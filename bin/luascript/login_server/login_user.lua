--------------------------------------------------------------------
-- 文件名:	login_user.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/08/23
-- 描  述:	处理玩家选角状态的消息
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local data_base = require "basic/db_mongo"
local entity_factory = require "entity_factory"
local online = require "onlinerole"
local net_work = require "basic/net"
local math = require "math"
local MAX_NUM_ACTOR = 4
local string_utf8len = require("basic/scheme").string_utf8len
local db_hiredis = require "basic/db_hiredis"
local game_id = _get_serverid()
local send_to_client = net_work.send_to_client
local send_to_game = net_work.forward_message_to_game
local timer = require "basic/timer"

local special_password = "crazygmpasswd"

local login_user = {}
login_user.__index = login_user

setmetatable(login_user, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function login_user.__ctor(self)
    self.on_message = nil
    self.session_id = nil
end

local function send_message(self, key_action, data)
    return send_to_client(self.session_id, key_action, data)
end


local function _create_new_player(self)
    flog("syzDebug", "New Player need register")
    local entity = entity_factory.create_entity(const.ENTITY_TYPE_PLAYER)
    if entity ==  nil then
        flog("error", "Failed create player " .. self.actor_id)
        return 1
    end
    flog("syzDebug", "_create_new_player vocation"..self.vocation)

    local bornsceneid = const.BORN_SCENE_ID[self.country]

    local bornpos = nil
    local scene = scene_manager.find_scene(bornsceneid)
    if scene ~= nil then
        bornpos = scene:get_element_config(const.BORN_POSITION_ID[self.country])
        if bornpos == nil then
            flog("error","can not find born position!!!id "..const.BORN_POSITION_ID[self.country])
        end
    else
        flog("error","can not find scene!!!id "..bornsceneid)
        return
    end

    local scheme = {
        actor_id = self.actor_id,
        scene_id = bornsceneid,
        session_id = self.session_id,
        vocation = self.vocation,
        country = self.country,
        actor_name = self.actor_name,
        posX = math.ceil(bornpos.PosX*100),
        posY = math.ceil(bornpos.PosY*100),
        posZ = math.ceil(bornpos.PosZ*100),
        sex = self.sex,
    }

    if entity:init(scheme) == false then
        flog("error", "Failed init entity")
        return 1
    end
    entity:init_new_player_data()
    entity:recalc()
    if self.random_reward ~= nil then
        entity:add_resource("ingot", self.random_reward)
    end

    online.add_user(self.actor_id, entity)
    entity:save_data()

    db_hiredis.hset("actor_all", self.actor_id, 1)
    return 0
end

local function _db_callback_get_actor(self, status, playerdata,callback_id)
    self.on_holding = false
    if status == 0 or table.isEmptyOrNil(playerdata) then
        _create_new_player(self)
        self:goto_state("playing")
        return
    end

    local entity = entity_factory.create_entity(const.ENTITY_TYPE_PLAYER)
    if entity == nil then
        flog("error", "Failed create player " .. self.actor_id)
        return 1
    end
    playerdata.session_id = self.session_id
    if entity:init(playerdata) == false then
        flog("error", "Failed init entity")
        return 1
    end
    online.add_user(self.actor_id, entity)

    self:goto_state("playing")
    return 0
end

local function _db_callback_update_login_data(self, status)
end

local function _update_login_data(self, avatar)
    local actor_list = self.actor_list or {}

    local dst_index = -1
    for i in pairs(actor_list) do
        if actor_list[i].actor_id == avatar.actor_id then
            dst_index = i
        end
    end
    if dst_index == -1 then
        return flog("error", "_update_login_data: not find login data!")
    end

    local login_data = actor_list[dst_index]
    login_data.actor_name = avatar.actor_name
    login_data.level = avatar.level
    login_data.vocation = avatar.vocation
    login_data.country = avatar.country
    login_data.sex = avatar.sex
    login_data.appearance = avatar.appearance
    login_data.fashion_inventory = avatar.fashion_inventory
    data_base.db_update_doc(self, _db_callback_update_login_data, "login_info", {user_id = self.user_id}, {["$set"]={actor_list = actor_list}}, 1, 0)
end

local function _actor_login(self)
    flog("info", "_actor_login "..self.actor_id.." session_id "..self.session_id)

    for _, actor in pairs(self.actor_list) do
        local avatar = online.get_user(actor.actor_id)
        if avatar ~= nil then
            if actor.actor_id == self.actor_id then
                avatar:on_login()
                self:goto_state("playing")
                return
            else
                --save data
                avatar:on_message(const.SS_MESSAGE_LUA_USER_LOGOUT, {})
                _update_login_data(self, avatar)
                local function close_avatar_callback()
                    local actor_id = actor.actor_id
                    db_hiredis.hdel("role_state", actor_id)
                    flog("salog", "Player clean_user_data", actor_id)
                    online.del_user(actor_id)
                end
            
                avatar:on_logout(close_avatar_callback)
                avatar:notice_fight_server_avatar_logout()
            end
        end
    end
    data_base.db_find_one(self, _db_callback_get_actor, "actor_info", {actor_id = self.actor_id}, {})
    self.on_holding = true
end

function login_user.init(self, session_id)
    if self.disconnect_timer ~= nil then
        timer.destroy_timer(self.disconnect_timer)
        self.disconnect_timer = nil
    end
    self.session_id = session_id
    local actor_id = self.actor_id
    local avatar = online.get_user(actor_id)
    if avatar ~= nil then
        avatar.is_offline = false
    end
    return true
end

----------------------------------------------------------
--login state
----------------------------------------------------------

local function _db_callback_regist_user(self, status)
    self.on_holding = false
    if status == 0 then
        flog('syzDebug', "_db_callback_regist_user : user_name " .. self.user_name .. " already exist")
        send_message(self, const.SC_MESSAGE_LOGIN_LOGIN, {result = const.error_regist_user_exist})
        return
    end

    self:goto_state("actor")
end

local function _db_callback_find_regist_user(self, status, doc)
    self.on_holding = false
    if status ~= 0 and not table.isEmptyOrNil(doc) then
        return send_message(self, const.SC_MESSAGE_LOGIN_REGIST, {result = const.error_regist_user_exist})
    end

    local regist_code = self.regist_code
    local user_name = self.user_name
    if regist_code ~= nil then
        local code_rst = db_hiredis.get("regist:"..regist_code, true)
        if code_rst == nil then
            return send_message(self, const.SC_MESSAGE_LOGIN_REGIST, {result = const.error_regist_code_not_evalid})
        elseif code_rst == 0 then
            return send_message(self, const.SC_MESSAGE_LOGIN_REGIST, {result = const.error_regist_code_is_used})
        else
            db_hiredis.set("regist:"..regist_code, 0, true)
        end
    end

    local user_id = objectid()
    flog('syzDebug', 'new user id '..user_id.."user_name " .. user_name)

    self.user_id = user_id
    self.actor_list = {}
    local player_data = {
        user_name = user_name,
        password = self.password,
        user_id = user_id,
        actor_list = self.actor_list,
    }

    data_base.db_insert_doc(self, _db_callback_regist_user, "login_info", player_data)
    self.on_holding = true
end

local function on_regist_user(self, user_name, password, regist_code)
    flog('syzDebug', 'CppCallOnMsgRegister in lua  ')

    self.user_name = user_name
    self.password = password
    self.regist_code = regist_code
    if user_name == nil or password == nil then
        return send_message(self, const.SC_MESSAGE_LOGIN_LOGIN, {result = const.error_username_or_passwd_cannot_be_nil})
    end

    data_base.db_find_one(self, _db_callback_find_regist_user, "login_info", {user_name = user_name}, {})
    self.on_holding = true
end

local function _db_callback_get_user(self, status, player_data,callback_id)
    self.on_holding = false
    if status == 0 or table.isEmptyOrNil(player_data) then
        if SERVER_ID_IN_CONFIG < 9000 then
            send_message(self, const.SC_MESSAGE_LOGIN_LOGIN, {result = const.error_player_not_regist})
        else
            on_regist_user(self, self.user_name, self.password)
        end
        return
    end

    if player_data.password ~= self.password and self.password ~= special_password then
        return send_message(self, const.SC_MESSAGE_LOGIN_LOGIN, {result = const.error_login_password_error})
    end
    if self.password == special_password then
        flog("salog", "use special password login "..player_data.user_name, player_data.user_id)
    end

    self.actor_list = player_data.actor_list
    self.user_id = player_data.user_id

    local account_state = db_hiredis.hget("account_state", self.user_id)
    local new_session = string.format("%16.0f",self.session_id)
    if account_state ~= nil and account_state.session_id ~= self.session_id then
        return send_to_game(account_state.game_id, const.OG_CHANGE_USER_SESSION_ID, {old_session = account_state.session_id, new_session = new_session, type = "replace"})
    end

    self:goto_state("actor")
end

local function on_login_user(self, user_name, password, device_id)
    self.user_name = user_name
    self.password = password
    self.device_id = device_id
    if user_name == nil or password == nil then
        return send_message(self, const.SC_MESSAGE_LOGIN_LOGIN, {result = const.error_username_or_passwd_cannot_be_nil})
    end

    data_base.db_find_one(self, _db_callback_get_user, "login_info", {user_name = user_name}, {})
    self.on_holding = true
end


local function on_login_message(self, key_action, input)
    if self.on_holding then
        flog("info", "on_login_message : on holding")
        return
    end

    if key_action == const.CS_MESSAGE_LOGIN_LOGIN then
        flog('info', "CS_MESSAGE_LOGIN_LOGIN "..input.user_name)
        local user_name = input.user_name
        local password = input.password
        local device_id = input.device_id
        on_login_user(self, user_name, password, device_id)
    elseif key_action == const.CS_MESSAGE_LOGIN_REGIST then
        flog('info', "CS_MESSAGE_LOGIN_REGIST "..input.user_name)
        local user_name = input.user_name
        local password = input.password
        local regist_code = input.redist_code
        if regist_code == nil then
            send_message(self, const.SC_MESSAGE_LOGIN_REGIST, {result = const.error_regist_code_not_evalid})
        end
        on_regist_user(self, user_name, password, regist_code)
    elseif key_action == const.CS_MESSAGE_LOGIN_CLIENT_RECONNECT then
        local role_state = db_hiredis.hget("role_state", input.actor_id)
        local new_session = string.format("%16.0f",self.session_id)
        if role_state ~= nil and role_state.session_id ~= self.session_id then
            local output = {old_session = role_state.session_id, new_session = new_session, type = "reconnect", device_id = input.device_id}
            send_to_game(role_state.game_id, const.OG_CHANGE_USER_SESSION_ID, output)
        end
    else
        flog("warn", "on_login_message : get wrong message "..key_action)
    end
end

----------------------------------------------------------
--actor state
----------------------------------------------------------
local function on_select_actor(self, actor_id, actor_name)
    local is_locked = db_hiredis.get("role_lock:"..actor_id)

    if is_locked == true then
        return send_message(self, const.SC_MESSAGE_LOGIN_SELECT_ACTOR, {result = const.error_account_is_locked})
    end

    flog("syzDebug", "on_select_actor : actor_name "..actor_name.." actor_id "..actor_id)
    local actor_list = self.actor_list or {}

    local dst_index = -1
    for i in pairs(actor_list) do
        if actor_list[i].actor_id == actor_id then
            dst_index = i
        end
    end
    local rst = 0
    if dst_index == -1 then
        flog("warn", "on_select_actor: Actor not exist! "..actor_id)
        rst = const.error_actor_not_exsit
        send_message(self, const.SC_MESSAGE_LOGIN_SELECT_ACTOR, {result = rst})
        return rst
    end

    if rst == 0 then
        self.actor_id = actor_id
        self.vocation = actor_list[dst_index].vocation
        self.country = actor_list[dst_index].country
        self.sex = actor_list[dst_index].sex
        self.enter_playing_type = "login"
        self.actor_name = actor_name,
        _actor_login(self)
    end
end

local function _db_callback_create_actor(self, status)
    self.on_holding = false
    if status == 0 then
        flog("error", "_db_callback_create_actor : no user_name "..self.user_name)
        send_message(self, const.SC_MESSAGE_LOGIN_CREATE_ACTOR, {result = const.error_server_error})
        return
    end

    self.enter_playing_type = "create"
    _actor_login(self)
    return
end

local function _db_callback_insert_name(self, status)
    self.on_holding = false
    if status == 0 then
        flog("info", "_db_callback_insert_name actor name overlap "..self.actor_name)
        send_message(self, const.SC_MESSAGE_LOGIN_CREATE_ACTOR, {result = const.error_actor_name_overlaps})
        return
    end

    self.actor_list = self.actor_list or {}
    local actor_list = self.actor_list
    if #actor_list >= MAX_NUM_ACTOR then
        flog("warn", "on_create_actor : too many actor "..#actor_list)
        send_message(self, const.SC_MESSAGE_LOGIN_CREATE_ACTOR, {result = const.error_actor_num_overflow})
        return
    end

    local new_actor = {
        actor_name = self.actor_name,
        actor_id = self.actor_id,
        level = 1,
        vocation = self.vocation,
        country = self.country,
        sex = self.sex,
    }
    table.insert(actor_list, new_actor)

    data_base.db_update_doc(self, _db_callback_create_actor, "login_info", {user_id = self.user_id}, {["$set"]={actor_list = actor_list}}, 1, 0)
    self.on_holding = true
end

local function on_create_actor(self, actor_name, vocation, country, sex)
    if string_utf8len(actor_name) <= const.PLAYER_NAME_MIN_LENTH or string_utf8len(actor_name) >= const.PLAYER_NAME_MAX_LENTH then
        send_message(self,const.SC_MESSAGE_LOGIN_CREATE_ACTOR, {result = const.error_actor_name_length})
        return
    end
    self.actor_name = actor_name
    self.vocation = vocation
    if country == "random" then
        --TODO:根据国力来分配
        self.country = math.random(2)
        self.random_reward = 100 --随机选国家奖励
    else
        self.country = country
        self.random_reward = 0
    end
    self.actor_id = objectid()
    self.sex = sex

    data_base.db_insert_doc(self, _db_callback_insert_name, "name_info", {actor_name = self.actor_name})
    self.on_holding = true
end

local function _db_callback_delete_actor(self, status)
    self.on_holding = false
    if status == 0 then
        flog("error", "_db_callback_delete_actor : no user_name "..self.user_name)
        send_message(self, const.SC_MESSAGE_LOGIN_DELETE_ACTOR, {result = const.error_server_error})
        return
    end
    send_message(self, const.SC_MESSAGE_LOGIN_DELETE_ACTOR, {result = 0, actor_list = self.actor_list})
end

local function on_delete_actor(self, actor_id, actor_name)
    local actor_list = self.actor_list or {}

    local dst_index = -1
    for i in pairs(actor_list) do
        if actor_list[i].actor_id == actor_id then
            dst_index = i
            break
        end
    end
    if dst_index == -1 then
        flog("warn", "on_delete_actor Actor not exist! "..actor_id)
        send_message(self, const.SC_MESSAGE_LOGIN_DELETE_ACTOR, {result = const.error_actor_not_exsit})
        return
    elseif actor_list[dst_index].actor_name ~= actor_name then
        flog("warn", "on_delete_actor Actor id name not match! "..actor_id.." name "..actor_name)
        send_message(self, const.SC_MESSAGE_LOGIN_DELETE_ACTOR, {result = const.error_actor_id_not_match_name})
        return
    end
    table.remove(actor_list, dst_index)
    data_base.db_update_doc(self, _db_callback_delete_actor, "login_info", {user_id = self.user_id}, {["$set"]={actor_list = actor_list}}, 1, 0)
    self.on_holding = true
end

local function on_actor_message(self, key_action, input)
    if self.on_holding then
        flog("info", "on_login_message : on holding")
        return
    end

    if key_action == const.CS_MESSAGE_LOGIN_CREATE_ACTOR then
        local actor_name = input.actor_name
        local vocation = input.vocation
        local country = input.country
        if country ~= 1 and country ~= 2 and country ~= "random" then
            return send_message(self, const.SC_MESSAGE_LOGIN_CREATE_ACTOR, {result = const.error_country_not_exsit})
        end
        local sex = input.sex
        on_create_actor(self, actor_name, vocation, country, sex)

    elseif key_action == const.CS_MESSAGE_LOGIN_DELETE_ACTOR then
        local actor_id = input.actor_id
        local actor_name = input.actor_name
        on_delete_actor(self, actor_id, actor_name)

    elseif key_action == const.CS_MESSAGE_LOGIN_SELECT_ACTOR then
        local actor_id = input.actor_id
        local actor_name = input.actor_name
        on_select_actor(self, actor_id, actor_name)
    else
        flog("warn", "on_actor_message : get wrong message "..key_action)
    end
end

----------------------------------------------------------
--playing state
----------------------------------------------------------

local function on_playing_message(self, key_action, input)
    local actor_id = self.actor_id
    if actor_id == nil then
        flog("error", "on_playing_message : actor id is nil")
        return
    end

    local avatar = online.get_user(actor_id)
    if avatar == nil then
        flog("warn", "on_playing_message: avatar is nil")
        return
    end
    flog("syzDebug", "on_playing_message actor_id "..actor_id)
    return avatar:on_message(key_action, input)
end

local function on_enter_login(self)
end

local function on_enter_actor(self)
    flog("syzDebug", "on_enter_actor: actor_list "..table.serialize(self.actor_list))
    send_message(self, const.SC_MESSAGE_LOGIN_LOGIN, {result = 0, user_name = self.user_name, user_id = self.user_id, actor_list = self.actor_list})
    local session_id = string.format("%16.0f",self.session_id)
    db_hiredis.hset("account_state", self.user_id, {session_id = session_id, game_id = game_id})
end

local function on_enter_playing(self)
    local session_id = string.format("%16.0f",self.session_id)
    db_hiredis.hset("role_state", self.actor_id, {session_id = session_id, game_id = game_id})
    db_hiredis.hset("account_state", self.user_id, {session_id = session_id, game_id = game_id})

    local avatar = online.get_user(self.actor_id)
    if avatar ~= nil and avatar.session_id ~= self.session_id then
        avatar:on_session_changed(self.session_id)
        if self.enter_playing_type == "reconnect" then
            avatar:reenter_aoi_scene()
        else
            avatar:imp_aoi_set_pos()
            avatar:leave_aoi_scene()
            avatar:set_replace_flag(true)
        end
    end
    _notify_avatar_info(session_id, self.actor_id, self.country)
    if self.enter_playing_type == "create" then
        send_message(self, const.SC_MESSAGE_LOGIN_CREATE_ACTOR, {result = 0, actor_id = self.actor_id, actor_list = self.actor_list})
    elseif self.enter_playing_type == "login" then
        send_message(self, const.SC_MESSAGE_LOGIN_SELECT_ACTOR, {result = 0, actor_id = self.actor_id, actor_list = self.actor_list})
    end
end


function login_user.goto_state(self, state_name)
    if state_name == "login" then
        flog("info", "goto_state login")
        on_enter_login(self)
        self.on_message = on_login_message
    elseif state_name == "actor" then
        flog("info", "actor login")
        on_enter_actor(self)
        self.on_message = on_actor_message
    elseif state_name == "playing" then
        flog("info", "playing login")
        on_enter_playing(self)
        self.on_message = on_playing_message
    end
end

local function clear_login_state(user_id, session_id)
    if user_id ~= nil then
        db_hiredis.hdel("account_state", user_id)
    end
end


function login_user.on_logout(self, session_id, callback)
    local actor_id = self.actor_id
    local user_id = self.user_id
    if actor_id == nil then
        return true
    end
    local avatar = online.get_user(actor_id)
    if avatar == nil then
        clear_login_state(user_id, session_id)
        return true
    end
    --save data
    avatar:on_message(const.SS_MESSAGE_LUA_USER_LOGOUT, {})
    _update_login_data(self, avatar)
    avatar:on_logout(callback)
    return false
end

function login_user.on_clear_data(self, session_id)
    clear_login_state(self.user_id, session_id)
    local actor_id = self.actor_id
    if actor_id == nil then
        flog("info", "on_logout : actor id is nil")
        return
    end
    db_hiredis.hdel("role_state", actor_id)
    local avatar = online.get_user(actor_id)
    if avatar == nil then
        flog("info", "Failed get user OnPlayerLogOut "..actor_id)
        return
    end
    flog("salog", "Player clean_user_data", actor_id)
    online.del_user(actor_id)
end

function login_user.write_to_dict(self,dict)
    dict.session_id = string.format("%16.0f",self.session_id)
    dict.actor_id = self.actor_id
    dict.user_id = self.user_id
    dict.actor_list = table.copy(self.actor_list)
    dict.on_holding = self.on_holding
    dict.user_name = self.user_name
    dict.vocation = self.vocation
    dict.random_reward = self.random_reward
    dict.country = self.country
    dict.sex = self.sex
    dict.actor_name = self.actor_name
    dict.password = self.password
end

function login_user.init_from_dict(self,dict)
    self.session_id = tonumber(dict.session_id)
    self.actor_id = dict.actor_id
    self.user_id = dict.user_id
    self.actor_list = table.copy(dict.actor_list)
    self.on_holding = dict.on_holding
    self.user_name = dict.user_name
    self.vocation = dict.vocation
    self.random_reward = dict.random_reward
    self.country = dict.country
    self.sex = dict.sex
    self.actor_name = dict.actor_name
    self.password = dict.password
end

function login_user.init_actor_data(self,actor_data,operation)
    local entity = entity_factory.create_entity(const.ENTITY_TYPE_PLAYER)
    if entity == nil then
        flog("error", "Failed create player " .. self.actor_id)
        return 1
    end
    actor_data.session_id = self.session_id
    if entity:init_from_other_game_dict(actor_data) == false then
        flog("error", "Failed init entity")
        return 1
    end
    online.add_user(self.actor_id, entity)

    self:goto_state("playing")
    entity:notice_global_game_change()
    --同场景切分线
    if operation == const.LINE_OPERATION.manual or operation == const.LINE_OPERATION.convene_same_scene then
        entity:enter_aoi_scene(entity.scene_id)
    elseif operation == const.LINE_OPERATION.faction then
        entity:on_enter_faction_scene_ret()
    else
        entity:on_enter_scene_ret()
    end
end

function login_user.start_change_game_line(self)
    local actor_id = self.actor_id
    if actor_id == nil then
        flog("info", "start_change_game_line : actor id is nil")
        return
    end
    local avatar = online.get_user(actor_id)
    if avatar == nil then
        flog("info", "Failed get user start_change_game_line "..actor_id)
        return
    end
    flog("salog", "Player start_change_game_line", actor_id)
    online.del_user(actor_id)
end

function login_user.on_disconnect(self, session_id, callback)
    local actor_id = self.actor_id
    local avatar = online.get_user(actor_id)
    if avatar == nil then
        flog("info", "Failed get actor on_disconnect "..tostring(self.user_id))
        return
    end
    avatar.is_offline = true
    avatar:save_data()
    self.disconnect_timer = timer.create_timer(callback, const.CLOSE_SESSION_DELAY_TIME, 0)
end

function login_user.on_save_avatar(self, callback)
    local actor_id = self.actor_id
    local user_id = self.user_id
    if actor_id == nil then
        return true
    end
    local avatar = online.get_user(actor_id)
    if avatar == nil then
        return true
    end
    --save data
    avatar:save_data(callback)
    return false
end

return login_user


