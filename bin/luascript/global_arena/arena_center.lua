--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/8 0008
-- Time: 17:20
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local data_base = require "basic/db_mongo"
local challenge_arena = require "data/challenge_arena"
local timer = require "basic/timer"
local online_user = require "global_arena/arena_online_user"
local arena_player = require "global_arena/arena_player"
local math = require "math"
local arena_config = require "global_arena/arena_config"
local common_system_list = require "data/common_system_list"
local challenge_arena_config = require "configs/challenge_arena_config"
local common_char_chinese_config = require "configs/common_char_chinese_config"
local mail_helper = require "global_mail/mail_helper"
local _get_now_time_second = _get_now_time_second
local table = table
local pairs = pairs

local DAY_SECOND = 86400000
local ARENA_TYPE = const.ARENA_TYPE
local arena_parameter = challenge_arena.Parameter
local ARENA_CHALLENGE_TYPE = const.ARENA_CHALLENGE_TYPE
local ARENA_CHALLENGE_OPPONENT_TYPE = const.ARENA_CHALLENGE_OPPONENT_TYPE
local SYSTEM_NAME_TO_ID = const.SYSTEM_NAME_TO_ID

local first_arena_grade_id = 0
local arena_grade_configs = {}
for _,v in pairs(challenge_arena.QualifyingGrade) do
    arena_grade_configs[v.ID] = v
    if v.NextGrade == 0 then
        first_arena_grade_id = v.ID
    end
end

--排位赛匹配表
local arena_qualifying_matching = {}
for _,v in pairs(challenge_arena.Matching) do
    arena_qualifying_matching[v.Lowerlimt] = v
end
local function get_qualifying_matching(rank)
    local limit = 100000000
    for i,_ in pairs(arena_qualifying_matching) do
        if i < limit and i >= rank then
            limit = i
        end
    end
    return arena_qualifying_matching[limit]
end

--混战赛匹配表
local arena_dogfight_matching_configs = {}
local arena_dogfight_matching_create_time = {}
for _,v in pairs(challenge_arena.Matching2) do
    arena_dogfight_matching_configs[v.CreateTime] = v
    table.insert(arena_dogfight_matching_create_time,v.CreateTime)
end

table.sort(arena_dogfight_matching_create_time)

local function get_dogfight_matching_config(create_time)
    local limit = 0
    for i=1,#arena_dogfight_matching_create_time,1 do
        if arena_dogfight_matching_create_time[i] < create_time then
            limit = arena_dogfight_matching_create_time[i]
        else
            break
        end
    end
    return arena_dogfight_matching_configs[limit]
end

local dogfight_room_id = 1
local function get_dogfight_room_id()
    dogfight_room_id = dogfight_room_id + 1
    if dogfight_room_id > 100000000 then
        dogfight_room_id = 1
    end
    return dogfight_room_id
end

local qualifying_day_reward_configs = {}
for _,v in pairs(challenge_arena.QualifyingReward) do
    if qualifying_day_reward_configs[v.MainGrade] == nil then
        qualifying_day_reward_configs[v.MainGrade] = {}
    end
    table.insert(qualifying_day_reward_configs[v.MainGrade],v)
end

for _,configs in pairs(qualifying_day_reward_configs) do
    table.sort(configs,function(a,b)
        return a.RankedLowerlimit < b.RankedLowerlimit
    end)
end

local function get_qualifying_day_reward_config(grade_id,rank)
    local qualifying_day_reward_config = nil
    if qualifying_day_reward_configs[grade_id] ~= nil then
        for _,v in ipairs(qualifying_day_reward_configs[grade_id]) do
            if v.RankedLowerlimit <= rank then
                qualifying_day_reward_config = v
            end
        end
    end
    return qualifying_day_reward_config
end

local common_system_list_configs = {}
for _,v in pairs(common_system_list.system) do
    common_system_list_configs[v.ID] = v
end

local arena_dogfight_rank_max_count = 1000

local arena_dogfight_reward_configs = {}
for _,v in pairs(challenge_arena.MeleeReward) do
    table.insert(arena_dogfight_reward_configs,v)
end
table.sort(arena_dogfight_reward_configs,function(a,b)
    return a.RankedLowerlimit < b.RankedLowerlimit
end)

local function get_arena_dogfight_reward_config(rank)
    local arena_dogfight_reward_config = nil
    for i=1,#arena_dogfight_reward_configs,1 do
        if rank >= arena_dogfight_reward_configs[i].RankedLowerlimit and (arena_dogfight_reward_config == nil or arena_dogfight_reward_configs[i].RankedLowerlimit > arena_dogfight_reward_config.RankedLowerlimit) then
            arena_dogfight_reward_config = arena_dogfight_reward_configs[i]
        end
    end
    return arena_dogfight_reward_config
end

local arena_center = {}
arena_center.__index = arena_center

setmetatable(arena_center, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

local function arena_center_fighting(self)
    if self.is_data_init == false then
        self:query_arena_ranks()
    end

    if self.init_actor_complete == false then
        self:check_init_actor_complete()
    end

    local current_time = _get_now_time_second()
    --排位赛
    for aid,fighting in pairs(self.qualifying_fighting) do
        if fighting.over_time < current_time then
            self.qualifying_fighting[aid] = nil
            if fighting.challenge_type == ARENA_CHALLENGE_TYPE.normal then
                if fighting.challenge_opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player then
                    self.fighting_normal[fighting.opponent_id] = nil
                end
            elseif fighting.challenge_type == ARENA_CHALLENGE_TYPE.upgrade then
                self.fighting_upgrade[aid] = nil
            end
        end
    end
end

function arena_center.__ctor(self)
    self.arena_ranks = {}
    self.arena_actors = {}
    self.qualifying_max = {}
    self.total_max_rank = 0
    self.sort_timer = nil
    --排位赛进行中
    self.qualifying_fighting = {}
    --主动进行的晋级挑战
    self.fighting_upgrade = {}
    --被挑战
    self.fighting_normal = {}
    local function arena_center_fighting_tick()
        arena_center_fighting(self)
    end
    self.tick_timer = timer.create_timer(arena_center_fighting_tick, 1000, const.INFINITY_CALL)
    --排位赛每日奖励
    self.qualifying_day_reward = {}
    self.actor_rewards = {}
    --周奖励
    self.weekly_rewards = {}
    self.is_data_init = false
    --总排行刷新时间
    self.next_refresh_rank_time = 0
    --初始化玩家
    self.init_actor_dict = {}
    self.init_actor_complete = false
    self.is_prepare_close = false
    --日奖励记分时间1
    self.daily_reward_score_timer1 = nil
    --日奖励记分时间2
    self.daily_reward_score_timer2 = nil
    --日奖励记分时间3
    self.daily_reward_score_timer3 = nil
    --日奖励时间
    self.daily_reward_timer = nil
    --周奖励记分时间
    self.weekly_reward_score_reset_timer = nil
    --周奖励发放时间
    self.weekly_reward_timer = nil
end

local function _db_callback_save_data(caller, status)
    flog("info", "arena _db_callback_save_data! ")
    if status == 0 then
        flog("warn", "arena _db_callback_save_data : save fail ")
        return
    end
end

local function _db_callback_save_actors(caller, status)
    flog("info", "arena _db_callback_save_actors! ")
    if status == 0 then
        flog("warn", "arena _db_callback_save_actors : save fail ")
        return
    end
    if caller.is_prepare_close then
        ArenaUserManageReadyClose()
    end
end

local function sort_dogfigght_rank(self)
    if self.init_arena_data == false then
        return
    end

    local tmp_actors = {}
    for actor_id,rank in pairs(self.arena_actors) do
        table.insert(tmp_actors,{actor_id=actor_id,total_score=rank.total_score})
    end

    if #tmp_actors > 1 then
        table.sort(tmp_actors,function(a,b)
            return b.total_score < a.total_score
        end)
    end

    for i=1,#tmp_actors,1 do
        self.arena_actors[tmp_actors[i].actor_id].total_rank = i
    end
    local player = nil
    for actor_id,rank in pairs(self.arena_actors) do
        player = online_user.get_user(actor_id)
        if player ~= nil then
            player:send_message_to_game({func_name="update_arena_dogfight_rank",dogfight_rank=rank.total_rank})
        end
    end
end

local function save_data(self)
    flog("info","arena_center.save_data")
    local actors = {}
    for grade_id,ranks in pairs(self.arena_ranks) do
        for actor_id,rank in pairs(ranks) do
            if table.isEmptyOrNil(rank) == true then
                flog("warn","arena ranks data error!!!actor_id "..actor_id)
            else
                data_base.db_update_doc(self, _db_callback_save_data, "arena_ranks", {actor_id=actor_id}, rank, 1, 0)
                table.insert(actors,actor_id)
            end
        end
    end
    data_base.db_update_doc(self, _db_callback_save_actors, "arena_actors", {}, actors, 1, 0)
    if #actors == 0 then
        if self.is_prepare_close then
            ArenaUserManageReadyClose()
        end
    end
end

--理论上不需要排序排位赛，由于目前找不到部分排名偶然缺失，初始化时重新检查排名
local function sort_qualifying_rank(self)
    for grade_id,actors in pairs(self.arena_ranks) do
        local actor_sort = {}
        for actor_id,rank in pairs(actors) do
            table.insert(actor_sort,{rank=rank.rank,actor_id=actor_id})
        end
        local count = #actor_sort
        if count > 1 then
            table.sort(actor_sort,function(a,b)
                return b.rank > a.rank
            end)
        end

        for i=1,count,1 do
            actors[actor_sort[i].actor_id].rank = i
        end
        self.qualifying_max[grade_id] = count
    end
end

function arena_center.check_init_actor_complete(self)
    for _,v in pairs(self.init_actor_dict) do
        if v.reply == false then
            return
        end
    end
    sort_qualifying_rank(self)
    sort_dogfigght_rank(self)
    self.init_actor_complete = true
end

local function query_actor_arena_rank_callback(self,status, arena_actor_data,callback_id)
    if status == false or table.isEmptyOrNil(arena_actor_data) then
        flog("warn","can not find arena actors data!!!,actor_id "..self.init_actor_dict[callback_id].actor_id)
        self.init_actor_dict[callback_id].reply = true
        return
    end
    if arena_actor_data.rank == nil then
        self.init_actor_dict[callback_id].reply = true
        return
    end

    self.total_max_rank = self.total_max_rank + 1
    if self.arena_ranks[arena_actor_data.grade_id] == nil then
        self.arena_ranks[arena_actor_data.grade_id] = {}
    end
    if self.qualifying_max[arena_actor_data.grade_id] == nil then
        self.qualifying_max[arena_actor_data.grade_id] = arena_actor_data.rank
    end
    if self.qualifying_max[arena_actor_data.grade_id] < arena_actor_data.rank then
        self.qualifying_max[arena_actor_data.grade_id] = arena_actor_data.rank
    end
    self.arena_actors[arena_actor_data.actor_id] = arena_actor_data
    self.arena_ranks[arena_actor_data.grade_id][arena_actor_data.actor_id] = arena_actor_data
    self.init_actor_dict[callback_id].reply = true
end

local function _db_callback_get_arena_actors(self, status, arena_actors,callback_id)

    if self.is_data_init == true then
        return
    end
    if self.arena_ranks == nil then
        self.arena_ranks = {}
    end

    if self.qualifying_max == nil then
        self.qualifying_max = {}
    end

    for i,_ in pairs(arena_grade_configs) do
        if self.arena_ranks[i] == nil then
            self.arena_ranks[i] = {}
        end
        if self.qualifying_max[i] == nil then
            self.qualifying_max[i] = 0
        end
    end

    if self.arena_actors == nil then
        self.arena_actors = {}
    end

    self.is_data_init = true
    if status == false or table.isEmptyOrNil(arena_actors) then
        flog("info","can not find arena actors data")
        save_data(self)
    else
        self.init_actor_complete = false
        for i=1,#arena_actors,1 do
            local callback_id = data_base.db_find_one(self,query_actor_arena_rank_callback, "arena_ranks", {actor_id=arena_actors[i]}, {})
            self.init_actor_dict[callback_id] = {}
            self.init_actor_dict[callback_id].actor_id = arena_actors[i]
            self.init_actor_dict[callback_id].reply = false
        end
    end
end

local function remove_sort_timer(self)
    if self.sort_timer ~= nil then
        timer.destroy_timer(self.sort_timer)
        self.sort_timer = nil
    end
end

--日奖励算分时间1
local function daily_reward_score_timer1_handle(self)
    self.qualifying_day_reward[1] = {}
    self.qualifying_day_reward[1].actors = {}
    for _,actor in pairs(self.arena_actors) do
        self.qualifying_day_reward[1].actors[actor.actor_id] = {}
        self.qualifying_day_reward[1].actors[actor.actor_id].grade_id = actor.grade_id
        self.qualifying_day_reward[1].actors[actor.actor_id].rank = actor.rank
    end
end

local function daily_reward_score_timer1_delay_handle(self)
    timer.destroy_timer(self.daily_reward_score_timer1)
    daily_reward_score_timer1_handle(self)
    local function _daily_reward_score_timer1_handle()
        daily_reward_score_timer1_handle(self)
    end
    self.daily_reward_score_timer1 = timer.create_timer(_daily_reward_score_timer1_handle,DAY_SECOND*1000,const.INFINITY_CALL)
end

--日奖励算分时间2
local function daily_reward_score_timer2_handle(self)
    self.qualifying_day_reward[2] = {}
    self.qualifying_day_reward[2].actors = {}
    for _,actor in pairs(self.arena_actors) do
        self.qualifying_day_reward[2].actors[actor.actor_id] = {}
        self.qualifying_day_reward[2].actors[actor.actor_id].grade_id = actor.grade_id
        self.qualifying_day_reward[2].actors[actor.actor_id].rank = actor.rank
    end
end

local function daily_reward_score_timer2_delay_handle(self)
    timer.destroy_timer(self.daily_reward_score_timer2)
    daily_reward_score_timer2_handle(self)
    local function _daily_reward_score_timer2_handle()
        daily_reward_score_timer2_handle(self)
    end
    self.daily_reward_score_timer2 = timer.create_timer(_daily_reward_score_timer2_handle,DAY_SECOND*1000,const.INFINITY_CALL)
end

--日奖励算分时间3
local function daily_reward_score_timer3_handle(self)
    self.qualifying_day_reward[3] = {}
    self.qualifying_day_reward[3].actors = {}
    for _,actor in pairs(self.arena_actors) do
        self.qualifying_day_reward[3].actors[actor.actor_id] = {}
        self.qualifying_day_reward[3].actors[actor.actor_id].grade_id = actor.grade_id
        self.qualifying_day_reward[3].actors[actor.actor_id].rank = actor.rank
    end
end

local function daily_reward_score_timer3_delay_handle(self)
    timer.destroy_timer(self.daily_reward_score_timer3)
    daily_reward_score_timer3_handle(self)
    local function _daily_reward_score_timer3_handle()
        daily_reward_score_timer3_handle(self)
    end
    self.daily_reward_score_timer3 = timer.create_timer(_daily_reward_score_timer3_handle,DAY_SECOND*1000,const.INFINITY_CALL)
end

--日奖励发放
local function daily_reward_timer_handle(self)
    self:send_qualifying_day_reward()
end

local function daily_reward_timer_delay_handle(self)
    timer.destroy_timer(self.daily_reward_timer)
    daily_reward_timer_handle(self)
    local function _daily_reward_timer_handle()
        daily_reward_timer_handle(self)
    end
    self.daily_reward_timer = timer.create_timer(_daily_reward_timer_handle,DAY_SECOND*1000,const.INFINITY_CALL)
end

local function weekly_reward_timer_handle(self)
    self:send_weekly_reward()
end

--周奖励发放
local function weekly_reward_timer_delay_handle(self)
    timer.destroy_timer(self.weekly_reward_timer)
    weekly_reward_timer_handle(self)
    local function _weekly_reward_timer_handle()
        weekly_reward_timer_handle(self)
    end
    self.weekly_reward_timer = timer.create_timer(_weekly_reward_timer_handle,DAY_SECOND*1000*7,const.INFINITY_CALL)
end

--周积分清空时间
local function weekly_reward_score_reset_timer_handle(self)
    for actor_id,rank in pairs(self.arena_actors) do
        rank.total_score = 0
        rank.qualifying_score = 0
    end
end

local function weekly_reward_score_reset_timer_delay_handle(self)
    timer.destroy_timer(self.weekly_reward_score_reset_timer)
    weekly_reward_score_reset_timer_handle(self)
    local function _weekly_reward_score_reset_timer_handle()
        weekly_reward_score_reset_timer_handle(self)
    end
    self.weekly_reward_score_reset_timer = timer.create_timer(_weekly_reward_score_reset_timer_handle,DAY_SECOND*1000*7,const.INFINITY_CALL)
end

local function init_timer(self)
    local current_time = _get_now_time_second()
    --日奖励记分时间1
    local date = os.date("*t",current_time)
    date.hour = challenge_arena_config.get_daily_reward_score_time1()[1]
    date.min = challenge_arena_config.get_daily_reward_score_time1()[2]
    date.sec = 0
    local time = os.time(date)
    if time < current_time then
        time = time + DAY_SECOND
    end
    time = time - current_time
    local function _daily_reward_score_timer1_delay_handle()
        daily_reward_score_timer1_delay_handle(self)
    end
    self.daily_reward_score_timer1 = timer.create_timer(_daily_reward_score_timer1_delay_handle,time*1000,0)
    --日奖励记分时间2
    date = os.date("*t",current_time)
    date.hour = challenge_arena_config.get_daily_reward_score_time2()[1]
    date.min = challenge_arena_config.get_daily_reward_score_time2()[2]
    date.sec = 0
    local time = os.time(date)
    if time < current_time then
        time = time + DAY_SECOND
    end
    time = time - current_time
    local function _daily_reward_score_timer2_delay_handle()
        daily_reward_score_timer2_delay_handle(self)
    end
    self.daily_reward_score_timer2 = timer.create_timer(_daily_reward_score_timer2_delay_handle,time*1000,0)
    --日奖励记分时间3
    date = os.date("*t",current_time)
    date.hour = challenge_arena_config.get_daily_reward_score_time3()[1]
    date.min = challenge_arena_config.get_daily_reward_score_time3()[2]
    date.sec = 0
    time = os.time(date)
    if time < current_time then
        time = time + DAY_SECOND
    end
    time = time - current_time
    local function _daily_reward_score_timer3_delay_handle()
        daily_reward_score_timer3_delay_handle(self)
    end
    self.daily_reward_score_timer3 = timer.create_timer(_daily_reward_score_timer3_delay_handle,time*1000,0)
    --日奖励时间
    date = os.date("*t",current_time)
    date.hour = challenge_arena_config.get_daily_reward_time()[1]
    date.min = challenge_arena_config.get_daily_reward_time()[2]
    date.sec = 0
    time = os.time(date)
    if time < current_time then
        time = time + DAY_SECOND
    end
    local function _daily_reward_timer_delay_handle()
        daily_reward_timer_delay_handle(self)
    end
    time = time - current_time
     self.daily_reward_timer = timer.create_timer(_daily_reward_timer_delay_handle,time*1000,0)
    --周积分重置时间
    date = os.date("*t",current_time)
    date.hour = challenge_arena_config.get_weekly_score_reset_time()[2]
    date.min = challenge_arena_config.get_weekly_score_reset_time()[3]
    date.sec = 0
    time = os.time(date)
    if date.wday == challenge_arena_config.get_weekly_score_reset_time()[1] then
        if time < current_time then
            time = time + DAY_SECOND*7
        end
    else
        if date.wday < challenge_arena_config.get_weekly_score_reset_time()[1] then
            date.wday = date.wday + 7
        end
        time = time + DAY_SECOND*(date.wday - challenge_arena_config.get_weekly_score_reset_time()[1])
    end
    time = time - current_time
    local function _weekly_reward_score_reset_timer_delay_handle()
        weekly_reward_score_reset_timer_delay_handle(self)
    end
    self.weekly_reward_score_reset_timer = timer.create_timer(_weekly_reward_score_reset_timer_delay_handle,time*1000,0)
    --周奖励发放时间
    date = os.date("*t",current_time)
    date.hour = challenge_arena_config.get_weekly_reward_time()[2]
    date.min = challenge_arena_config.get_weekly_reward_time()[3]
    date.sec = 0
    time = os.time(date)
    if date.wday == challenge_arena_config.get_weekly_reward_time()[1] then
        if time < current_time then
            time = time + DAY_SECOND*7
        end
    else
        if date.wday < challenge_arena_config.get_weekly_reward_time()[1] then
            date.wday = date.wday + 7
        end
        time = time + DAY_SECOND*(date.wday - challenge_arena_config.get_weekly_reward_time()[1])
    end
    time = time - current_time
    local function _weekly_reward_timer_delay_handle()
        weekly_reward_timer_delay_handle(self)
    end
    self.weekly_reward_timer = timer.create_timer(_weekly_reward_timer_delay_handle,time*1000,0)
end

local function init()
    flog("info","arena center init")
    data_base.db_find_one(arena_center_instance, _db_callback_get_arena_actors, "arena_actors", {}, {})
    remove_sort_timer(arena_center_instance)
    arena_center_instance.next_refresh_rank_time = _get_now_time_second() + 600
    local function syn_tick()
        --排序
        sort_dogfigght_rank(arena_center_instance)
        arena_center_instance.next_refresh_rank_time = _get_now_time_second() + 600
        save_data(arena_center_instance)
    end

    arena_center_instance.sort_timer = timer.create_timer(syn_tick, 600000, const.INFINITY_CALL)
    init_timer(arena_center_instance)
end

function arena_center.query_arena_ranks(self)
    data_base.db_find_one(arena_center_instance, _db_callback_get_arena_actors, "arena_actors", {}, {})
end

function arena_center.on_arena_player_init(self,input,game_id)
    local actor_id = input.actor_id
    local player = online_user.get_user(actor_id)
    if player == nil then
        player = arena_player(actor_id)
        online_user.add_user(actor_id,player)
        if self.arena_actors[actor_id] == nil then
            if self.arena_ranks[first_arena_grade_id] == nil then
                self.arena_ranks[first_arena_grade_id] = {}
            end

            self.arena_ranks[first_arena_grade_id][actor_id] = {}
            self.qualifying_max[first_arena_grade_id] = self.qualifying_max[first_arena_grade_id] + 1
            self.arena_ranks[first_arena_grade_id][actor_id].rank = self.qualifying_max[first_arena_grade_id]
            self.arena_ranks[first_arena_grade_id][actor_id].grade_id = first_arena_grade_id
            self.arena_ranks[first_arena_grade_id][actor_id].qualifying_score = 0
            self.arena_ranks[first_arena_grade_id][actor_id].total_score = 0
            self.total_max_rank = self.total_max_rank + 1
            self.arena_ranks[first_arena_grade_id][actor_id].total_rank = self.total_max_rank
            self.arena_actors[actor_id] = self.arena_ranks[first_arena_grade_id][actor_id]

            flog("salog","new player init arena,grade_id:"..first_arena_grade_id..",rank:"..self.qualifying_max[first_arena_grade_id],actor_id)
        end
    end
    player:set_game_id(game_id)
    local qualifying_data = self.arena_actors[actor_id]
    if qualifying_data ~= nil then
        qualifying_data.actor_id = actor_id
        qualifying_data.actor_name = input.actor_name
        qualifying_data.level = input.level
        qualifying_data.vocation = input.vocation
        qualifying_data.union_name = input.union_name
        qualifying_data.fight_power = input.fight_power
        qualifying_data.spritual = input.spritual
        qualifying_data.sex = input.sex
    end
end

function arena_center.update_player_info(self,input,game_id)
    if self.arena_actors[input.actor_id] == nil then
        return
    end
    self.arena_actors[input.actor_id][input.attribute] = input.attribute_value
end

function arena_center.on_get_actor_arena_info(self,input,game_id)
    local actor_id = input.actor_id
    if self.arena_actors[actor_id] == nil then
        return
    end
    local player = online_user.get_user(actor_id)
    if player == nil then
        return
    end
    player:send_message_to_game({func_name="on_get_actor_arena_info_reply",result=0,qualifying_score=self.arena_actors[actor_id].qualifying_score,total_score=self.arena_actors[actor_id].total_score,dogfight_score=self.arena_actors[actor_id].total_score - self.arena_actors[actor_id].qualifying_score,qualifying_score=self.arena_actors[actor_id].qualifying_score,qualifying_rank=self.arena_actors[actor_id].rank,dogfight_rank=self.arena_actors[actor_id].total_rank,grade_id=self.arena_actors[actor_id].grade_id})
end

function arena_center.on_arena_player_logout(self,input,game_id)
    local actor_id = input.actor_id
    if self.qualifying_fighting[actor_id] ~= nil then
        if self.qualifying_fighting[actor_id].challenge_type == ARENA_CHALLENGE_TYPE.normal then
            if self.qualifying_fighting[actor_id].challenge_opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player then
                self.fighting_normal[self.qualifying_fighting[actor_id].opponent_id] = nil
            end
        elseif self.qualifying_fighting[actor_id].challenge_type == ARENA_CHALLENGE_TYPE.upgrade then
            self.fighting_upgrade[actor_id] = nil
        end
        self.qualifying_fighting[actor_id] = nil
    end
    online_user.del_user(actor_id)
end

function arena_center.get_arena_rank(self,input,game_id)
    local player = online_user.get_user(input.actor_id)
    if player == nil then
        flog("tmlDebug","arena_center.get_arena_rank can not find player,actor_id "..input.actor_id)
        return
    end

    local result = 0
    local data = {}
    if input.type == ARENA_TYPE.qualifying then
        for _,rank in pairs(self.arena_ranks[input.grade_id]) do
            if rank.rank >= input.rank_start and rank.rank < input.rank_start + arena_parameter[37].Value[1] then
                data[rank.rank] = table.copy(rank)
                data[rank.rank].dogfight_score = rank.total_score - rank.qualifying_score
            end
        end
    elseif input.type == ARENA_TYPE.dogfight then
        for _,rank in pairs(self.arena_actors) do
            if rank.total_rank >= input.rank_start and rank.total_rank < input.rank_start + arena_parameter[37].Value[1] then
                data[rank.total_rank] = table.copy(rank)
                data[rank.total_rank].dogfight_score = rank.total_score - rank.qualifying_score
            end
        end
    else
        result = const.error_arena_type
    end
    player:send_message_to_game({result = result,rank_data=data,next_refresh_rank_time=self.next_refresh_rank_time,func_name="reply_get_arena_rank"})
end

function arena_center.refresh_arena_qualifying(self,input)
    local actor_id = input.actor_id
    local player = online_user.get_user(actor_id)
    if player == nil then
        flog("tmlDebug","arena_center.refresh_arena_qualifying can not find player,actor_id "..actor_id)
        return
    end

    local my_rank = self.arena_actors[actor_id]
    if my_rank == nil then
        flog("tmlDebug","arena_center.refresh_arena_qualifying can not find actor arena info,actor_id "..actor_id)
        return
    end
    local grade_id = my_rank.grade_id
    if self.arena_ranks[grade_id] == nil then
        flog("tmlDebug","arena_center.refresh_arena_qualifying can not find grade info,grade_id "..grade_id)
        return
    end
    local result = 0
    local data = {}
    flog("tmlDebug","my rank:"..my_rank.rank)
    local matching_cfg = get_qualifying_matching(my_rank.rank)
    if matching_cfg == nil then
        flog("tmlDebug","can not find qualifying  matching config!rank:"..my_rank.rank)
        result = const.error_arena_qualifying_refresh_no_info
    else
        data.normal_opponents = {}
        local ranges = {}
        if my_rank.rank > 2 then
            table.insert(ranges,{my_rank.rank + 1,my_rank.rank + matching_cfg.Seat1 })
            table.insert(ranges,{my_rank.rank + matching_cfg.Seat2,my_rank.rank - 1})
            table.insert(ranges,{my_rank.rank + matching_cfg.Seat3,my_rank.rank + matching_cfg.Seat2 - 1})
        elseif my_rank.rank == 2 then
            table.insert(ranges,{my_rank.rank + matching_cfg.Seat2+ 1,my_rank.rank + matching_cfg.Seat1 })
            table.insert(ranges,{my_rank.rank + 1,my_rank.rank + matching_cfg.Seat2})
            table.insert(ranges,{my_rank.rank + matching_cfg.Seat3,my_rank.rank - 1})
        else
            table.insert(ranges,{my_rank.rank + matching_cfg.Seat2+ 1,my_rank.rank + matching_cfg.Seat1 })
            table.insert(ranges,{my_rank.rank + matching_cfg.Seat3+ 1,my_rank.rank + matching_cfg.Seat2 })
            table.insert(ranges,{my_rank.rank + 1,my_rank.rank + matching_cfg.Seat3 })
        end

        --处理边界问题
        for  i = #ranges,1,-1 do
            if ranges[i][1] < 1 then
                ranges[i][1] = 1
            end
            if ranges[i][2] > self.qualifying_max[grade_id] then
                ranges[i][2] = self.qualifying_max[grade_id]
            end

            if ranges[i][1] > self.qualifying_max[grade_id] then
                table.remove(ranges,i)
            elseif ranges[i][1] == ranges[i][2] then
                if ranges[i][2] == my_rank.rank then
                    table.remove(ranges,i)
                end
            elseif ranges[i][1] > ranges[i][2] then
                table.remove(ranges,i)
            else
                if ranges[i][1] == my_rank.rank then
                    ranges[i][1] = ranges[i][1] + 1
                elseif ranges[i][2] == my_rank.rank then
                    ranges[i][2] = ranges[i][2] -1
                end
            end
        end

        flog("tmlDebug","after edge="..table.serialize(ranges))
        --补足三个
        local ranges_count = #ranges
        if ranges_count == 1 then
            local min_rank = ranges[ranges_count][1]
            local max_rank = ranges[ranges_count][2]
            if max_rank - min_rank >= 2 then
                ranges[ranges_count][2] = max_rank - 2
                table.insert(ranges,{max_rank - 1,max_rank - 1})
                table.insert(ranges,{max_rank,max_rank})
            end
        elseif ranges_count == 2 then
            if ranges[ranges_count][2] - ranges[ranges_count][1] > 0 then
                local min_rank = ranges[ranges_count][1]
                local max_rank = ranges[ranges_count][2]
                local middle_rank = math.floor((max_rank + min_rank) / 2)
                if middle_rank < min_rank then
                    middle_rank = min_rank
                end
                ranges[ranges_count][2] = middle_rank
                table.insert(ranges,{middle_rank+1,max_rank})
            elseif ranges[1][2] - ranges[1][1] > 0 then
                local min_rank = ranges[1][1]
                local max_rank = ranges[1][2]
                local middle_rank = math.floor((max_rank + min_rank) / 2)
                if middle_rank < min_rank then
                    middle_rank = min_rank
                end
                ranges[1][2] = middle_rank
                table.insert(ranges,2,{middle_rank+1,max_rank})
            end
        end
        flog("tmlDebug","three!three!="..table.serialize(ranges))
        local select_ranks = {}
        for i = 1,#ranges,1 do
            local rank = math.random(ranges[i][1],ranges[i][2])
            table.insert(select_ranks,rank)
        end
        flog("tmlDebug","select ranks="..table.serialize(select_ranks))
        for i=1,#select_ranks,1 do
            for _,v in pairs(self.arena_ranks[grade_id]) do
                if v.rank == select_ranks[i] then
                    table.insert(data.normal_opponents,table.copy(v))
                    break
                end
            end
        end
        --晋级
        data.upgrade_opponent = {}
        if my_rank.rank <= 10 then
            data.upgrade_opponent.challenge = true
        else
            data.upgrade_opponent.challenge = false
        end
        local current_grade_cfg = arena_grade_configs[grade_id]
        if current_grade_cfg ~= nil then
            local next_grade_cfg = arena_grade_configs[current_grade_cfg.ExGrade]
            if next_grade_cfg ~= nil then
                if self.qualifying_max[current_grade_cfg.ExGrade] >= next_grade_cfg.Number then
                    --玩家
                    data.upgrade_opponent.type = ARENA_CHALLENGE_OPPONENT_TYPE.player
                    local min_rank = self.qualifying_max[current_grade_cfg.ExGrade] - 10
                    if min_rank < 1 then
                        min_rank = 1
                    end
                    local upgrade_rank = math.random(min_rank,self.qualifying_max[current_grade_cfg.ExGrade])
                    for _,v in pairs(self.arena_ranks[grade_id]) do
                        if v.rank == upgrade_rank then
                            data.upgrade_opponent.opponent_data = table.copy(v)
                            break
                        end
                    end
                else
                    -- 守门人
                    data.upgrade_opponent.type = ARENA_CHALLENGE_OPPONENT_TYPE.monster
                    data.upgrade_opponent.opponent_data = {}
                    data.upgrade_opponent.opponent_data.rank = self.qualifying_max[current_grade_cfg.ExGrade] + 1
                    data.upgrade_opponent.opponent_data.grade_id = current_grade_cfg.ExGrade
                end
            end
        end
    end
    player:send_message_to_game({result=result,opponent_data=data,func_name="reply_arena_refresh"})
end

function arena_center.get_player_grade_id(self,actor_id)
    if self.arena_actors[actor_id] ~= nil then
        return self.arena_actors[actor_id].grade_id
    end
    return 0
end

function arena_center.arena_challenge(self,input)
    local actor_id = input.actor_id
    local player = online_user.get_user(actor_id)
    if player == nil then
        flog("tmlDebug","arena_center.arena_challenge can not find player,actor_id "..actor_id)
        return
    end
    local my_rank = self.arena_actors[actor_id]
    if my_rank == nil then
        flog("tmlDebug","arena_center.arena_challenge can not find actor arena info,actor_id "..actor_id)
        return
    end
    local grade_id = my_rank.grade_id
    if self.arena_ranks[grade_id] == nil then
        flog("tmlDebug","arena_center.arena_challenge can not find grade info,grade_id "..grade_id)
        return
    end
    local result = 0
    if input.challenge_type == ARENA_CHALLENGE_TYPE.normal then
        if input.challenge_opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player then
            if self.fighting_normal[input.opponent_id] ~= nil then
                result = const.error_arena_challenge_player_challenged
                player:send_message_to_game({func_name="reply_arena_challenge",result=result})
            end
            if self.fighting_upgrade[input.opponent_id] ~= nil then
                result = const.error_arena_challenge_player_upgrade
                player:send_message_to_game({func_name="reply_arena_challenge",result=result})
            end

            if grade_id ~= self:get_player_grade_id(input.opponent_id) or self.arena_ranks[grade_id][input.opponent_id] == nil or self.arena_ranks[grade_id][input.opponent_id].rank ~= input.opponent_rank then
                result = const.error_arena_challenge_opponent_rank_update
                player:send_message_to_game({func_name="reply_arena_challenge",result=result})
            end

            self.fighting_normal[input.opponent_id] = {}
            self.fighting_normal[input.opponent_id].actor_id = input.opponent_id
        else
            result = const.error_arena_challenge_normal_monster
            player:send_message_to_game({func_name="reply_arena_challenge",result=result})
        end
        self.qualifying_fighting[actor_id] = {}
        self.qualifying_fighting[actor_id].challenge_type = ARENA_CHALLENGE_TYPE.normal
        self.qualifying_fighting[actor_id].challenge_opponent_type = ARENA_CHALLENGE_OPPONENT_TYPE.player
        self.qualifying_fighting[actor_id].opponent_id = input.opponent_id
        self.qualifying_fighting[actor_id].over_time = _get_now_time_second() + challenge_arena_config.get_qualifying_arena_fight_ready_time() + challenge_arena_config.get_qualifying_arena_duration() + 120
        player:send_message_to_game({func_name="reply_arena_challenge",result=result})
    elseif input.challenge_type == ARENA_CHALLENGE_TYPE.upgrade then
        if self.fighting_normal[actor_id] ~= nil then
            result = const.error_arena_challenge_me_challenged
            player:send_message_to_game({func_name="reply_arena_challenge",result=result})
        end

        local current_grade_cfg = arena_grade_configs[grade_id]
        if current_grade_cfg == nil then
            result = const.error_arena_grade_data
            player:send_message_to_game({func_name="reply_arena_challenge",result=result})
        end
        local next_grade_cfg = arena_grade_configs[current_grade_cfg.ExGrade]
        if next_grade_cfg == nil then
            result = const.error_arena_grade_max
            player:send_message_to_game({func_name="reply_arena_challenge",result=result})
        end

        if my_rank.rank > 10 then
            result = const.error_arena_challenge_upgrade_rank
            player:send_message_to_game({func_name="reply_arena_challenge",result=result})
        end

        if input.challenge_opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player then
            if self.arena_ranks[current_grade_cfg.ExGrade] == nil or self.arena_ranks[current_grade_cfg.ExGrade][input.opponent_id] == nil or self.arena_ranks[current_grade_cfg.ExGrade][input.opponent_id].rank ~= input.opponent_rank then
                result = const.error_arena_challenge_opponent_rank_update
                player:send_message_to_game({func_name="reply_arena_challenge",result=result})
            end
        elseif input.opponent_rank ~= self.qualifying_max[current_grade_cfg.ExGrade] + 1 then
            flog("tmlDebug","input.opponent_rank:"..input.opponent_rank..",max_rank:"..(self.qualifying_max[current_grade_cfg.ExGrade] + 1))
            result = const.error_arena_challenge_opponent_rank_update
            player:send_message_to_game({func_name="reply_arena_challenge",result=result})
        end

        self.fighting_upgrade[actor_id] = {}
        self.fighting_upgrade[actor_id].actor_id = input.opponent_id

        self.qualifying_fighting[actor_id] = {}
        self.qualifying_fighting[actor_id].challenge_type = ARENA_CHALLENGE_TYPE.upgrade
        self.qualifying_fighting[actor_id].challenge_opponent_type = input.challenge_opponent_type
        self.qualifying_fighting[actor_id].opponent_id = input.opponent_id
        self.qualifying_fighting[actor_id].over_time = _get_now_time_second() + challenge_arena_config.get_qualifying_arena_fight_ready_time() + challenge_arena_config.get_qualifying_arena_duration() + 120
        player:send_message_to_game({func_name="reply_arena_challenge",result=result})
    else
        flog("tmlDebug","arena challenge type error!!!")
    end
end

function arena_center.cancel_qualifying_challenge(self,input)
    flog("tmlDebug","arena_center.cancel_qualifying_challenge")
    local result = 0
    if input.challenge_type == ARENA_CHALLENGE_TYPE.normal then
        if input.opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player then
            self.fighting_normal[input.opponent_id] = nil
        end
        self.qualifying_fighting[input.actor_id] = nil
    elseif input.challenge_type == ARENA_CHALLENGE_TYPE.upgrade then
        self.fighting_upgrade[input.actor_id] = nil
        self.qualifying_fighting[input.actor_id] = nil
    end
end

local function send_mail_to_fail_player(self,actor_id,opponent_name,grade_id,rank)
    local actor = self.arena_actors[actor_id]
    if actor == nil then
        return
    end

    if actor.level < common_system_list_configs[SYSTEM_NAME_TO_ID.arena_qualifying].level then
        return
    end

    if opponent_name == nil then
        opponent_name = ""
    end
    local replace_string = common_char_chinese_config.get_back_text(2135001)
    replace_string = string.format(replace_string,challenge_arena_config.get_arena_grade_name(grade_id),rank)
    mail_helper.send_mail(actor_id,const.MAIL_IDS.ARENA_RANK_CHANGE,{},_get_now_time_second(),{opponent_name,replace_string})
end

function arena_center.arena_qualifying_fight_over(self,input)
    flog("tmlDebug","arena_center.arena_qualifying_fight_over")
    local actor_id = input.actor_id
    local player = online_user.get_user(actor_id)
    if player == nil then
        flog("tmlDebug","arena_center.arena_qualifying_fight_over can not find player,actor_id "..actor_id)
        return
    end

    local my_rank = self.arena_actors[actor_id]
    if my_rank == nil then
        flog("tmlDebug","arena_center.arena_qualifying_fight_over can not find actor arena info,actor_id "..actor_id)
        return
    end
    local grade_id = my_rank.grade_id
    if self.arena_ranks[grade_id] == nil then
        flog("tmlDebug","arena_center.arena_qualifying_fight_over can not find grade info,grade_id "..grade_id)
        return
    end
    local current_grade_config = arena_grade_configs[grade_id]
    if current_grade_config == nil then
        flog("tmlDebug","arena_center.arena_qualifying_fight_over current_grade_config == nil,grade_id "..grade_id)
        return
    end
    local result = 0
    local new_grade_id = input.grade_id
    local new_rank = 0
    local upgrade = false
    local rank_up = 0
    local server_rank = 0

    self.fighting_upgrade[actor_id] = nil
    if input.opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player then
        self.fighting_normal[self.qualifying_fighting[actor_id].opponent_id] = nil
    end
    if self.qualifying_fighting[actor_id] ~= nil then
        local opponent_id = self.qualifying_fighting[actor_id].opponent_id
        if self.qualifying_fighting[actor_id].challenge_type == ARENA_CHALLENGE_TYPE.upgrade then
            if input.success == true then
                local current_grade_config = arena_grade_configs[grade_id]
                if self.arena_ranks[grade_id] ~= nil and self.arena_ranks[current_grade_config.ExGrade] ~= nil then
                    if self.qualifying_fighting[actor_id].challenge_opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player then
                        local tmpRank = my_rank.rank
                        local tmpData = my_rank
                        local opponent_rank = self.arena_ranks[current_grade_config.ExGrade][self.qualifying_fighting[actor_id].opponent_id]
                        if opponent_rank ~= nil then
                            tmpData.rank = opponent_rank.rank
                            --对方数据更改
                            self.arena_ranks[grade_id][opponent_id] = opponent_rank
                            self.arena_ranks[grade_id][opponent_id].rank = tmpRank
                            self.arena_ranks[current_grade_config.ExGrade][opponent_id] = nil
                            self.arena_actors[opponent_id] = opponent_rank
                            opponent_rank.grade_id = grade_id
                            --己方数据更改
                            self.arena_ranks[current_grade_config.ExGrade][actor_id] = tmpData
                            self.arena_ranks[grade_id][actor_id] = nil
                            self.arena_actors[actor_id] = tmpData
                            tmpData.grade_id = current_grade_config.ExGrade

                            new_rank = tmpData.rank
                            upgrade = true
                            server_rank = self:get_arena_qualifying_server_rank(actor_id)
                            send_mail_to_fail_player(self,opponent_id,my_rank.actor_name,grade_id,tmpRank)
                            flog("salog",string.format("upgrade arena qualifying change,grade %d --> %d, rank %d -->%d",grade_id,current_grade_config.ExGrade,tmpRank,new_rank),actor_id)
                            flog("salog",string.format("upgrade arena qualifying change,grade %d --> %d, rank %d -->%d",current_grade_config.ExGrade,grade_id,new_rank,tmpRank),opponent_id)

                            --刷新被挑战者数据
                            local opponent_player = online_user.get_user(opponent_id)
                            if opponent_player ~= nil then
                                self:on_get_actor_arena_info({actor_id=opponent_id})
                                self:refresh_arena_qualifying({actor_id=opponent_id})
                            end
                        end
                        rank_up = tmpRank + self.qualifying_max[current_grade_config.ExGrade] - new_rank
                        new_grade_id = current_grade_config.ExGrade
                    else
                        local tmpRank = my_rank.rank
                        self.arena_ranks[current_grade_config.ExGrade][actor_id] = my_rank
                        new_rank = self.qualifying_max[current_grade_config.ExGrade] + 1
                        my_rank.rank = new_rank
                        my_rank.grade_id = current_grade_config.ExGrade
                        self.arena_ranks[grade_id][actor_id] = nil

                        self.qualifying_max[current_grade_config.ExGrade] = new_rank
                        self.qualifying_max[grade_id] = self.qualifying_max[grade_id] - 1
                        upgrade = true
                        server_rank = self:get_arena_qualifying_server_rank(actor_id)
                        new_grade_id = current_grade_config.ExGrade
                        for _,other_data in pairs(self.arena_ranks[grade_id]) do
                            if other_data.rank > tmpRank then
                                other_data.rank = other_data.rank - 1
                            end
                        end
                        rank_up = tmpRank
                        flog("salog",string.format("upgrade arena qualifying change,grade %d --> %d, rank %d -->%d",grade_id,current_grade_config.ExGrade,tmpRank,new_rank),actor_id)
                    end
                end
            end
        else
            if self.qualifying_fighting[actor_id].challenge_opponent_type == ARENA_CHALLENGE_OPPONENT_TYPE.player then
                if input.success == true and self.arena_ranks[grade_id][opponent_id] ~= nil then
                    local myRank = my_rank.rank
                    local opponentRank = self.arena_ranks[grade_id][opponent_id].rank
                    if opponentRank < myRank then
                        rank_up = myRank - opponentRank
                        my_rank.rank = opponentRank
                        self.arena_ranks[grade_id][opponent_id].rank = myRank
                        new_rank = opponentRank
                        server_rank = self:get_arena_qualifying_server_rank(actor_id)
                        send_mail_to_fail_player(self,opponent_id,self.arena_ranks[grade_id][actor_id].actor_name,grade_id,myRank)
                        flog("salog",string.format("normal arena qualifying change,grade %d --> %d, rank %d -->%d",grade_id,grade_id,myRank,opponentRank),actor_id)
                        flog("salog",string.format("normal arena qualifying change,grade %d --> %d, rank %d -->%d",grade_id,grade_id,opponentRank,myRank),opponent_id)
                        --刷新被挑战者数据
                        local opponent_player = online_user.get_user(opponent_id)
                        if opponent_player ~= nil then
                            self:on_get_actor_arena_info({actor_id=opponent_id})
                            self:refresh_arena_qualifying({actor_id=opponent_id})
                        end
                    end
                end
            end
        end
    end
    self.qualifying_fighting[input.actor_id] = nil
    player:send_message_to_game({func_name="reply_arena_qualifying_fight_over",result=result,success=input.success,grade_id=new_grade_id,rank = new_rank,upgrade=upgrade,rank_up=rank_up,server_rank=server_rank})
end

function arena_center.on_dogfight_arena_fight_over_score(self,input)
    if input.actor_id == nil then
        return
    end

    local actor_rank = self.arena_actors[input.actor_id]
    if actor_rank ~= nil then
        actor_rank.total_score = actor_rank.total_score + input.total_score
        flog("salog", string.format("dogfight arena fight over, add score:%s", tostring(input.total_score)), input.actor_id)
        if actor_rank.total_score < 0 then
            actor_rank.total_score = 0
        end
    end
end

function arena_center.get_arena_qualifying_server_rank(self,actor_id)
    local server_rank = 0
    local actor = self.arena_actors[actor_id]
    if actor == nil then
        return server_rank
    end

    local arena_grade_list = arena_config.get_arena_grade_list()
    local grade_count = #arena_grade_list
    for i = grade_count,1,-1 do
        if arena_grade_list[i] == actor.grade then
            server_rank = server_rank + actor.rank
            break
        end
        server_rank = server_rank + self.qualifying_max[arena_grade_list[i]]
    end
    return server_rank
end

function arena_center.arena_add_score(self,input)
    local actor = self.arena_actors[input.actor_id]
    if actor ~= nil then
        actor.total_score = actor.total_score + input.addon
        if actor.total_score < 0 then
            actor.total_score = 0
        end
    end
end

--排位赛奖励
function arena_center.send_qualifying_day_reward(self)
    local current_time = _get_now_time_second()
    self.actor_rewards = {}
    for actor_id,actor in pairs(self.arena_actors) do
        if actor.level >= common_system_list_configs[SYSTEM_NAME_TO_ID.arena_qualifying].level then
            self.actor_rewards[actor_id] = {}
            self.actor_rewards[actor_id].items = {}
            self.actor_rewards[actor_id].ranks = {}
            self.actor_rewards[actor_id].qualifying_score = 0
            for _,rewards in pairs(self.qualifying_day_reward) do
                repeat
                    if rewards.actors[actor.actor_id] == nil then
                        break
                    end
                    table.insert(self.actor_rewards[actor_id].ranks,{time=rewards.time,rank=rewards.actors[actor.actor_id].rank,grade_id=rewards.actors[actor.actor_id].grade_id})
                    local qualifying_day_reward_config = get_qualifying_day_reward_config(rewards.actors[actor.actor_id].grade_id,rewards.actors[actor.actor_id].rank)
                    if qualifying_day_reward_config == nil then
                        break
                    end

                    for i=1,4,1 do
                        if qualifying_day_reward_config["Reward"..i][1] ~= nil and qualifying_day_reward_config["Reward"..i][2] ~= nil then
                            if qualifying_day_reward_config["Reward"..i][1] ~= const.RESOURCE_NAME_TO_ID.arena_score then
                                local have_item = false
                                for _,item in pairs(self.actor_rewards[actor_id].items) do
                                    if item.item_id == qualifying_day_reward_config["Reward"..i][1] then
                                        item.count = item.count + qualifying_day_reward_config["Reward"..i][2]
                                        have_item = true
                                        break
                                    end
                                end
                                if have_item == false then
                                    table.insert(self.actor_rewards[actor_id].items,{item_id=qualifying_day_reward_config["Reward"..i][1],count=qualifying_day_reward_config["Reward"..i][2]})
                                end
                            else
                                self.actor_rewards[actor_id].qualifying_score = self.actor_rewards[actor_id].qualifying_score + qualifying_day_reward_config["Reward"..i][2]
                                actor.qualifying_score = actor.qualifying_score + qualifying_day_reward_config["Reward"..i][2]
                                actor.total_score = actor.total_score + qualifying_day_reward_config["Reward"..i][2]
                            end
                        end
                    end
                until(true)
            end
        end
    end

    --奖励邮件
    if table.isEmptyOrNil(self.actor_rewards) then
        return
    end
    local replace_string = common_char_chinese_config.get_back_text(2135001)

    for actor_id,actor in pairs(self.actor_rewards) do
        local rank_string = ""
        for i = 1,#actor.ranks,1 do
            rank_string = rank_string..string.format(replace_string,challenge_arena_config.get_arena_grade_name(actor.ranks[i].grade_id),actor.ranks[i].rank)
            if i ~= #actor.ranks then
                rank_string = rank_string..","
            end
        end
        mail_helper.send_mail(actor_id,const.MAIL_IDS.ARENA_DAY_REWARD,table.copy(actor.items),current_time,{rank_string,actor.qualifying_score})
    end
end

--发放周奖励
function arena_center.send_weekly_reward(self)
    local current_time = _get_now_time_second()
    self.weekly_rewards = {}
    sort_dogfigght_rank(self)
    for actor_id,actor in pairs(self.arena_actors) do
        if actor.level >= common_system_list_configs[SYSTEM_NAME_TO_ID.arena_qualifying].level then
            self.weekly_rewards[actor_id] = {}
            self.weekly_rewards[actor_id].items = {}
            self.weekly_rewards[actor_id].rank = actor.total_rank
            local arena_dogfight_reward_config = get_arena_dogfight_reward_config(actor.total_rank)
            if arena_dogfight_reward_config ~= nil then
                --发放奖励
                for i=1,4,1 do
                    if arena_dogfight_reward_config["Reward"..i][1] ~= nil and arena_dogfight_reward_config["Reward"..i][2] ~= nil then
                        table.insert(self.weekly_rewards[actor_id].items,{item_id=arena_dogfight_reward_config["Reward"..i][1],count=arena_dogfight_reward_config["Reward"..i][2]})
                    end
                end
            end
        end
    end

    --奖励邮件
    if table.isEmptyOrNil(self.weekly_rewards) then
        return
    end
    for actor_id,actor in pairs(self.weekly_rewards) do
        mail_helper.send_mail(actor_id,const.MAIL_IDS.ARENA_WEEK_REWARD,table.copy(actor.items),current_time,{actor.rank})
    end
end

function arena_center.on_notice_can_not_connect_qualifying_fight_server(self,input)
    self:cancel_qualifying_challenge(input)
end

function arena_center.player_union_name_change(self,input)
    if input.members == nil then
        return
    end
    for actor_id,_ in pairs(input.members) do
        if self.arena_actors[actor_id] ~= nil then
            self.arena_actors[actor_id].union_name = input.union_name
        end
    end
end

function arena_center.on_server_stop(self)
    self.is_prepare_close = true
    sort_dogfigght_rank(self)
    save_data(self)
end

function arena_center.on_arena_player_game_id_change(self,input)
    flog("tmlDebug","imp_global_player.on_friend_player_game_id_change")
    self.src_game_id = input.actor_game_id
end

arena_center.on_player_session_changed = require("helper/global_common").on_player_session_changed

register_function_on_start(init)

return arena_center

