--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/20 0020
-- Time: 17:24
-- To change this template use File | Settings | File Templates.
--

local challenge_arena = require "data/challenge_arena"
local common_char_chinese_config = require "configs/common_char_chinese_config"
local common_fight_base_config = require "configs/common_fight_base_config"
local parameter = challenge_arena.Parameter
local flog = require "basic/log"
local const = require "Common/constant"
local math = require "math"

--检查出生点
for id,v in pairs(challenge_arena.ArenaScene) do
    local find = false
    for _,v1 in pairs(challenge_arena[v.SceneSetting]) do
        if v1.Type == const.ENTITY_TYPE_BIRTHDAY_POS then
            find = true
            break
        end
    end
    if find == false then
        flog("error","can not find birth position in arena,id "..id)
    end
end

local first_arena_grade_id = 0
local arena_grade_configs = {}
for _,v in pairs(challenge_arena.QualifyingGrade) do
    arena_grade_configs[v.ID] = v
    if v.NextGrade == 0 then
        first_arena_grade_id = v.ID
    end
end

local function get_arena_grade_config(grade_id)
    return arena_grade_configs[grade_id]
end

local function get_arena_grade_name(grade_id)
    local grade_config = arena_grade_configs[grade_id]
    if grade_config == nil then
        return ""
    end
    if grade_config.SubGrade > 0 then
        return common_char_chinese_config.get_table_text(grade_config.SubGrade)
    end
    return grade_config.SubGrade1
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

local function get_qualifying_send_reward_time(current_date)
    return os.time({day=current_date.day, month=current_date.month, year=current_date.year, hour=parameter[9].Value[1], min=parameter[9].Value[2], sec=0})
end

local function get_arena_weekly_reward_weekday()
    return parameter[30].Value[1]
end

local function get_arena_weekly_reward_time(current_date)
    return os.time({day=current_date.day, month=current_date.month, year=current_date.year, hour=parameter[30].Value[2], min=parameter[30].Value[3], sec=0})
end

local function is_reset_score_time(current_date)
    if current_date.wday == parameter[31].Value[1] and current_date.hour == parameter[31].Value[2] and current_date.min == parameter[31].Value[3] then
        return true
    end
    return false
end

local arena_dogfight_min_player_count = 10000000
--混战赛匹配表
local arena_dogfight_matching_configs = {}
local arena_dogfight_matching_create_time = {}
for _,v in pairs(challenge_arena.Matching2) do
    arena_dogfight_matching_configs[v.CreateTime] = v
    table.insert(arena_dogfight_matching_create_time,v.CreateTime)
    if arena_dogfight_min_player_count > v.PlayerNum then
        arena_dogfight_min_player_count = v.PlayerNum
    end
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

local function get_arena_dogfight_min_player_count()
    return challenge_arena.Parameter[8].Value[1]
end

local grade_keeper_configs = {}
for _,v in pairs(challenge_arena.GradeKeeper) do
    grade_keeper_configs[v.GradeID] = v
end

local function get_keeper_config(id)
    return grade_keeper_configs[id]
end

local monsters = {}
for _,v in pairs(challenge_arena.MonsterSetting) do
    monsters[v.ID] = v
end

local function get_qualifying_arena_fight_ready_time()
    return challenge_arena.Parameter[6].Value[1]/1000
end


local function get_total_arena_scene_setting()
    return challenge_arena
end

local function get_qualifying_arena_duration()
    return challenge_arena.Parameter[7].Value[1]/1000
end

local function get_dogfight_arena_fight_ready_time()
    return math.floor(challenge_arena.Parameter[20].Value[1]/1000)
end

local function get_dogfight_arena_duration()
    return math.floor(challenge_arena.Parameter[21].Value[1]/1000)
end

--占领获得的积分
local function get_occupy_score(grade_id)
    local grade_config = get_arena_grade_config(grade_id)
    if grade_config == nil or grade_config.Reward15 == nil or grade_config.Reward15[2] == nil then
        return 0
    end
    return grade_config.Reward15[2]
end

--获得占领积分时间间隔
local function get_occupy_score_interval()
    return challenge_arena.Parameter[42].Value[1]
end

local arena_plunder_score_configs = {}
for _,v in pairs(challenge_arena.MeleeLoot) do
    arena_plunder_score_configs[v.Deathlowerlimit] = v
end

local function get_arena_plunder_score_config(die_count)
    local arena_plunder_score_config = nil
    for _,v in pairs(arena_plunder_score_configs) do
        if die_count >= v.Deathlowerlimit and (arena_plunder_score_config == nil or v.Deathlowerlimit > arena_plunder_score_config.Deathlowerlimit) then
            arena_plunder_score_config = v
        end
    end
    return arena_plunder_score_config
end

--混战赛等待时间
local function get_dogfight_wait_time()
    return challenge_arena.Parameter[18].Value[1]
end

--日奖励时间1
local function get_daily_reward_score_time1()
    return challenge_arena.Parameter[10].Value
end

--日奖励时间2
local function get_daily_reward_score_time2()
    return challenge_arena.Parameter[11].Value
end

--日奖励时间3
local function get_daily_reward_score_time3()
    return challenge_arena.Parameter[5].Value
end

--日奖励发放时间
local function get_daily_reward_time()
    return challenge_arena.Parameter[9].Value
end

--周积分清空时间
local function get_weekly_score_reset_time()
    return challenge_arena.Parameter[31].Value
end

--周奖励发放时间
local function get_weekly_reward_time()
    return challenge_arena.Parameter[30].Value
end

return{
    get_arena_grade_config = get_arena_grade_config,
    get_qualifying_day_reward_config = get_qualifying_day_reward_config,
    get_arena_grade_name = get_arena_grade_name,
    get_qualifying_send_reward_time = get_qualifying_send_reward_time,
    get_arena_weekly_reward_weekday = get_arena_weekly_reward_weekday,
    get_arena_weekly_reward_time = get_arena_weekly_reward_time,
    is_reset_score_time = is_reset_score_time,
    get_arena_dogfight_min_player_count = get_arena_dogfight_min_player_count,
    get_keeper_config = get_keeper_config,
    get_qualifying_arena_fight_ready_time = get_qualifying_arena_fight_ready_time,
    get_total_arena_scene_setting = get_total_arena_scene_setting,
    get_qualifying_arena_duration = get_qualifying_arena_duration,
    get_dogfight_arena_duration = get_dogfight_arena_duration,
    get_dogfight_arena_fight_ready_time = get_dogfight_arena_fight_ready_time,
    get_occupy_score = get_occupy_score,
    get_occupy_score_interval = get_occupy_score_interval,
    get_arena_plunder_score_config = get_arena_plunder_score_config,
    get_dogfight_wait_time = get_dogfight_wait_time,
    get_daily_reward_score_time1 = get_daily_reward_score_time1,
    get_daily_reward_score_time2 = get_daily_reward_score_time2,
    get_daily_reward_score_time3 = get_daily_reward_score_time3,
    get_daily_reward_time = get_daily_reward_time,
    get_weekly_score_reset_time = get_weekly_score_reset_time,
    get_weekly_reward_time = get_weekly_reward_time,
}

