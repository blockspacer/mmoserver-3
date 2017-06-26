--------------------------------------------------------------------
-- 文件名:	wild_elite_boss.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/13
-- 描  述:	野外boss怒气管理
--------------------------------------------------------------------
local recreate_scheme_table_with_key = require("basic/scheme").recreate_scheme_table_with_key
local wild_elite_boss_scheme_original = require("data/common_scene").FieldBossID
local wild_elite_boss_scheme = recreate_scheme_table_with_key(wild_elite_boss_scheme_original, "MonsterID")
local anger_change_scheme = require("data/common_scene").AngerChange
local get_server_level = require("helper/global_server_data").get_server_level
local date_to_day_second = require("basic/scheme").date_to_day_second
local create_system_message_by_id = require("basic/scheme").create_system_message_by_id


local flog = require "basic/log"
local const = require "Common/constant"
local pairs = pairs

local formula_str = require("data/common_parameter_formula").Formula[11].Formula      --boss等级生成公式
formula_str =  "return function (a, b, c) return "..formula_str.." end"          --a=基础等级，b=服务器等级，c=修正等级
local level_formula_func = loadstring(formula_str)()

local LOGIC_ID_TO_NAME = {
    [1] = "team_member",
    [2] = "hatred_country",
    [4] = "damage_count",
    [5] = "pet_skill",
    [6] = "time",
    [7] = "position",
    [8] = "hatred_number",
    [9] = "once_damage",
}

local LOGIC_NAME_TO_ID = {}
for i, v in pairs(LOGIC_ID_TO_NAME) do
    LOGIC_NAME_TO_ID[v] = i
end


local anger_change_condition = {}
for i, v in pairs(anger_change_scheme) do
    if LOGIC_ID_TO_NAME[v.LogicID] == "time" then
        local start_time_daily = date_to_day_second({hour = v.Para1[1], min = v.Para1[2], sec = 0})
        local end_time_daily = date_to_day_second({hour = v.Para2[1], min = v.Para2[2], sec = 0})
        v.start_time_daily = start_time_daily
        v.end_time_daily = end_time_daily
    elseif LOGIC_ID_TO_NAME[v.LogicID] == "position" then
        v.radius_square = v.Para2[1] * v.Para2[1]
    elseif LOGIC_ID_TO_NAME[v.LogicID] == "pet_skill" then
        v.skill_set = {}
        for _, skill_id in pairs(v.Para1) do
            v.skill_set[skill_id] = true
        end
    end
    anger_change_condition[v.LogicID] = anger_change_condition[v.LogicID] or {}
    anger_change_condition[v.LogicID][i] = v
end


local wild_elite_boss = {}
wild_elite_boss.__index = wild_elite_boss

setmetatable(wild_elite_boss, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function wild_elite_boss.__ctor(self)
    self.anger_value = 0
    self.anger_condition = {}
    self.damage_cnt = {}
    self.pet_skill_black_list = {}
end

function wild_elite_boss.get_boss_level(monster_id)
    local config = wild_elite_boss_scheme[monster_id]
    if config == nil then
        monster_id = monster_id or "nil"
        flog("error", "wild_elite_boss.on_born get config fail! "..monster_id)
    end

    local server_level = get_server_level()
    return level_formula_func(config.Level, server_level, config.LevelAdd)
end

function wild_elite_boss.on_born(self, monster_id)
    local config = wild_elite_boss_scheme[monster_id]
    if config == nil then
        monster_id = monster_id or "nil"
        flog("error", "wild_elite_boss.on_born get config fail! "..monster_id)
    end

    for _, v in pairs(config.AngerCondition) do
        self.anger_condition[v] = true
    end
    self.anger_value = 0
    self.config = config
end

function wild_elite_boss.get_anger_value(self)
    local anger_value = self.anger_value
    anger_value = math.floor(self.config.AngerChange * anger_value / 100)
    return anger_value
end

local function _finish_condition(self, condition_id)
    if not self.anger_condition[condition_id] then
        return false
    end
    if anger_change_scheme[condition_id] == nil then
        condition_id = condition_id or "nil"
        flog("error", "wild_elite_boss.finish_condition no condition_id "..condition_id)
        return
    end

    self.anger_condition[condition_id] = false
    local anger_diff = anger_change_scheme[condition_id].Rage
    self.anger_value = self.anger_value + anger_diff

    --condition_id = tostring(condition_id)
    --anger_diff = tostring(anger_diff)
    --local anger_change_message = create_system_message_by_id(const.SYSTEM_MESSAGE_ID.boss_anger_change, nil, condition_id, self.puppet.name, anger_diff)
    --self.puppet:BroadcastToAoi(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE, anger_change_message)
    return true
end

function wild_elite_boss.is_finish_condition_team_member(self, team_member_number)
    local anger_value_changed = false
    for i, v in pairs(anger_change_condition[LOGIC_NAME_TO_ID.team_member]) do
        repeat
            if not self.anger_condition[i] then
                break
            end
            if team_member_number ~= v.Para1[1] then
                break
            end
            if _finish_condition(self, i) then
                anger_value_changed = true
            end
        until(true)
    end
    return anger_value_changed
end

function wild_elite_boss.is_finish_condition_time(self)
    local anger_value_changed = false
    local time_now_daily = date_to_day_second()
    for i, v in pairs(anger_change_condition[LOGIC_NAME_TO_ID.time]) do
        repeat
            if not self.anger_condition[i] then
                break
            end

            if time_now_daily < v.start_time_daily or time_now_daily > v.end_time_daily then
                break
            end

            if _finish_condition(self, i) then
                anger_value_changed = true
            end
        until(true)
    end
    return anger_value_changed
end

function wild_elite_boss.is_finish_condition_once_damage(self, damage, attacker_id)
    local anger_value_changed = false
    if attacker_id == nil then
        return
    end
    for i, v in pairs(anger_change_condition[LOGIC_NAME_TO_ID.once_damage]) do
        repeat
            if not self.anger_condition[i] then
                break
            end

            if damage < v.Para1[1] or damage > v.Para1[2] then
                break
            end

            if _finish_condition(self, i) then
                anger_value_changed = true
            end
        until(true)
    end
    self.damage_cnt[attacker_id] = self.damage_cnt[attacker_id] or 0
    self.damage_cnt[attacker_id] = self.damage_cnt[attacker_id] + damage
    return anger_value_changed
end

function wild_elite_boss.is_finish_condition_damage_count(self, killer_id)
    local anger_value_changed = false
    if killer_id == nil then
        return
    end

    local total_damage = 0
    for i, v in pairs(self.damage_cnt) do
        total_damage = total_damage + v
    end
    self.damage_cnt[killer_id] = self.damage_cnt[killer_id] or 0
    local damage_rate
    if total_damage == 0 then
        damage_rate = 0
    else
        damage_rate = self.damage_cnt[killer_id] * 100 / total_damage
    end

    for i, v in pairs(anger_change_condition[LOGIC_NAME_TO_ID.damage_count]) do
        repeat
            if not self.anger_condition[i] then
                break
            end

            if damage_rate >= v.Para1[1] then
                break
            end

            if _finish_condition(self, i) then
                anger_value_changed = true
            end
        until(true)
    end
    return anger_value_changed
end


function wild_elite_boss.is_finish_condition_position(self, pos)
    local anger_value_changed = false
    for i, v in pairs(anger_change_condition[LOGIC_NAME_TO_ID.position]) do
        repeat
            if not self.anger_condition[i] then
                break
            end

            local diff_x = pos.x - v.Para1[1]
            local diff_y = pos.y - v.Para1[2]
            local diff_z = pos.z - v.Para1[3]
            local diff_square = diff_x * diff_x + diff_y * diff_y + diff_z * diff_z
            if diff_square > v.radius_square then
                break
            end

            if _finish_condition(self, i) then
                anger_value_changed = true
            end
        until(true)
    end
    return anger_value_changed
end

function wild_elite_boss.is_finish_condition_pet_skill(self, pet_skill, pet_id)
    local anger_value_changed = false
    if self.pet_skill_black_list[pet_id] then
        return anger_value_changed
    end
    self.pet_skill_black_list[pet_id] = true
    for i, v in pairs(anger_change_condition[LOGIC_NAME_TO_ID.pet_skill]) do
        repeat
            if not self.anger_condition[i] then
                break
            end

            local temp_skill_set = table.copy(v.skill_set)
            for _, v in pairs(pet_skill) do
                if temp_skill_set[v.id] then
                    temp_skill_set[v.id] = nil
                end
            end
            if not table.isEmptyOrNil(temp_skill_set) then
                break
            end

            if _finish_condition(self, i) then
                anger_value_changed = true
            end
        until(true)
    end
    return anger_value_changed
end

function wild_elite_boss.is_finish_condition_hatred_country(self, hatred_entity_list)
    local anger_value_changed = false
    for i, v in pairs(anger_change_condition[LOGIC_NAME_TO_ID.hatred_country]) do
        repeat
            if not self.anger_condition[i] then
                break
            end

            local country_list = {[1] = true, [2] = true}
            for _, v in pairs(hatred_entity_list) do
                if country_list[v.country] then
                    country_list[v.country] = nil
                end
            end

            if not table.isEmptyOrNil(country_list) then
                break
            end

            if _finish_condition(self, i) then
                anger_value_changed = true
            end
        until(true)
    end
    return anger_value_changed
end

function wild_elite_boss.is_finish_condition_hatred_number(self, list_num)
    local anger_value_changed = false
    for i, v in pairs(anger_change_condition[LOGIC_NAME_TO_ID.hatred_number]) do
        repeat
            if not self.anger_condition[i] then
                break
            end

            if list_num < v.Para1[1] then
                break
            end

            if _finish_condition(self, i) then
                anger_value_changed = true
            end
        until(true)
    end
    return anger_value_changed
end


return wild_elite_boss