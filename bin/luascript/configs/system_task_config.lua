--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/2 0002
-- Time: 13:48
-- To change this template use File | Settings | File Templates.
--

local system_task = require "data/system_task"
local flog = require "basic/log"
local const = require "Common/constant"
local pairs = pairs
local table = table
local math = math

local tasks = {}
local next_branch_tasks = {}
local next_main_task = {}
local branch_group = {}
local daily_cycle_first_task = {}
local daily_cycle_next_task = {}
local country_tasks = {}
local task_dungeons = {}
local country_task_exp_reward = {}

local function get_first_branch_task(tid)
    local task_config = tasks[tid]
    if task_config ~= nil then
        if task_config.TaskSort == const.TASK_SORT.main then
            flog("error","can not find task config,id "..tid)
        end
        if task_config.PrepositionTask == 0 then
            return tid
        end
        local pre_task = tasks[task_config.PrepositionTask]
        if pre_task == nil then
            flog("error","can not find task config,id "..tid)
        elseif pre_task.TaskSort == const.TASK_SORT.main then
            return tid
        elseif pre_task.TaskSort == const.TASK_SORT.branch then
            return get_first_branch_task(task_config.PrepositionTask)
        else
            flog("error","pre_task task is not main or branch task,id "..task_config.PrepositionTask)
        end
    else
        flog("error","can not find task config,id "..tid)
    end
    return tid
end



local function get_task_config(tid)
    return tasks[tid]
end

local function get_next_branch_task(group,tid)
    if next_branch_tasks[group] ~= nil then
        return next_branch_tasks[group][tid]
    end
    return nil
end

local function get_next_main_task(tid)
    return next_main_task[tid]
end

local function get_first_main_task_id(country)
    if country == const.COUNTRY_ID.jiuli then
        return system_task.Parameter[2].Value
    end
    return system_task.Parameter[1].Value
end

--获取上一个非废弃任务
local function get_preposition_task(tid)
    local task_config = get_task_config(tid)
    if task_config ~= nil then
        if task_config.AbandonSign == 0 then
            return tid
        else
            return get_preposition_task(task_config.PrepositionTask)
        end
    end
    return 0
end

local function get_branch_groups()
    return branch_group
end

local function get_task_dungeon_config(id)
    return task_dungeons[id]
end

local function get_task_dungeon_scene_setting(id)
    local dungeon_config = get_task_dungeon_config(id)
    if dungeon_config == nil then
        return nil
    end
    return system_task[dungeon_config.SceneSetting]
end

local function get_task_dungeon_table(id)
    return system_task
end

local function get_task_dungeon_total_time(id)
    local dungeon_config = get_task_dungeon_config(id)
    if dungeon_config == nil then
        return 0
    end
    return dungeon_config.Time
end

local function get_daily_cycle_task_first(country)
    if daily_cycle_first_task[country] == nil then
        return nil
    end
    if #daily_cycle_first_task[country] == 0 then
        return nil
    end
    return daily_cycle_first_task[country][math.random(#daily_cycle_first_task[country])]
end

local function get_next_daily_cycle_task(id)
    return daily_cycle_next_task[id]
end

local function get_daily_cycle_task_count()
    return system_task.Parameter[4].Value
end

local function get_daily_cycle_task_player_count()
    return system_task.Parameter[6].Value
end

local function get_daily_cycle_task_level()
    return system_task.Parameter[5].Value
end

local function get_group_first_task_id(group_id)
    return branch_group[group_id].first_task_id
end

local function get_country_task(country,level)
    local level_tasks = {}
    for _,task in pairs(country_tasks[country]) do
        if task.LevelLimit <= level then
            table.insert(level_tasks,task.TaskID)
        end
    end

    local count = #level_tasks
    if count == 0 then
        return nil
    end

    return level_tasks[math.random(count)]
end

local function get_country_task_max_count()
    return system_task.Parameter[8].Value
end

local function get_country_task_max_turn()
    return system_task.Parameter[7].Value
end

local function get_country_task_exp_reward(times)
    return country_task_exp_reward[times]
end

local function reload()
    tasks = {}
    next_branch_tasks = {}
    next_main_task = {}
    branch_group = {}
    daily_cycle_first_task = {}
    daily_cycle_next_task = {}
    country_tasks = {}
    task_dungeons = {}
    country_tasks[const.COUNTRY_ID.jiuli] = {}
    country_tasks[const.COUNTRY_ID.yanhuang] = {}

    for _,v in pairs(system_task.MainTask1) do
        if tasks[v.TaskID] ~= nil then
            flog("error","task id is repeat!!!id "..v.TaskID)
        end
        tasks[v.TaskID] = v
        if v.TaskSort == const.TASK_SORT.main and v.PrepositionTask > 0 and v.AbandonSign == 0 then
            next_main_task[v.PrepositionTask] = v.TaskID
        end
    end

    for _,v in pairs(system_task.MainTask2) do
        if tasks[v.TaskID] ~= nil then
            flog("error","task id is repeat!!!id "..v.TaskID)
        end
        tasks[v.TaskID] = v
        if v.TaskSort == const.TASK_SORT.main and v.PrepositionTask > 0 and v.AbandonSign == 0 then
            next_main_task[v.PrepositionTask] = v.TaskID
        end
    end

    for _,v in pairs(system_task.OtherTask) do
        if tasks[v.TaskID] ~= nil then
            flog("error","task id is repeat!!!id "..v.TaskID)
        end
        tasks[v.TaskID] = v
        if v.TaskSort == const.TASK_SORT.branch and v.AbandonSign == 0 then
            if branch_group[v.TaskGroup] == nil then
                branch_group[v.TaskGroup] = {}
                branch_group[v.TaskGroup].first_task_id = v.TaskID
            end
            if v.PrepositionTask > 0 then
                if next_branch_tasks[v.TaskGroup] == nil then
                    next_branch_tasks[v.TaskGroup] = {}
                end
                next_branch_tasks[v.TaskGroup][v.PrepositionTask] = v.TaskID
            end
        elseif v.TaskSort == const.TASK_SORT.daily_cycle and v.AbandonSign == 0 then
            if daily_cycle_first_task[v.Camp] == nil then
                daily_cycle_first_task[v.Camp] = {}
            end
            if v.PrepositionTask == 0 then
                table.insert(daily_cycle_first_task[v.Camp],v.TaskID)
            else
                daily_cycle_next_task[v.PrepositionTask] = v.TaskID
            end
        end
    end

    --阵营任务
    for _,v in pairs(system_task.CampTask) do
        if tasks[v.TaskID] ~= nil then
            flog("error","task id is repeat!!!id "..v.TaskID)
        end
        tasks[v.TaskID] = v
        if v.TaskSort == const.TASK_SORT.country and v.AbandonSign == 0 then
            table.insert(country_tasks[v.Camp],v)
        end
    end

    --支线任务首个任务
    for _,group in pairs(branch_group) do
        group.first_task_id = get_first_branch_task(group.first_task_id)
    end
    --环副本
    task_dungeons = {}
    for _,v in pairs(system_task.MainTaskTranscript) do
        task_dungeons[v.ID] = v
    end

    --阵营任务经验奖励倍数
    country_task_exp_reward = {}
    for _,v in pairs(system_task.CampExpReward) do
        country_task_exp_reward[v.Num] = v
    end
end

reload()

return {
    reload = reload,
    get_task_config = get_task_config,
    get_next_branch_task = get_next_branch_task,
    get_next_main_task = get_next_main_task,
    get_first_main_task_id = get_first_main_task_id,
    get_preposition_task = get_preposition_task,
    get_branch_groups = get_branch_groups,
    get_task_dungeon_config = get_task_dungeon_config,
    get_task_dungeon_scene_setting = get_task_dungeon_scene_setting,
    get_task_dungeon_table = get_task_dungeon_table,
    get_task_dungeon_total_time=get_task_dungeon_total_time,
    get_daily_cycle_task_count = get_daily_cycle_task_count,
    get_daily_cycle_task_player_count = get_daily_cycle_task_player_count,
    get_daily_cycle_task_level = get_daily_cycle_task_level,
    get_daily_cycle_task_first = get_daily_cycle_task_first,
    get_next_daily_cycle_task = get_next_daily_cycle_task,
    get_group_first_task_id = get_group_first_task_id,
    get_country_task = get_country_task,
    get_country_task_exp_reward = get_country_task_exp_reward,
    get_country_task_max_count = get_country_task_max_count,
    get_country_task_max_turn = get_country_task_max_turn,
}