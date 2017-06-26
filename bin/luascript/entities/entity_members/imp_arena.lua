--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/2 0002
-- Time: 15:49
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local get_serverid = require("basic/net").get_serverid
local flog = require "basic/log"
local challenge_arena = require "data/challenge_arena"
local scene_func = require "scene/scene_func"
local data_base = require "basic/db_mongo"
local entity_factory = require "entity_factory"
local math = require "math"
local common_fight_base = require "data/common_fight_base"
local daily_refresher = require("helper/daily_refresher")
local MonsterAttribute = common_fight_base.Attribute
local timer = require "basic/timer"
local challenge_arena_table = require "data/challenge_arena"
local skill_moves = require("data/growing_skill").SkillMoves
local skill_unlock = require("data/growing_skill").SkillUnlock
local common_char_chinese = require "data/common_char_chinese"
local common_system_list = require "data/common_system_list"
local table = table
local get_fight_server_info = require("basic/common_function").get_fight_server_info
local send_message_to_fight = require("basic/net").send_message_to_fight
local _get_now_time_second = _get_now_time_second
local center_server_manager = require "center_server_manager"

local ARENA_TYPE = const.ARENA_TYPE
local ARENA_CHALLENGE_TYPE = const.ARENA_CHALLENGE_TYPE
local ARENA_CHALLENGE_OPPONENT_TYPE = const.ARENA_CHALLENGE_OPPONENT_TYPE
local arena_parameter = challenge_arena.Parameter
local RESOURCE_NAME_TO_ID = const.RESOURCE_NAME_TO_ID
local table_text = common_char_chinese.TableText
local SYSTEM_NAME_TO_ID = const.SYSTEM_NAME_TO_ID

local purchase_limit_configs = {}
for _,v in pairs(challenge_arena.PurchaseLimit) do
    if purchase_limit_configs[v.Type] == nil then
        purchase_limit_configs[v.Type] = {}
    end
    purchase_limit_configs[v.Type][v.Lowerlimt] = v
end

local first_arena_grade_id = 10000
local arena_grade_configs = {}
for _,v in pairs(challenge_arena.QualifyingGrade) do
    arena_grade_configs[v.ID] = v
    if v.NextGrade == 0 then
        first_arena_grade_id = v.ID
    end
end

local grade_keeper_configs = {}
for _,v in pairs(challenge_arena.GradeKeeper) do
    grade_keeper_configs[v.GradeID] = v
end

local arena_monster_configs = {}
for _,v in pairs(challenge_arena.MonsterSetting) do
    arena_monster_configs[v.ID] = v
end

local common_system_list_configs = {}
for _,v in pairs(common_system_list.system) do
    common_system_list_configs[v.ID] = v
end

local arena_scene = challenge_arena_table.ArenaScene

local function get_buy_count_consume(type,count)
    if purchase_limit_configs[type] ~= nil then
        local limit = 0
        for l,_ in pairs(purchase_limit_configs[type]) do
            if l > limit and count >= l then
                limit = l
            end
        end
        if limit > 0 then
            return purchase_limit_configs[type][limit].Value
        end
    end
    return 0
end

local params = {
    --下次挑战时间
    next_fight_time = {db=true,sync=true,default=0 },
    --当前战斗次数
    qualifying_fight_count = {db=true,sync=true,default=0 },
    --购买次数
    qualifying_buy_count = {db=true,sync=true,default = 0},
    --当前战斗次数
    dogfight_fight_count = {db=true,sync=true,default=0 },
    --购买次数
    dogfight_buy_count = {db=true,sync=true,default = 0},
    --排名通告
    arena_rank_notice = {db=true,sync=false,default = false },

}
local imp_arena = {}
imp_arena.__index = imp_arena

setmetatable(imp_arena, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_arena.__params = params

function imp_arena.__ctor(self)
    --排位赛积分
    self.qualifying_score = 0
    --混战赛积分
    self.dogfight_score = 0
    --总积分
    self.total_score = 0
    self.qualifying_rank = 0
    self.dogfight_rank = 0
    self.grade_id = 0
    self.matching_time = 0
    self.arena_refresher = nil
    self.defend_pet = {}
    self.arena_defend_skill = {}

    --对手数据
    self.opponent_type = 1
    self.arena_opponent_id = 1
    self.in_arena = false
    self.in_arena_scene = false
    --混战赛匹配中
    self.dogfight_matching = false
    self.dogfight_room_id = 0
    --晋级通告
    self.arena_upgrade_notice = {}
    --禁赛时间
    self.arena_dogfight_ban_time = 0
    --等待创建竞技场场景
    self.waiting_create_qualifying_scene = false
end

local function refresh_arena_data(self)
    self.qualifying_fight_count = 0
    self.qualifying_buy_count = 0
    self.dogfight_fight_count = 0
    self.dogfight_buy_count = 0
end

function imp_arena.imp_arena_init_from_dict(self,dict)
    local arena_info = table.get(dict,"arena_info",{})
    for i, v in pairs(params) do
        if arena_info[i] ~= nil then
            self[i] = arena_info[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    if arena_info.arena_last_refresh_time == nil then
        self.arena_last_refresh_time = _get_now_time_second()
    else
        self.arena_last_refresh_time = arena_info.arena_last_refresh_time
    end

    if arena_info.defend_pet == nil then
        self.defend_pet = {}
    else
        self.defend_pet = arena_info.defend_pet
    end

    if arena_info.arena_defend_skill == nil then
        self.arena_defend_skill = {}
    else
        self.arena_defend_skill = arena_info.arena_defend_skill
    end

    if arena_info.arena_dogfight_ban_time ~= nil then
        self.arena_dogfight_ban_time = arena_info.arena_dogfight_ban_time
    end

    if arena_info.arena_upgrade_notice ~= nil then
        self.arena_upgrade_notice = table.copy(arena_info.arena_upgrade_notice)
    end

    self.arena_refresher = daily_refresher(refresh_arena_data, self.arena_last_refresh_time, arena_parameter[38].Value[1], arena_parameter[38].Value[2])
    self.arena_refresher:check_refresh(self)
end

function imp_arena.imp_arena_init_from_other_game_dict(self,dict)
    self:imp_arena_init_from_dict(dict)
    self.qualifying_score = dict.qualifying_score
    self.dogfight_score = dict.dogfight_score
    self.total_score = dict.total_score
    self.qualifying_rank = dict.qualifying_rank
    self.dogfight_rank = dict.dogfight_rank
    self.grade_id = dict.grade_id
end

function imp_arena.imp_arena_write_to_dict(self,dict)
    if self.in_fight_server and self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
        self.next_fight_time = _get_now_time_second() + math.floor(arena_parameter[3].Value[1]/1000)
    end

    self.arena_refresher:check_refresh(self)
    dict.arena_info = {}
    for i, v in pairs(params) do
        if v.db then
            dict.arena_info[i] = self[i]
        end
    end

    dict.arena_info.defend_pet = table.copy(self.defend_pet)
    dict.arena_info.arena_defend_skill = table.copy(self.arena_defend_skill)
    dict.arena_info.arena_last_refresh_time = self.arena_refresher:get_last_refresh_time()
    dict.arena_info.arena_upgrade_notice = table.copy(self.arena_upgrade_notice)
    dict.arena_info.arena_dogfight_ban_time = self.arena_dogfight_ban_time
end

function imp_arena.imp_arena_write_to_other_game_dict(self,dict)
    self:imp_arena_write_to_dict(dict)
    dict.qualifying_score = self.qualifying_score
    dict.dogfight_score = self.dogfight_score
    dict.total_score = self.total_score
    dict.qualifying_rank = self.qualifying_rank
    dict.dogfight_rank = self.dogfight_rank
    dict.grade_id = self.grade_id
end

function imp_arena.imp_arena_write_to_sync_dict(self,dict)
    self.arena_refresher:check_refresh(self)
    dict.arena_info = {}
    for i, v in pairs(params) do
        if v.sync then
            dict.arena_info[i] = self[i]
        end
    end
    dict.arena_info.qualifying_rank = self.qualifying_rank
    dict.arena_info.dogfight_rank = self.dogfight_rank
    dict.arena_info.grade_id = self.grade_id
    dict.arena_info.matching_time = self.matching_time
    dict.arena_info.next_fight_time = dict.arena_info.next_fight_time - _get_now_time_second()
    if dict.arena_info.next_fight_time < 0 then
        dict.arena_info.next_fight_time = 0
    end
    dict.arena_info.defend_pet = table.copy(self.defend_pet)
    dict.arena_info.arena_defend_skill = table.copy(self.arena_defend_skill)
    dict.arena_info.arena_dogfight_ban_time = self.arena_dogfight_ban_time - _get_now_time_second()
    if dict.arena_info.arena_dogfight_ban_time < 0 then
        dict.arena_info.arena_dogfight_ban_time = 0
    end
end

function imp_arena.get_qualifying_score(self)
    return self.qualifying_score
end

function imp_arena.get_dogfight_score(self)
    return self.dogfight_score
end

function imp_arena.get_total_score(self)
    return self.total_score
end

function imp_arena.get_last_fight_time(self)
    return self.last_fight_time
end

function imp_arena.get_fight_count(self)
    return self.fight_count
end

function imp_arena.get_buy_count(self)
    return self.buy_count
end

function imp_arena.update_player_info_to_arena(self,attribute,value)
    self:send_message_to_arena_server({func_name="update_player_info",attribute = attribute,attribute_value = value})
end

local function on_arena_server_rpc(self,input,sync_data)
    local func_name = input.func_name
    if func_name == nil or self[func_name] == nil then
        func_name = func_name or "nil"
        flog("error", "on_arena_server_rpc: no func_name  "..func_name)
        return
    end
    self[func_name](self, input, sync_data)
end

local function on_get_arena_info(self,input,sync_data)
    local result = 0
    if self.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_qualifying].level then
        result = const.error_level_not_enough
        self:send_message(const.SC_MESSAGE_LUA_ARENA_INFO,{result=result})
        return
    end
    self:send_message_to_arena_server({func_name="on_get_actor_arena_info",})
end

function imp_arena.on_get_actor_arena_info_reply(self,input,sync_data)
    if input.result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_ARENA_INFO,{result=input.result})
        return
    end
    self.qualifying_score = input.qualifying_score
    self.total_score = input.total_score
    self.dogfight_score = input.dogfight_score
    self.qualifying_rank = input.qualifying_rank
    self.dogfight_rank = input.dogfight_rank
    self.grade_id = input.grade_id
    local data = {result=0}
    self:imp_arena_write_to_sync_dict(data)
    self:send_message(const.SC_MESSAGE_LUA_ARENA_INFO,data)
end

local function on_get_arena_rank(self,input,sync_data)
    local result = 0
    if input.type == nil or input.rank_start == nil or input.rank_start <= 0 then
        flog("tmlDebug","on_get_arena_rank input.type is nil or input.rank_start is nil")
        return
    end

    if input.type == ARENA_TYPE.qualifying then
        if self.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_qualifying].level then
            result = const.error_level_not_enough
            self:send_message(const.SC_MESSAGE_LUA_ARENA_GET_RANK,{result=result})
            return
        end
        if input.grade_id == nil then
            flog("tmlDebug","on_get_arena_rank input.grade_id is nil")
            return
        end
    else
        if self.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_dogfight].level then
            result = const.error_level_not_enough
            self:send_message(const.SC_MESSAGE_LUA_ARENA_GET_RANK,{result=result})
            return
        end
    end

    self:send_message_to_arena_server({func_name="get_arena_rank",grade_id=input.grade_id,rank_start=input.rank_start,type = input.type})
end

function imp_arena.reply_get_arena_rank(self,input,sync_data)
    self:send_message(const.SC_MESSAGE_LUA_ARENA_GET_RANK,{result=input.result,rank_data=input.rank_data,next_refresh_rank_time=input.next_refresh_rank_time})
end

local function on_arena_challenge(self,input,sync_data)
    local result = 0
    if self.waiting_create_qualifying_scene then
        flog("info","on_arena_challenge waiting create qualifying scene!!!")
        return
    end

    if input.challenge_opponent_type == nil then
        flog("tmlDebug","arena challenge input.challenge_opponent_type == nil")
        return
    end

    if input.challenge_type == nil then
        flog("tmlDebug","arena challenge input.challenge_type == nil")
        return
    end

    result = self:is_operation_allowed("arena_challenge")
    if result ~= 0 then
         self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=result})
        return
    end

    if self.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_qualifying].level then
        result = const.error_level_not_enough
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=result})
        return
    end

    if input.challenge_type == ARENA_CHALLENGE_TYPE.upgrade and self.qualifying_rank > 10 then
        result = const.error_arena_challenge_upgrade_rank
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=result})
        return
    end

    if input.challenge_opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player and (input.opponent_id == nil or input.opponent_rank == nil) then
        flog("tmlDebug","arena challenge input.opponent_id == nil or input.rank == nil")
        return
    end

    if self.dogfight_matching == true or self.dogfight_room_id > 0 then
        result = const.error_arena_dogfight_matching
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=result})
        return
    end

    if self.qualifying_fight_count >= arena_parameter[2].Value[1] + self.qualifying_buy_count then
        result = const.error_arena_challenge_max_count
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=result})
        return
    end

    local current_time = _get_now_time_second()
    if current_time < self.next_fight_time then
        result = const.error_arena_challenge_cooling
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=result})
        return
    end

    self.challenge_type = input.challenge_type
    self.opponent_type = input.challenge_opponent_type
    self.arena_opponent_id = input.opponent_id
    self.waiting_create_qualifying_scene = true

    self:send_message_to_arena_server({func_name="arena_challenge",challenge_type=input.challenge_type,challenge_opponent_type=input.challenge_opponent_type,opponent_id = input.opponent_id,opponent_rank= input.opponent_rank})
end

function imp_arena.on_create_qualifying_arena_complete(self,input,sync_data)
    self.waiting_create_qualifying_scene = false
    if input.success == false then
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=const.error_fight_server_create,scene_id=const.ARENA_QUALIFYING_SCENE_ID})
        self:send_message_to_arena_server({func_name="cancel_qualifying_challenge",challenge_type=self.challenge_type,opponent_type=self.opponent_type,opponent_id=self.arena_opponent_id})
        return
    end
    local data = {}
    data.fight_type = const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA
    self:send_fight_info_to_fight_server(data)
end

function imp_arena.on_enter_qualifying_arena_success(self,input,sync_data)
    self.arena_refresher:check_refresh(self)
    self.qualifying_fight_count = self.qualifying_fight_count + 1
    self.in_arena = true
    self.in_fight_server = true
    self:fight_avatar_notice_leave_aoi_scene()
end

local function create_qualifying_arena_fight(self,playerdata)
    if self.in_fight_server == true then
        flog("info","create_qualifying_arena_fight fail,player in fight server!!!")
        self.waiting_create_qualifying_scene = false
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=const.error_fight_server_create,scene_id=const.ARENA_QUALIFYING_SCENE_ID})
        self:send_message_to_arena_server({func_name="cancel_qualifying_challenge",challenge_type=self.challenge_type,opponent_type=self.opponent_type,opponent_id=self.arena_opponent_id})
        return
    end
    local fight_server_id,ip,port,token,fight_id = get_fight_server_info(const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA)
    if fight_server_id == nil then
        flog("info","create_qualifying_arena_fight fail,can not find fight server!!!")
        self.waiting_create_qualifying_scene = false
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=const.error_fight_server_create,scene_id=const.ARENA_QUALIFYING_SCENE_ID})
        self:send_message_to_arena_server({func_name="cancel_qualifying_challenge",challenge_type=self.challenge_type,opponent_type=self.opponent_type,opponent_id=self.arena_opponent_id})
        return
    end
    self:set_fight_server_info(fight_server_id,ip,port,token,fight_id,const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA)
    if playerdata ~= nil then
        playerdata.posX = 0
        playerdata.posY = 0
        playerdata.posZ = 0
        playerdata.kill_boss_score = nil
        playerdata.items = nil
    end
    flog("tmlDebug","playerdata="..table.serialize(playerdata))
    send_message_to_fight(fight_server_id, const.GD_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "on_create_qualifying_arena", actor_id = self.actor_id,fight_id=fight_id,token=token,fight_type=const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA,playerdata=playerdata,opponent_type = self.opponent_type,arena_opponent_id=self.arena_opponent_id,grade_id=self.grade_id})
end

local function _db_callback_get_opponent(self, status, playerdata,callback_id)
    flog("tmlDebug","arena _db_callback_get_opponent")
    if status == 0 or table.isEmptyOrNil(playerdata) then
        self.waiting_create_qualifying_scene = false
        flog("info","can not find arena opponent data!opponent "..self.arena_opponent_id)
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=const.error_no_player})
        self:send_message_to_arena_server({func_name="cancel_qualifying_challenge",challenge_type=self.challenge_type,opponent_type=self.opponent_type,opponent_id=self.arena_opponent_id})
        return
    end
    create_qualifying_arena_fight(self,playerdata)
    return 0
end

function imp_arena.reply_arena_challenge(self,input,sync_data)
    local result = input.result
    if result ~= 0 then
        self.waiting_create_qualifying_scene = false
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=input.result})
        if result == const.error_arena_challenge_opponent_rank_update then
            self:send_message_to_arena_server({func_name="refresh_arena_qualifying"})
        end
        return
    end
    self.waiting_create_qualifying_scene = true
    if self.opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player then
        flog("tmlDebug", "reply_arena_challenge arena fight,find opponent: "..self.arena_opponent_id)
        data_base.db_find_one(self, _db_callback_get_opponent, "actor_info", {actor_id = self.arena_opponent_id}, {})
    else
        create_qualifying_arena_fight(self)
    end
    return
end

local function on_arena_matching(self,input,sync_data)
    flog("tmlDebug","imp_arena.on_arena_matching")
    local result = 0
    result = self:is_operation_allowed("arena_match")
    if result ~= 0 then
         self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=result})
        return
    end

    if self.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_dogfight].level then
        result = const.error_level_not_enough
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,{result=result})
        return
    end

    local current_time = _get_now_time_second()
    local current_date = os.date("*t", current_time)
    local time1 = {year=current_date.year,month=current_date.month,day=current_date.day,hour=arena_parameter[1].Value[1],min=arena_parameter[1].Value[2],sec=0 }
    local time2 = {year=current_date.year,month=current_date.month,day=current_date.day,hour=arena_parameter[23].Value[1],min=arena_parameter[23].Value[2],sec=0 }
    local time3 = {year=current_date.year,month=current_date.month,day=current_date.day,hour=arena_parameter[24].Value[1],min=arena_parameter[24].Value[2],sec=0 }
    local time4 = {year=current_date.year,month=current_date.month,day=current_date.day,hour=arena_parameter[33].Value[1],min=arena_parameter[33].Value[2],sec=0 }
    local weekday = false
    for i = 1,#arena_parameter[22].Value,1 do
        if current_date.wday == arena_parameter[22].Value[i] then
            weekday = true
            break
        end
    end
    if weekday == false then
        result = const.error_arena_dogfight_time
        self:send_message(const.SC_MESSAGE_LUA_ARENA_MATCHING,{result=result})
        return
    end
    if current_time < os.time(time1) or (current_time > os.time(time2 )and current_time < os.time(time3)) or current_time > os.time(time4) then
        result = const.error_arena_dogfight_time
        self:send_message(const.SC_MESSAGE_LUA_ARENA_MATCHING,{result=result})
        return
    end

    if self.dogfight_matching == true or self.dogfight_room_id > 0 then
        result = const.error_arena_dogfight_matching
        self:send_message(const.SC_MESSAGE_LUA_ARENA_MATCHING,{result=result})
        return
    end

    if self.arena_dogfight_ban_time > _get_now_time_second() then
        result = const.error_arena_dogfight_ban_time
        self:send_message(const.SC_MESSAGE_LUA_ARENA_MATCHING,{result=result})
        return
    end

    self:send_message_to_cross_server_arena_server({func_name="on_player_start_matching",actor_name=self.actor_name,vocation=self.vocation,grade_id=self.grade_id})
end

function imp_arena.on_player_start_matching_reply(self,input,sync_data)
    flog("tmlDebug","imp_arena.reply_arena_dogfight_matching")
    if input.result == 0 then
        self.dogfight_matching = true
    end
    self:send_message(const.SC_MESSAGE_LUA_ARENA_MATCHING,{result=input.result,predict_dogfight_matching_time=input.predict_dogfight_matching_time})
end

local function on_cancel_dogfight_matching(self,input,sync_data)
    flog("tmlDebug","imp_arena.on_cancel_dogfight_matching")
    local result = 0
    if self.dogfight_matching == false and self.dogfight_room_id == 0 then
        result = const.error_arena_dogfight_not_matching
        self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_CANCEL_MATCHING,{result=result})
        return
    end
    on_get_arena_info(self)
    self:send_message_to_cross_server_arena_server({func_name="cancel_dogfight_matching",quit = false})
end

function imp_arena.reply_cancel_dogfight_matching(self,input,sync_data)
    flog("tmlDebug","imp_arena.reply_cancel_dogfight_matching")
    local result = 0
    self.dogfight_matching = false
    self.dogfight_room_id = 0
    self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_CANCEL_MATCHING,{result=result})
end

local function on_arena_buy_count(self,input,sync_data)
    local result = 0
    if input.type == nil then
        flog("tmlDebug","input.type == nil")
        return
    end
    self.arena_refresher:check_refresh(self)
    local consume = 0;
    if input.type == ARENA_TYPE.qualifying then
        if self.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_qualifying].level then
            result = const.error_level_not_enough
            self:send_message(const.SC_MESSAGE_LUA_ARENA_BUY_COUNT,{result=result})
            return
        end
        consume = get_buy_count_consume(input.type,self.qualifying_buy_count + 1)
        if consume == 0 then
            flog("tmlDebug","can not find consume config,type:"..input.type..",count:"..(self.qualifying_buy_count + 1))
            return
        end

    else
        if self.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_dogfight].level then
            result = const.error_level_not_enough
            self:send_message(const.SC_MESSAGE_LUA_ARENA_BUY_COUNT,{result=result})
            return
        end
        consume = get_buy_count_consume(input.type,self.dogfight_buy_count + 1)
        if consume == 0 then
            flog("tmlDebug","can not find consume config,type:"..input.type..",count:"..(self.dogfight_buy_count + 1))
            return
        end
    end

    if not self:is_enough_by_id(RESOURCE_NAME_TO_ID.ingot,consume) then
        local result = const.error_item_not_enough
        self:send_message(const.SC_MESSAGE_LUA_ARENA_BUY_COUNT,{result=result,item_id=RESOURCE_NAME_TO_ID.ingot})
        return
    end

    if input.type == ARENA_TYPE.qualifying then
        self.qualifying_buy_count = self.qualifying_buy_count + 1
    else
        self.dogfight_buy_count = self.dogfight_buy_count + 1
    end

    self:remove_item_by_id(RESOURCE_NAME_TO_ID.ingot,consume)

    local result_data = {result=result}
    self:imp_arena_write_to_sync_dict(result_data)
    self:send_message(const.SC_MESSAGE_LUA_ARENA_BUY_COUNT,result_data)
end

local function on_arena_cooling(self,input,sync_data)
    local result = 0
    if self.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_qualifying].level then
        result = const.error_level_not_enough
        self:send_message(const.SC_MESSAGE_LUA_ARENA_COOLING,{result=result})
        return
    end
    local current_time = _get_now_time_second()
    if self.next_fight_time <= current_time then
        result = const.error_arena_qualifying_cooling
        self:send_message(const.SC_MESSAGE_LUA_ARENA_COOLING,{result=result})
    end

    local consume = math.ceil((self.next_fight_time - current_time)/60)*arena_parameter[4].Value[1]
    if not self:is_enough_by_id(RESOURCE_NAME_TO_ID.ingot,consume) then
        local result = const.error_item_not_enough
        self:send_message(const.SC_MESSAGE_LUA_ARENA_COOLING,{result=result,item_id=RESOURCE_NAME_TO_ID.ingot})
        return
    end
    self.next_fight_time = _get_now_time_second()
    self:remove_item_by_id(RESOURCE_NAME_TO_ID.ingot,consume)

    local result_data = {result=result}
    self:imp_arena_write_to_sync_dict(result_data)
    self:send_message(const.SC_MESSAGE_LUA_ARENA_COOLING,result_data)
    self:imp_assets_write_to_sync_dict(sync_data)
end

local function on_arena_refresh(self,input,sync_data)
    self:send_message_to_arena_server({func_name="refresh_arena_qualifying"})
end

function imp_arena.reply_arena_refresh(self,input,sync_data)
    self:send_message(const.SC_MESSAGE_LUA_ARENA_REFRESH,{result=input.result,opponent_data=input.opponent_data})
end

local function on_arena_setting_pet(self,input,sync_data)
    local result = 0
    if input.defend_pet == nil or type(input.defend_pet) ~= "table" or input.arena_defend_skill == nil or type(input.arena_defend_skill) ~= "table" then
        flog("tmlDebug","on_arena_set_defend_pet defend_pet is not a table!")
        return
    end
    self.defend_pet = {}
    for _,entity_id in pairs(input.defend_pet) do
        if self:is_have_pet(entity_id) == true then
            table.insert(self.defend_pet,entity_id)
        end
    end
    self.arena_defend_skill = {}
    for place,skill_id in pairs(input.arena_defend_skill) do
        local moves_id = self.vocation * 1000 + place   --根据职业和place计算招式组合的id
        if skill_moves[moves_id] ~= nil and skill_unlock[skill_id] ~= nil then
            if self.level >= skill_unlock[skill_id].PlayerLv then
                local is_match = false
                for _, v in pairs(skill_moves[moves_id].SkillID) do
                    if v == skill_id then
                        is_match = true
                        break
                    end
                end
                if is_match then
                    self.arena_defend_skill[place]=skill_id
                else
                    flog("warn", "on_arena_setting_pet : skill id not match, place: "..place.." id: "..moves_id)
                end
            end
        else
            flog("warn", "on_arena_setting_pet : error_impossible_param is nil,  id: "..moves_id)
        end
    end
    local result_data = {result=result }
    self:imp_arena_write_to_sync_dict(result_data)
    self:send_message(const.SC_MESSAGE_LUA_ARENA_PET_SETTING,result_data)
    self:save_data()
end

function imp_arena.check_arena_defend_pet(self,uid)
    for i=#self.defend_pet,1,-1 do
        if uid == self.defend_pet[i] then
            table.remove(self.defend_pet,i)
            self:save_data()
        end
    end
end

local function on_player_quit_dogfight_arena(self)
    if arena_parameter[43].Value[1] ~= nil and arena_parameter[43].Value[2] ~= nil then
        local cost1_count = self:get_item_count_by_id(arena_parameter[43].Value[1])
        if cost1_count >= arena_parameter[43].Value[2] then
            self:remove_item_by_id(arena_parameter[43].Value[1],arena_parameter[43].Value[2])
        else
            self:remove_item_by_id(arena_parameter[43].Value[1],cost1_count)
        end
    end
    if arena_parameter[43].Value[3] ~= nil and arena_parameter[43].Value[4] then
        if arena_parameter[43].Value[3] == const.RESOURCE_NAME_TO_ID.arena_score then
            self:send_message_to_arena_server({func_name="arena_add_score",addon = -1*arena_parameter[43].Value[4],actor_id=self.actor_id})
        else
            local cost2_count = self:get_item_count_by_id(arena_parameter[43].Value[3])
            if cost2_count >= arena_parameter[43].Value[4] then
                self:remove_item_by_id(arena_parameter[43].Value[3],arena_parameter[43].Value[4])
            else
                self:remove_item_by_id(arena_parameter[43].Value[3],cost2_count)
            end
        end
    end
    if arena_parameter[44].Value[1] ~= nil then
        self.arena_dogfight_ban_time = _get_now_time_second() + arena_parameter[44].Value[1]
    end
end

local function on_arena_dogfight_quit_fight(self,input,sync_data)
    if self.fight_type ~= const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
        flog("tmlDebug","on_arena_dogfight_quit_fight actor is not in dogfight scene!")
        return
    end

    if self.in_arena then
        on_player_quit_dogfight_arena(self)
    end

    self.dogfight_matching = false
    self.dogfight_room_id = 0
    on_get_arena_info(self,{},nil)
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_leave_dogfight_arena"})
    self:send_message_to_cross_server_arena_server({func_name="cancel_dogfight_matching",quit = true})
end

function imp_arena.fight_server_disconnect_dogfight_arena(self)
    if self.in_arena then
        on_player_quit_dogfight_arena(self)
    end
    self.dogfight_room_id = 0
    self.dogfight_matching = false
    self.in_arena = false
    self:send_message_to_cross_server_arena_server({func_name="cancel_dogfight_matching",quit = true})
end

function imp_arena.on_fight_avatar_leave_dogfight_arena(self,input,sync_data)
    flog("tmlDebug","imp_arena.on_fight_avatar_leave_dogfight_arena")
end

function imp_arena.update_rank_info(self,input,sync_data)
    flog("tmlDebug","update_rank_info")
    if input.qualifying_score ~= nil then
        self.qualifying_score = input.qualifying_score
    end
    if input.total_score ~= nil then
        self.total_score = input.total_score
    end
    if input.dogfight_score ~= nil then
        self.dogfight_score = input.dogfight_score
    end
    if input.qualifying_rank ~= nil then
        self.qualifying_rank = input.qualifying_rank
    end
    if input.dogfight_rank ~= nil then
        self.dogfight_rank = input.dogfight_rank
    end
    if input.grade_id ~= nil then
        self.grade_id = input.grade_id
    end
end

--客户端点击结算面板
local function on_arena_qualifying_fight_over(self,input,sync_data)
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_leave_qualifying_arena"})
end

--战斗服反馈
function imp_arena.on_fight_avatar_leave_qualifying_arena(self,input,sync_data)
    flog("tmlDebug","imp_arena.on_fight_avatar_leave_qualifying_arena")
end

--竞技场服务器反馈
function imp_arena.reply_arena_qualifying_fight_over(self,input,sync_data)
    local result = input.result
    if input.rank ~= nil and input.rank > 0 then
        self.qualifying_rank = input.rank
    end
    --晋级成功，发放奖励
    if input.upgrade ~= nil and input.upgrade == true then
        if input.grade_id ~= nil then
            --公告
            if self.arena_upgrade_notice[input.grade_id] == nil or self.arena_upgrade_notice[input.grade_id] == false then
                local arena_grade_config = arena_grade_configs[input.grade_id]
                if arena_grade_config ~= nil then
                    if arena_grade_config.SystemMesID > 0 then
                        local grade_name = ""
                        if arena_grade_config.MainGrade > 0 and table_text[arena_grade_config.MainGrade] ~= nil then
                            grade_name = table_text[arena_grade_config.MainGrade].NR
                        else
                            grade_name = arena_grade_config.MainGrade1
                        end
                        grade_name = grade_name.."-"
                        if arena_grade_config.SubGrade > 0 and table_text[arena_grade_config.SubGrade] ~= nil then
                            grade_name = grade_name..table_text[arena_grade_config.SubGrade].NR
                        else
                            grade_name = grade_name..arena_grade_config.SubGrade1
                        end
                        self:arena_upgrade_grade_system_notice(arena_grade_config.SystemMesID,grade_name)
                        self.arena_upgrade_notice[input.grade_id] = true
                    end
                end
            end
        end
    end

    if input.server_rank ~= nil then
        --本服排名
        if input.server_rank > 0 then
            if self.arena_rank_notice == false then
                if arena_parameter[40].Value[1] >= input.server_rank then
                    self:arena_rank_ten_system_notice(arena_parameter[40].Value[2])
                    self.arena_rank_notice = true
                end
            end
            if arena_parameter[39].Value[1] >= input.server_rank then
                self:arena_rank_ten_system_notice(arena_parameter[39].Value[2],input.server_rank)
            end
        end
    end

    if input.grade_id ~= nil and input.grade_id > 0 then
        self.grade_id = input.grade_id
    end

    local rewards = {}
    if input.success ~= nil then
        if input.success == true then
            table.insert(rewards,{id=arena_parameter[12].Value[1],count=arena_parameter[12].Value[2]})
            self:add_item_by_id(arena_parameter[12].Value[1],arena_parameter[12].Value[2])
            table.insert(rewards,{id=arena_parameter[13].Value[1],count=arena_parameter[13].Value[2]})
            self:add_item_by_id(arena_parameter[13].Value[1],arena_parameter[13].Value[2])
            table.insert(rewards,{id=arena_parameter[14].Value[1],count=arena_parameter[14].Value[2]})
            self:add_item_by_id(arena_parameter[14].Value[1],arena_parameter[14].Value[2])
        else
            table.insert(rewards,{id=arena_parameter[15].Value[1],count=arena_parameter[15].Value[2]})
            self:add_item_by_id(arena_parameter[15].Value[1],arena_parameter[15].Value[2])
            table.insert(rewards,{id=arena_parameter[16].Value[1],count=arena_parameter[16].Value[2]})
            self:add_item_by_id(arena_parameter[16].Value[1],arena_parameter[16].Value[2])
            table.insert(rewards,{id=arena_parameter[17].Value[1],count=arena_parameter[17].Value[2]})
            self:add_item_by_id(arena_parameter[17].Value[1],arena_parameter[17].Value[2])
        end
    end

    local current_time = _get_now_time_second()
    self.next_fight_time = current_time + math.floor(arena_parameter[3].Value[1]/1000)
    if not self.is_offline then
        self:send_message(const.SC_MESSAGE_LUA_ARENA_RESULT,{result=result,success = input.success,rewards=rewards,upgrade=input.upgrade,rank_up=input.rank_up})
    else
        self:notice_fight_server_avatar_logout()
    end
end

--通知竞技场服务器战斗完成
function imp_arena.arena_qualifying_fight_over(self,success)
    flog("salog", string.format("qualifying arena fight over, is win:%s", tostring(success)), self.actor_id)
    self.in_arena = false
    self:finish_activity("arena_challenge")
    self:send_message_to_arena_server({func_name="arena_qualifying_fight_over",opponent_id=self.arena_opponent_id,opponent_type=self.opponent_type,success=success})
end

local function notice_fight_server_quit_qualifying_arena(self)
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_notice_fight_server_quit_qualifying_arena"})
end

--客户端主动请求放弃
local function on_arena_qualifying_fight_quit(self,input,sync_data)
    if self.in_fight_server == false or self.fight_type ~= const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
        flog("tmlDebug","on_arena_qualifying_fight_quit actor is not in qualifying scene!")
        return
    end

    notice_fight_server_quit_qualifying_arena(self)
    self:arena_qualifying_fight_over(false)
end

--玩家退出
local function on_logout(self,input,sync_data)
    flog("tmlDebug","imp_arena|on_logout")
    if self.in_fight_server then
        if self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
            self:arena_qualifying_fight_over(false)
        elseif self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
            on_player_quit_dogfight_arena(self)
        end
    end
    --通知竞技场服务器
    self:send_message_to_arena_server({func_name="on_arena_player_logout",actor_id=self.actor_id})
    if self.dogfight_matching then
        self:send_message_to_cross_server_arena_server({func_name="on_arena_player_logout",actor_id=self.actor_id})
    end
end

function imp_arena.on_qualifying_arena_fight_result(self,input,sync_data)
    flog("tmlDebug","on_arena_fight_result")
    self:arena_qualifying_fight_over(input.success)
end

local function on_arena_dogfight_fight_over(self,input,sync_data)
    if self.fight_type ~= const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
        flog("tmlDebug","on_arena_dogfight_quit_fight actor is not in dogfight scene!")
        return
    end
    self.dogfight_matching = false
    self.dogfight_room_id = 0
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_leave_dogfight_arena"})
end

function imp_arena.set_in_arena_scene(self,value)
    self.in_arena_scene = value
end

function imp_arena.arena_dogfight_matching_successs(self,input,sync_data)
    flog("tmlDebug","imp_arena.arena_dogfight_matching_successs")
    self.dogfight_room_id = input.room_id
end

function imp_arena.create_dogfight_scene_fail(self,input,sync_data)
    flog("tmlDebug","imp_arena.create_dogfight_scene_fail")
    local result = 0
    self.dogfight_room_id = 0
    self.dogfight_matching = false
    result = const.error_arena_dogfight_create_scene_fail
    self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_CREATE_SCENE,{result=result})
end

function imp_arena.create_dogfight_scene_success(self,input,sync_data)
    flog("tmlDebug","imp_arena.create_dogfight_scene_success")
    self:set_fight_server_info(input.fight_server_id,input.ip,input.port,input.token,input.fight_id,const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA)
    local data = {}
    data.fight_type = const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA
    data.arena_total_score = self.total_score
    data.arena_address = center_server_manager.on_get_service_address(const.SERVICE_TYPE.cross_server_arena_service)
    self:send_fight_info_to_fight_server(data)
end

function imp_arena.on_enter_dogfight_arena_success(self,input,sync_data)
    flog("tmlDebug","imp_arena.on_enter_dogfight_arena_success")
    self.dogfight_fight_count = self.dogfight_fight_count + 1
    self.dogfight_room_id = input.room_id
    self:finish_activity("arena_dogfight")
    self.in_arena = true
    self.in_fight_server = true
    self:fight_avatar_notice_leave_aoi_scene()
end

function imp_arena.arena_dogfight_fightover(self,input,sync_data)
    flog("tmlDebug","imp_arena.arena_dogfight_fightover")
    self.dogfight_room_id = 0
    self.dogfight_matching = false
    self.in_arena = false
    if self.is_offline then
        self:notice_fight_server_avatar_logout()
    else
        self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_RESULT,input.score_data)
    end
end

function imp_arena.get_defend_pet(self)
    return self.defend_pet
end

function imp_arena.update_arena_dogfight_rank(self,input,sync_data)
    self.dogfight_rank = input.dogfight_rank
end

function imp_arena.arena_player_level_up(self)
    self:update_player_info_to_arena("level",self.level)
end

--混战赛匹配中
function imp_arena.is_dogfight_matching(self)
    return self.dogfight_matching
end

function imp_arena.arena_request_agree(self,input,sync_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="ArenaRequestAgree",agree_time=input.agree_time})
end

function imp_arena.on_arena_agree(self,input,sync_data)
    if self:is_player_die() then
        self:on_cancel_dogfight_matching({})
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="PlayerAgreeArenaReplyRet",result=const.error_invalid_while_dead})
        return
    else
        self:send_message_to_cross_server_arena_server({func_name="player_agree_arena",room_id=self.dogfight_room_id})
    end
end

function imp_arena.dogfight_matching_fail_because_player_not_enough(self,input,sync_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="DogfightMatchingFailBecausePlayerNotEnough"})
end

function imp_arena.player_agree_arena_reply(self,input,sync_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="PlayerAgreeArenaReplyRet",result=input.result})
end

function imp_arena.can_not_connect_qualifying_fight_server(self)
    flog("warn", "can_not_connect_qualifying_fight_server actor_id "..self.actor_id)
    self.in_arena = false
    self.waiting_create_qualifying_scene = false
    self:send_message_to_arena_server({func_name="on_notice_can_not_connect_qualifying_fight_server",challenge_type=self.challenge_type,opponent_id=self.arena_opponent_id,opponent_type=self.opponent_type})
end

function imp_arena.can_not_connect_dogfight_fight_server(self)
    flog("warn", "can_not_connect_dogfight_fight_server actor_id "..self.actor_id)
    self.dogfight_room_id = 0
    self.dogfight_matching = false
    self.in_arena = false
    self:send_message_to_cross_server_arena_server({func_name="on_notice_can_not_connect_dogfight_fight_server"})
end

function imp_arena.send_arena_info(self)
    if self.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_qualifying].level then
        return
    end
    on_get_arena_info(self)
end

register_message_handler(const.CS_MESSAGE_LUA_ARENA_INFO,on_get_arena_info)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_GET_RANK,on_get_arena_rank)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_CHALLENGE,on_arena_challenge)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_MATCHING,on_arena_matching)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_BUY_COUNT,on_arena_buy_count)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_COOLING,on_arena_cooling)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_REFRESH,on_arena_refresh)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_PET_SETTING,on_arena_setting_pet)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_QUALIFYING_GIFHT_OVER,on_arena_qualifying_fight_over)
register_message_handler(const.SS_MESSAGE_LUA_USER_LOGOUT, on_logout)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_QUALIFYING_GIFHT_QUIT,on_arena_qualifying_fight_quit)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_DOGFIGHT_CANCEL_MATCHING,on_cancel_dogfight_matching)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_DOGFIGHT_FIGHT_OVER,on_arena_dogfight_fight_over)
register_message_handler(const.CS_MESSAGE_LUA_ARENA_DOGFIGHT_QUIT_FIGHT,on_arena_dogfight_quit_fight)

imp_arena.__message_handler = {}
imp_arena.__message_handler.on_get_arena_info = on_get_arena_info
imp_arena.__message_handler.on_get_arena_rank = on_get_arena_rank
imp_arena.__message_handler.on_arena_challenge = on_arena_challenge
imp_arena.__message_handler.on_arena_matching = on_arena_matching
imp_arena.__message_handler.on_arena_buy_count = on_arena_buy_count
imp_arena.__message_handler.on_arena_cooling = on_arena_cooling
imp_arena.__message_handler.on_arena_refresh = on_arena_refresh
imp_arena.__message_handler.on_arena_setting_pet = on_arena_setting_pet
imp_arena.__message_handler.on_arena_qualifying_fight_over = on_arena_qualifying_fight_over
imp_arena.__message_handler.on_logout = on_logout
imp_arena.__message_handler.on_arena_qualifying_fight_quit = on_arena_qualifying_fight_quit
imp_arena.__message_handler.on_cancel_dogfight_matching = on_cancel_dogfight_matching
imp_arena.__message_handler.on_arena_dogfight_fight_over = on_arena_dogfight_fight_over
imp_arena.__message_handler.on_arena_dogfight_quit_fight = on_arena_dogfight_quit_fight

return imp_arena

