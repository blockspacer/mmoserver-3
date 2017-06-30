--------------------------------------------------------------------
-- 文件名:	imp_dungeon.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/09
-- 描  述:	副本模块
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local normal_tran_script = require("data/challenge_main_dungeon").NormalTranscript
local daily_refresher = require("helper/daily_refresher")
local daily_normal_max_time = require("data/challenge_main_dungeon").Parameter[1].Value[1]       --普通副本每天最大次数
local tili_consume_of_normal = require("data/challenge_main_dungeon").Parameter[2].Value[1]       --普通副本消耗体力
local transcript_mark = require("data/challenge_main_dungeon").TranscriptMark
local chapter_scheme = require("data/challenge_main_dungeon").Chapter
local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"
--local team_follow = require "helper/team_follow"
local challenge_main_dungeon_config = require "configs/challenge_main_dungeon_config"
local math = require "math"
local scene_func = require "scene/scene_func"
local get_fight_server_info = require("basic/common_function").get_fight_server_info
local send_message_to_fight = require("basic/net").send_message_to_fight
local system_task_config = require "configs/system_task_config"
local mail_helper = require "global_mail/mail_helper"


local params = {
    chapter_unlock = {db = true,sync = true, default = 1},  --章节解锁进度
    dungeon_unlock = {db = true,sync = true, default = 1},  --副本解锁进度
    dungeon_in_playing = {db = true,sync = true, default = const.DUNGEON_NOT_EXIST},--当前副本id
    daily_normal_times = {db = true,sync = true, default = daily_normal_max_time }, --每日普通副本可完成次数
    dungeon_start_time = {db = true},            --当前副本开始时间
    is_reward_enable = {db = false,sync = true, default = true},  --当前状态是否可获得奖励
}


local imp_dungeon = {}
imp_dungeon.__index = imp_dungeon

setmetatable(imp_dungeon, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_dungeon.__params = params

function imp_dungeon.__ctor(self)
    self.dungeon_refresher = nil
    self.normal_best_time = {}          --普通副本最佳通关时间
    self.chapter_reward = {}            --章节奖励领取情况
    self.chapter_mark = {}              --章节获得的S数目
    self.team_dungeon_times = {}        --组队副本次数
    self.get_hegemon_times = {}         --获得霸主榜霸主次数
end

local function on_player_login(self, input, syn_data)
    self:set_dungeon_in_playing(const.DUNGEON_NOT_EXIST)
end

local function on_start_dungeon(self, input, syn_data)
    flog("syzDebug", "CreateImpDungeon.start_dungeon")
    self:start_dungeon(input.dungeon_id)

end

local function on_end_dungeon(self, input, syn_data)
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_leave_main_dungeon"})
end

local function on_quit_dungeon(self, input, syn_data)
    self:quit_dungeon(input.dungeon_id)
end

local function _refresh_data(self)
    flog("syzDebug", "imp_dungeon  _refresh_data")
    self.daily_normal_times = daily_normal_max_time
    self.team_dungeon_times = {}
    self.get_hegemon_times = {}
end

local function _calc_dungeon_star(time, total_time)
    if total_time < time or time < 0 or total_time == 0 then
        return -1
    end

    local last_time_rate = math.floor((total_time - time) * 100 / total_time)  --剩余时间百分比
    local reward_index
    for i, v in ipairs(transcript_mark) do
        if last_time_rate >= v.RestTime then
            reward_index = i
            break
        end
    end
    if reward_index == nil then
        flog("error", "reward_index should not be nil")
    end
    return reward_index
end

local function on_chapter_reward(self, input, syn_data)
    local chapter_id = input.chapter
    local rank = input.rank

    if self.chapter_mark[chapter_id] == nil then
        self:send_message(const.SC_MESSAGE_LUA_CHAPTER_REWARD, {result = const.error_chapter_reward_not_available})
        return
    end
    local total_s = 0
    for _, cnt in pairs(self.chapter_mark[chapter_id]) do
        total_s = total_s + cnt
    end

    self.chapter_reward[chapter_id] = self.chapter_reward[chapter_id] or {}
    if self.chapter_reward[chapter_id][rank] then
        self:send_message(const.SC_MESSAGE_LUA_CHAPTER_REWARD, {result = const.error_chapter_reward_already_get})
    else
        local reward_scheme = chapter_scheme[chapter_id]["Rewar"..rank]
        local rewards = {}
        for i = 1, #reward_scheme - 1 , 2 do
            rewards[reward_scheme[i]] = reward_scheme[i + 1]
        end

        self:send_message(const.SC_MESSAGE_LUA_CHAPTER_REWARD, {result = 0, reward = rewards})
        self.chapter_reward[chapter_id][rank] = true
        self:add_new_rewards(rewards)
        self:imp_assets_write_to_sync_dict(syn_data)
    end
    self:imp_dungeon_write_to_sync_dict(syn_data)
end

local function is_dungeon_enterable(self, dungeon_id)
    if self.dungeon_in_playing ~= const.DUNGEON_NOT_EXIST then
        flog("warn", "Already in dungeon！")
        return const.error_already_in_dungeon
    end

    if dungeon_id > self.dungeon_unlock then
        flog("warn", "Not unlock dungeon "..dungeon_id.." yet")
        return const.error_dungeon_not_unlock
    end

    self.dungeon_refresher:check_refresh(self)
    if self.daily_normal_times <= 0 then
        return const.error_normal_dungeon_times_use_out
    end

    if not self:is_resource_enough("tili", tili_consume_of_normal) then
        return const.error_tili_not_enough
    end

    return 0
end

local function on_dungeon_sweep(self, input, syn_data)
    local dungeon_id = input.dungeon_id
    local chapter_id = normal_tran_script[dungeon_id].Chapter

    if self.chapter_mark[chapter_id] == nil or self.chapter_mark[chapter_id][dungeon_id] ~= 3 then  --需要达到SSS才能扫荡
        self:send_message(const.SC_MESSAGE_LUA_DUNGEON_SWEEP, {result = const.error_dungeon_not_achieve_sss})
        return
    end

    local result = is_dungeon_enterable(self, dungeon_id)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_DUNGEON_SWEEP, {result = result})
    else
        self.daily_normal_times = self.daily_normal_times - 1
        self:remove_resource("tili", tili_consume_of_normal)
        local rewards = self:get_main_dungeon_win_reward(dungeon_id)
        self:send_message(const.SC_MESSAGE_LUA_DUNGEON_SWEEP, {result = 0, rewards = rewards})
        self:add_new_rewards(rewards)
        self:imp_assets_write_to_sync_dict(syn_data)
        self:imp_dungeon_write_to_sync_dict(syn_data)
    end
end

local function on_get_dungeon_hegemon(self, input, syn_data)
    input.func_name = "get_dungeon_hegemon"
    self:send_message_to_ranking_server(input)
end

local function gm_clear_dungeon_hegemon(self, input, syn_data)
    input.func_name = "clear_dungeon_hegemon"
    self:send_message_to_ranking_server(input)
end

local function _update_to_ranking(self, time, chapter_id, dungeon_id)
    local output = {func_name = "update_dungeon_hegemon"}
    output.player = {actor_id = self.actor_id, actor_name = self.actor_name, level = self.level}
    output.chapter_id = chapter_id
    output.dungeon_id = dungeon_id
    output.time = time
    self:send_message_to_ranking_server(output)
end

--根据dict初始化
function imp_dungeon.imp_dungeon_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.normal_best_time = table.get(dict, "normal_best_time", {})
    self.chapter_reward = table.get(dict, "chapter_reward", {})
    self.chapter_mark = table.get(dict, "chapter_mark", {})
    self.team_dungeon_times = table.get(dict, "team_dungeon_times", {})
    self.get_hegemon_times = table.get(dict, "get_hegemon_times", {})

    if dict.dungeon_last_refresh_time == nil then
        dict.dungeon_last_refresh_time = _get_now_time_second()
    end
    self.dungeon_refresher = daily_refresher(_refresh_data, dict.dungeon_last_refresh_time, const.REFRESH_HOUR)
    self.dungeon_refresher:check_refresh(self)
end

function imp_dungeon.imp_dungeon_init_from_other_game_dict(self,dict)
    self:imp_dungeon_init_from_dict(dict)
end

function imp_dungeon.imp_dungeon_write_to_dict(self, dict, to_other_game)
    self.dungeon_refresher:check_refresh(self)
    if to_other_game then
        for i, _ in pairs(params) do
            dict[i] = self[i]
        end
    else
        for i, v in pairs(params) do
            if v.db then
                dict[i] = self[i]
            end
        end
    end

    dict.dungeon_last_refresh_time = self.dungeon_refresher:get_last_refresh_time()
    dict.normal_best_time = self.normal_best_time
    dict.chapter_reward = self.chapter_reward
    dict.chapter_mark = self.chapter_mark
    dict.team_dungeon_times = self.team_dungeon_times
    dict.get_hegemon_times = self.get_hegemon_times
end

function imp_dungeon.imp_dungeon_write_to_other_game_dict(self,dict)
    self:imp_dungeon_write_to_dict(dict, true)
end

function imp_dungeon.imp_dungeon_write_to_sync_dict(self, dict)
    self.dungeon_refresher:check_refresh(self)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
    dict.normal_best_time = table.copy(self.normal_best_time)
    dict.chapter_reward = table.copy(self.chapter_reward)
    dict.chapter_mark = table.copy(self.chapter_mark)
    dict.team_dungeon_times = table.copy(self.team_dungeon_times)
end


local function send_main_dungeon_info_to_fight_server(self,dungeon_id,fight_server_id,ip,port,token,fight_id)
    self:set_fight_server_info(fight_server_id,ip,port,token,fight_id,const.FIGHT_SERVER_TYPE.MAIN_DUNGEON)
    local data = {}
    data.dungeon_id = dungeon_id
    data.fight_type = const.FIGHT_SERVER_TYPE.MAIN_DUNGEON
    self:send_fight_info_to_fight_server(data)
end

function imp_dungeon.start_dungeon(self, dungeon_id)
    --self.pick_items = nil
    local rst = self:is_operation_allowed("main_dungeon_start")
    if rst ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_START_DUNGEON, {result = rst})
        return false
    end
    rst = is_dungeon_enterable(self, dungeon_id)
    if rst ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_START_DUNGEON, {result = rst})
        return false
    end

    local fight_server_id,ip,port,token,fight_id = get_fight_server_info(const.FIGHT_SERVER_TYPE.MAIN_DUNGEON)
    if fight_server_id == nil then
        flog("debug","get_fight_server_info fail!!!")
        return false
    end
    send_message_to_fight(fight_server_id, const.GD_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "on_create_main_dungeon", actor_id = self.actor_id,dungeon_id=dungeon_id,fight_id=fight_id,token=token,fight_type=const.FIGHT_SERVER_TYPE.MAIN_DUNGEON})
    send_main_dungeon_info_to_fight_server(self,dungeon_id,fight_server_id,ip,port,token,fight_id)
    --self:send_message(const.SC_MESSAGE_LUA_START_DUNGEON, {result = 0})
    return true
end

function imp_dungeon.on_enter_main_dungeon_success(self,input,sync_data)
    self.in_fight_server = true
    self:fight_avatar_notice_leave_aoi_scene()
    self:set_dungeon_in_playing(input.dungeon_id)
    self.dungeon_start_time = _get_now_time_second()
    flog("syzDebug", "self.dungeon_in_playing:"..self.dungeon_in_playing)
    --重置副本复活次数
    self:reset_dungeon_rebirth_time()
    self:imp_property_write_to_sync_dict(sync_data)
    self:imp_assets_write_to_sync_dict(sync_data)
    self:imp_dungeon_write_to_sync_dict(sync_data)
end

function imp_dungeon.on_enter_task_dungeon_success(self,input,sync_data)
    self.in_fight_server = true
    self:fight_avatar_notice_leave_aoi_scene()
    self:set_dungeon_in_playing(input.dungeon_id)
    self.dungeon_start_time = _get_now_time_second()
    self:reset_dungeon_rebirth_time()
end

function imp_dungeon.on_quit_task_dungeon(self,input)
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_quit_task_dungeon"})
end

local function is_result_legal(self, dungeon_id, result)
    if self.dungeon_in_playing ~= dungeon_id then
        flog("warn", "is_result_legal: Not in dungeon "..dungeon_id.."  in "..self.dungeon_in_playing)
        return const.error_dungeon_not_match
    end

    if dungeon_id > self.dungeon_unlock then
        flog("warn", "Not unlock dungeon "..dungeon_id.." yet")
        return const.warn_dungeon_not_unlock
    end

    return 0
end

function imp_dungeon.end_dungeon(self, dungeon_id, win,cost_time,wave,mark)
    local rst = is_result_legal(self, dungeon_id, win)
    if rst ~= 0  then
        self:send_message(const.SC_MESSAGE_LUA_END_DUNGEON, {result = rst})
        return
    end
    --local pick_items = self.pick_items
    --self.pick_items = nil
    flog("salog", string.format("Main dungeon end %d, is win:%s", dungeon_id, tostring(win)), self.actor_id)
    if win == true then
        self:remove_resource("tili", tili_consume_of_normal)
        self.daily_normal_times = self.daily_normal_times - 1
        local delta_time = cost_time
        local chapter_id = normal_tran_script[dungeon_id].Chapter
        local s_count = 4 - mark            --计算获得了多少个S
        if s_count < 0 then
            s_count = 0
        end
        self:add_resource("dungeon_score", transcript_mark[mark].RewardPoints)

        if self.dungeon_unlock == dungeon_id then       --第一次通关
            self.dungeon_unlock = self.dungeon_unlock + 1
            self.chapter_unlock = normal_tran_script[self.dungeon_unlock].Chapter
        
            self.chapter_mark[chapter_id] = self.chapter_mark[chapter_id] or {}
            self.chapter_mark[chapter_id][dungeon_id] = s_count
            flog("salog", string.format("Main dungeon unlock %d", self.dungeon_unlock), self.actor_id)
        end
        self.normal_best_time[dungeon_id] = self.normal_best_time[dungeon_id] or delta_time

        if delta_time > 0 and delta_time < self.normal_best_time[dungeon_id] then
            self.normal_best_time[dungeon_id] = delta_time
            self.chapter_mark[chapter_id][dungeon_id] = s_count
        end

        local rewards = self:get_main_dungeon_win_reward(dungeon_id)
        --[[local drop = pick_items or {}
        for id, count in pairs(drop) do
            if rewards[id] == nil then
                rewards[id] = count
            else
                rewards[id] = rewards[id] + count
            end
        end]]

        local result = {result = 0, win = true, rewards = rewards, mark = mark,cost_time=cost_time,wave=wave}
        --self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards)
        self:send_message(const.SC_MESSAGE_LUA_END_DUNGEON, result)
        self:add_new_rewards(rewards)
        _update_to_ranking(self, delta_time, chapter_id, dungeon_id)
        self:update_task_dungeon(const.TASK_TYPE.main_dungeon,dungeon_id)
    else
        self:send_message(const.SC_MESSAGE_LUA_END_DUNGEON, {result = 0, win = false,mark = mark,cost_time=cost_time,wave=wave})
    end
    self:set_dungeon_in_playing(const.DUNGEON_NOT_EXIST)
    if self.is_offline then
        on_end_dungeon({})
    end
end

function imp_dungeon.quit_dungeon(self, dungeon_id)
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_leave_main_dungeon",quit=true})
end

function imp_dungeon.on_fight_avatar_leave_main_dungeon(self,input,sync_data)
    self:set_dungeon_in_playing(const.DUNGEON_NOT_EXIST)
    self:send_message(const.SC_MESSAGE_LUA_QUIT_DUNGEON, {result = 0})
end

function imp_dungeon.end_main_dungeon(self,input,sync_data)
    self:end_dungeon(input.dungeon_id, input.win,input.cost_time,input.wave,input.mark)
    self:imp_assets_write_to_sync_dict(sync_data)
    self:imp_dungeon_write_to_sync_dict(sync_data)
end

local function end_task_dungeon(self,dungeon_id,win,cost_time,wave,mark)
    local rst = 0
    flog("salog", string.format("task dungeon end %d, is win:%s", dungeon_id, tostring(win)), self.actor_id)
    if win == true then
        local result = {func_name="TaskDungeonEndRet",result = 0, win = true, rewards = {}, mark = mark,cost_time=cost_time,wave=wave}
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, result)
        self:update_task_dungeon(const.TASK_TYPE.task_dungeon,dungeon_id)
    else
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name="TaskDungeonEndRet",result = 0, win = false, mark = mark,cost_time=cost_time,wave=wave})
    end
    self:set_dungeon_in_playing(const.DUNGEON_NOT_EXIST)
    if self.is_offline then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_leave_task_dungeon"})
    end
end

function imp_dungeon.on_end_task_dungeon(self,input,sync_data)
    end_task_dungeon(self,input.dungeon_id, input.win,input.cost_time,input.wave,input.mark)
end


function imp_dungeon.on_team_dungeon_start(self, input)
    --team_follow.remove_team_follower(self:get_team_captain(), self)

    input.team_id = self.team_id
    input.fight_type = const.FIGHT_SERVER_TYPE.TEAM_DUNGEON
    self:set_fight_server_info(input.fight_server_id,input.ip,input.port,input.token,input.fight_id,const.FIGHT_SERVER_TYPE.TEAM_DUNGEON)
    self:send_fight_info_to_fight_server(input)
end

function imp_dungeon.on_enter_team_dungeon_success(self, input)
    self.in_fight_server = true
    self:fight_avatar_notice_leave_aoi_scene()
    local dungeon_id = input.dungeon_id
    self:set_dungeon_in_playing(dungeon_id)
    self:reset_dungeon_rebirth_time()
end

function imp_dungeon.on_quit_team_dungeon(self,input)
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_quit_team_dungeon"})
end

function imp_dungeon.enable_get_reward(self, dungeon_id)
    local dungeon_type = self:get_dungeon_type(dungeon_id)
    if dungeon_type == "no_dungeon" or dungeon_type == "main_dungeon" then
        self.is_reward_enable = true
    elseif dungeon_type == "team_dungeon" then
        local chapter_id = challenge_team_dungeon_config.get_chapter_id(dungeon_id)
        local times = self.team_dungeon_times[chapter_id] or 0
        local no_reward_times = challenge_team_dungeon_config.get_dungeon_no_reward_times(dungeon_id)
        if times >= no_reward_times then
            self.is_reward_enable = false
        else
            self.is_reward_enable = true
        end
    else
        dungeon_id = dungeon_id or "nil"
        flog("error", "imp_dungeon.enable_get_reward error dungeon_id "..dungeon_id)
        return false
    end

    return self.is_reward_enable
end

function imp_dungeon.on_team_dungeon_end(self, input, syn_data)
    --[[if self.team_state == "follow" then
        team_follow.add_team_follower(self:get_team_captain(), self)
    end]]

    flog("info","imp_dungeon.on_team_dungeon_end dungeon_id "..input.dungeon_id)
    local dungeon_id = input.dungeon_id
    local cost_time = input.cost_time
    local win = input.win

    if self.dungeon_in_playing ~= dungeon_id then
        flog("warn", "on_team_dungeon_end: Not in dungeon "..dungeon_id.."  in "..self.dungeon_in_playing)
        return
    end
    flog("salog", string.format("Team dungeon end %d, is win:%s", dungeon_id, tostring(win)), self.actor_id)
    if win == false then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = 0,func_name = "TeamDungeonEnd",win=false,wave=input.wave,cost_time=input.cost_time,mark=input.mark})
        if self.is_offline then
            self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_leave_team_dungeon"})
        end
        return
    end
    -- 扣除次数和体力
    self:remove_resource("tili", challenge_team_dungeon_config.get_dungeon_cost(dungeon_id))
    self:finish_activity("team_dungeon")
    local chapter_id = challenge_team_dungeon_config.get_chapter_id(dungeon_id)
    self.team_dungeon_times[chapter_id] = self.team_dungeon_times[chapter_id] or 0
    self.team_dungeon_times[chapter_id] = self.team_dungeon_times[chapter_id] + 1

    --任务更新
    self:update_task_dungeon(const.TASK_TYPE.team_dungeon,dungeon_id)

    -- 获得奖励
    if not self:enable_get_reward(dungeon_id) then
        if self.is_offline then
            self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_leave_team_dungeon"})
        end
        return
    end
    self:add_resource("dungeon_score", transcript_mark[input.mark].RewardPoints2)
    local rewards = challenge_team_dungeon_config.get_dungeon_reward(dungeon_id)
    self:add_new_rewards(rewards)
    self:imp_assets_write_to_sync_dict(syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "TeamDungeonEnd", win = true, mark = input.mark, rewards = rewards,cost_time=cost_time,wave=input.wave})
    if self.is_offline then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_leave_team_dungeon"})
    end
end

local function on_logout(self, input, syn_data)
    --战斗服统一退出
    --self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, {func_name = "on_logout"})
end

function imp_dungeon.on_fight_avatar_leave_team_dungeon(self, input)
    self:set_dungeon_in_playing(const.DUNGEON_NOT_EXIST)
end

function imp_dungeon.on_leave_task_dungeon(self,input)
    self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_leave_task_dungeon"})
end

function imp_dungeon.on_fight_avatar_leave_task_dungeon(self,input)
    self:set_dungeon_in_playing(const.DUNGEON_NOT_EXIST)
end

function imp_dungeon.gm_unlock_all_dungeon(self, syn_data)
    self.dungeon_unlock = 10000
    self:imp_dungeon_write_to_sync_dict(syn_data)
end

function imp_dungeon.on_get_team_dungeon_info(self, input)
    self.dungeon_refresher:check_refresh(self)
    local output = {func_name = "GetTeamDungeonInfoRet"}
    output.team_dungeon_times = self.team_dungeon_times
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_dungeon.gm_hegemon_dispense_rewards(self)
    local output = {}
    output.func_name = "gm_hegemon_dispense_rewards"
    self:send_message_to_ranking_server(output)
end

function imp_dungeon.get_dungeon_hegemon(self, input)
    local dungeon_type = input.dungeon_type
    local dungeon_id = input.dungeon_id

    local mail_id
    local dungeon_name
    if dungeon_type == "main_dungeon" then
        mail_id = const.MAIL_IDS.MAIN_DUNGEON_HEGEMON
        dungeon_name = challenge_main_dungeon_config.get_main_dungeon_name(dungeon_id)
    elseif dungeon_type == "team_dungeon" then
        mail_id = const.MAIL_IDS.TEAM_DUNGEON_HEGEMON
        dungeon_name = challenge_team_dungeon_config.get_team_dungeon_name(dungeon_id)
    else
        flog("error", "get_dungeon_hegemon wrong dungeon_type"..tostring(dungeon_type))
    end
    self.get_hegemon_times[dungeon_id] = self.get_hegemon_times[dungeon_id] or 0
    if self.get_hegemon_times[dungeon_id] >= challenge_main_dungeon_config.max_get_hegemon_pack_times then
        mail_id = const.MAIL_IDS.NO_DUNGEON_HEGEMON_PACK
    end
    self.get_hegemon_times[dungeon_id] = self.get_hegemon_times[dungeon_id] + 1

    mail_helper.send_mail(self.actor_id, mail_id, {}, _get_now_time_second(),{dungeon_name})
end

function imp_dungeon.set_dungeon_in_playing(self,value)
    self.dungeon_in_playing = value
    --debug调试信息
    if value == const.DUNGEON_NOT_EXIST then
        flog("info","this is debug log!!!!")
        flog("info",debug.traceback())
    end
end

register_message_handler(const.CS_MESSAGE_LUA_START_DUNGEON, on_start_dungeon)
register_message_handler(const.CS_MESSAGE_LUA_END_DUNGEON, on_end_dungeon)
register_message_handler(const.CS_MESSAGE_LUA_QUIT_DUNGEON, on_quit_dungeon)
register_message_handler(const.CS_MESSAGE_LUA_LOGIN, on_player_login)
register_message_handler(const.CS_MESSAGE_LUA_CHAPTER_REWARD, on_chapter_reward)
register_message_handler(const.CS_MESSAGE_LUA_DUNGEON_SWEEP, on_dungeon_sweep)
register_message_handler(const.CS_MESSAGE_LUA_GET_DUNGEON_HEGEMON, on_get_dungeon_hegemon)
register_message_handler(const.SS_MESSAGE_LUA_USER_LOGOUT, on_logout)

imp_dungeon.__message_handler = {}
imp_dungeon.__message_handler.on_start_dungeon = on_start_dungeon
imp_dungeon.__message_handler.on_end_dungeon = on_end_dungeon
imp_dungeon.__message_handler.on_quit_dungeon = on_quit_dungeon
imp_dungeon.__message_handler.on_player_login = on_player_login
imp_dungeon.__message_handler.on_chapter_reward = on_chapter_reward
imp_dungeon.__message_handler.on_dungeon_sweep = on_dungeon_sweep
imp_dungeon.__message_handler.on_get_dungeon_hegemon = on_get_dungeon_hegemon
imp_dungeon.__message_handler.on_logout = on_logout
return imp_dungeon