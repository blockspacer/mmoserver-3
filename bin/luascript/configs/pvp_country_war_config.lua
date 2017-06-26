--------------------------------------------------------------------
-- 文件名:	pvp_country_war_config.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/5/9 0009
-- 描  述:	pvp大攻防配置文件
--------------------------------------------------------------------
local pvp_country_war_scheme = require "data/pvp_country_war"
local recreate_scheme_table_with_key = require("basic/scheme").recreate_scheme_table_with_key
local npc_level_scheme_original = pvp_country_war_scheme.NpcLevel
local npc_level_scheme
local flog = require "basic/log"
local battle_score_original = pvp_country_war_scheme.ScoreReward
local battle_score_scheme = {}
local scheme_param = pvp_country_war_scheme.Parameter
local scheme_fun = require "basic/scheme"
local get_open_day = scheme_fun.get_open_day
local table = table
local const = require "Common/constant"
local math = math

local winner_necessary_rate
local transport_fleet_refresh_number
local country_boss_leader_buff_id
local activity_week_day
local open_time_in_day
local dispatch_fleet_time
local open_after_open_day
local country_war_task = {}
local country_war_task_monster = {}
local country_war_task_refresh_cost = {}
local npc_tasks = {}

local function country_war_task_sort(a,b)
    return a.mark > b.mark
end

local function country_war_task_refresh_sort(a,b)
    return a.Number < b.Number
end

local function get_modify_level(monster_type)
    local level_config = npc_level_scheme[monster_type]
    if level_config == nil then
        flog("error", "get_modify_level error monster_type "..tostring(monster_type))
    end
    return level_config.level
end

local function get_battle_score(type, goal_type, monster_type)
    local score_data
    if monster_type == nil then
        score_data = battle_score_scheme[type][goal_type]
    else
        score_data = battle_score_scheme[type][goal_type][monster_type]
    end
    return score_data.country, score_data.player
end

local function get_loser_buff_id(lose_times)
    if lose_times <= 0 then
        return
    end

    local boss_buff_scheme = pvp_country_war_scheme.BossBuff
    local index = #boss_buff_scheme
    for i, v in ipairs(boss_buff_scheme) do
        if v.LostNumLimit > lose_times then
            index = i - 1
            break
        end
    end
    if boss_buff_scheme[index] == nil then
        flog("error", "get_loser_buff_id fail! "..tostring(lose_times))
        return
    end
    return boss_buff_scheme[index].buffID
end

local function is_country_war_time(current_time)
    local current_date = os.date("*t", current_time)
    local week_day = current_date.wday

    if activity_week_day[week_day] then
        local daily_time = current_date.hour * 3600 + current_date.min * 60 + current_date.sec
        if daily_time > open_time_in_day.start_time and daily_time < open_time_in_day.end_time then
            local open_day = get_open_day()
            if open_day > open_after_open_day then
                return true
            end
        end
    end
    return false
end


-- 半小时前发通知
local function is_time_send_notice(current_time)
    local current_date = os.date("*t", current_time)
    local week_day = current_date.wday

    if activity_week_day[week_day] then
        local daily_time = current_date.hour * 3600 + current_date.min * 60 + current_date.sec
        if daily_time < open_time_in_day.start_time and daily_time > open_time_in_day.start_time - 1800 then
            return true
        end
    end
    return false
end

local function is_dispatch_fleet_time(current_time)
    if not is_country_war_time(current_time) then
        return false
    end

    local current_date = os.date("*t", current_time)
    local key = string.format("%d:%d", current_date.hour, current_date.min)
    if dispatch_fleet_time[key] then
        return true
    end
    return false
end

--第一次产生系列任务
local function refresh_country_war_task(country)
    local results = {}
    for num,tasks in pairs(country_war_task[country]) do
        if tasks[1].mark == 1 then
            results[num] = tasks[1].ID
            table.insert(results,tasks[1].ID)
        else
            results[num] = tasks[math.random(#tasks)].ID
        end
    end
    return results
end

--玩家产生任务
local function refresh_country_war_task_by_num(country,num,current_id)
    if #country_war_task[country][num] == 0 then
        return nil
    elseif #country_war_task[country][num] == 1 then
        return country_war_task[country][num][1]
    else
        local random_index = math.random(#country_war_task[country][num] - 1)
        local index = 0
        for _,task in pairs(country_war_task[country][num]) do
            if task.ID ~= current_id then
                index = index + 1
                if index == random_index then
                    return task.ID
                end
            end
        end
    end
    return nil
end

local function get_country_war_task(id)
    return pvp_country_war_scheme.Task[id]
end

local function check_country_war_task_monster(scene_id,element_id)
    if country_war_task_monster[scene_id] ~= nil and country_war_task_monster[scene_id][element_id] ~= nil then
        return true
    end
    return false
end

local function get_country_war_task_refresh_cost(times)
    flog("tmlDebug","get_country_war_task_refresh_cost "..table.serialize(country_war_task_refresh_cost))
    for i=#country_war_task_refresh_cost,1,-1 do
        if country_war_task_refresh_cost[i].Number <= times then
            return country_war_task_refresh_cost[i].Cost
        end
    end
    return nil
end

local function get_npc_task(id)
    return npc_tasks[id]
end

local function get_npc_tasks()
    return npc_tasks
end

local function reload()
    npc_level_scheme = recreate_scheme_table_with_key(npc_level_scheme_original, "Type")

    for i, v in ipairs(battle_score_original) do
        local data = {country = v.CampScore, player = v.BattleScore }
        local type, goal_type
        if v.Type == 1 then
            type = "kill"
        elseif v.Type == 2 then
            type = "assist"
        elseif v.Type == 3 then
            type = "supply"
        else
            flog("error", "battle_score_original wrong Type "..tostring(v.Type))
        end
        battle_score_scheme[type] = battle_score_scheme[type] or {}

        local orginal_goal = v.Goal[1]
        local monster_type = v.Goal[2]
        if orginal_goal == 1 then
            goal_type = "player"
        elseif orginal_goal == 2 then
            goal_type = "transporter"
        elseif orginal_goal == 23 then
            goal_type = "country_monster"
            if monster_type == nil then
                flog("error", "battle_score_original no monster type "..tostring(i))
            end
        elseif orginal_goal == nil then
            goal_type = "default"
        else
            flog("error", "battle_score_original wrong Goal "..tostring(orginal_goal))
        end

        if monster_type ~= nil then
            battle_score_scheme[type][goal_type] = battle_score_scheme[type][goal_type] or {}
            battle_score_scheme[type][goal_type][monster_type] = data
        else
            battle_score_scheme[type][goal_type] = data
        end
    end

    winner_necessary_rate = scheme_param[2].Value[1]
    transport_fleet_refresh_number = scheme_param[9].Value[1]
    country_boss_leader_buff_id = scheme_param[11].Value[1]

    local activity_week_day_scheme = scheme_param[4].Value
    activity_week_day = {}
    for _, v in pairs(activity_week_day_scheme) do
        v = v % 7 + 1           --换成lua星期格式，1为周日
        activity_week_day[v] = true
    end

    open_time_in_day = {}
    local open_time_in_day_scheme = scheme_param[5].Value
    local start_hour = open_time_in_day_scheme[1]
    local start_min = open_time_in_day_scheme[2]
    open_time_in_day.start_time = start_hour * 3600 + start_min * 60
    local end_hour = open_time_in_day_scheme[3]
    local end_min = open_time_in_day_scheme[4]
    open_time_in_day.end_time = end_hour * 3600 + end_min * 60

    dispatch_fleet_time = {}
    local dispatch_fleet_time_scheme = scheme_param[8].Value
    local length = #dispatch_fleet_time_scheme
    for i = 1, length, 2 do
        local hour = dispatch_fleet_time_scheme[i]
        local min = dispatch_fleet_time_scheme[i + 1]
        local key = string.format("%d:%d", hour, min)
        dispatch_fleet_time[key] = true
    end

    open_after_open_day = scheme_param[7].Value[1]

    --攻防任务
    country_war_task = {}
    country_war_task[const.COUNTRY_ID.jiuli] = {}
    country_war_task[const.COUNTRY_ID.yanhuang] = {}
    for _,v in pairs(pvp_country_war_scheme.Task) do
        if v.Camp == 0 then
            if country_war_task[const.COUNTRY_ID.jiuli][v.TaskNum] == nil then
                country_war_task[const.COUNTRY_ID.jiuli][v.TaskNum] = {}
            end
            table.insert(country_war_task[const.COUNTRY_ID.jiuli][v.TaskNum],v)
            if country_war_task[const.COUNTRY_ID.yanhuang][v.TaskNum] == nil then
                country_war_task[const.COUNTRY_ID.yanhuang][v.TaskNum] = {}
            end
            table.insert(country_war_task[const.COUNTRY_ID.yanhuang][v.TaskNum],v)
        else
            if country_war_task[v.Camp][v.TaskNum] == nil then
                country_war_task[v.Camp][v.TaskNum] = {}
            end
            table.insert(country_war_task[v.Camp][v.TaskNum],v)
        end
        if v.LogicID == const.COUNTRY_WAR_TASK_LOGIC_ID.attack_monster then
            if country_war_task_monster[v.para1] == nil then
                country_war_task_monster[v.para1] = {}
            end
            if country_war_task_monster[v.para1][v.para2] == nil then
                country_war_task_monster[v.para1][v.para2] = 1
            end
        end
    end
    for _,camp in pairs(country_war_task) do
        for _,tasks in pairs(camp) do
            if #tasks > 1 then
                table.sort(tasks,country_war_task_sort)
            end
        end
    end

    --刷新任务消耗
    country_war_task_refresh_cost = {}
    for _,v in pairs(pvp_country_war_scheme.TaskRefresh) do
        table.insert(country_war_task_refresh_cost,v)
    end
    if #country_war_task_refresh_cost > 1 then
        table.sort(country_war_task_refresh_cost,country_war_task_refresh_sort)
    end

    --阵营npc任务
    npc_tasks = {}
    for _,v in pairs(pvp_country_war_scheme.CampNpcTask) do
        npc_tasks[v.ID] = v
    end
end
reload()

return {
    get_modify_level = get_modify_level,
    get_battle_score = get_battle_score,
    reload = reload,
    winner_necessary_rate = winner_necessary_rate,
    transport_fleet_refresh_number = transport_fleet_refresh_number,
    country_boss_leader_buff_id = country_boss_leader_buff_id,
    get_loser_buff_id = get_loser_buff_id,
    is_country_war_time = is_country_war_time,
    is_dispatch_fleet_time = is_dispatch_fleet_time,
    battle_rank_reward = pvp_country_war_scheme.RankingReward,
    is_time_send_notice = is_time_send_notice,
    refresh_country_war_task =  refresh_country_war_task,
    refresh_country_war_task_by_num = refresh_country_war_task_by_num,
    get_country_war_task = get_country_war_task,
    check_country_war_task_monster = check_country_war_task_monster,
    get_country_war_task_refresh_cost = get_country_war_task_refresh_cost,
    get_npc_task = get_npc_task,
    get_npc_tasks = get_npc_tasks,
}