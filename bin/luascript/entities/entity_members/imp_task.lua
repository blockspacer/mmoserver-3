--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/3 0003
-- Time: 9:35
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local system_task_config = require "configs/system_task_config"
local get_now_time_second = _get_now_time_second
local flog = require "basic/log"
local math = require "math"
local timer = require "basic/timer"
local get_fight_server_info = require("basic/common_function").get_fight_server_info
--local team_follow = require "helper/team_follow"
local onlinerole = require "onlinerole"
local _get_now_time_second = _get_now_time_second
local common_level_config = require "configs/common_level_config"
local daily_refresher = require("helper/daily_refresher")
local pairs = pairs
local table =table
local common_system_list_config = require "configs/common_system_list_config"

local task_state = const.TASK_STATE
local task_sort = const.TASK_SORT
local task_type = const.TASK_TYPE
local task_trigger_condition = const.TASK_TRIGGER_CONDITION
local scene_type = const.SCENE_TYPE
local task_system_operation = const.TASK_SYSTEM_OPERATION

local daily_cycle_task_flag = {
    receive = 1,
    enter = 2,
}

local params = {
    daily_cycle_task_current_count = {db=true,sync=true,default=0 },
    country_task_current_count = {db=true,sync=true,default=0},
    country_task_current_turn = {db=true,sync=true,default=1}
}
local imp_task = {}
imp_task.__index = imp_task

setmetatable(imp_task, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_task.__params = params

function imp_task.__ctor(self)
    self.update_task_timer = nil
    --检查是否向客户端推送任务信息
    self.update_flag = true
    --检查是否有任务已完成
    self.check_flag = false
    --检查其他玩家奇门遁甲任务信息
    self.daily_cycle_task_check = nil
    self.daily_cycle_task_check_flag = 0
    self.daily_cycle_task_check_time = 0
    self.daily_cycle_task_refresher = nil

end

local function reset_daily_cycle_task_flag(self)
    self.daily_cycle_task_check = nil
    self.daily_cycle_task_check_flag = 0
    self.daily_cycle_task_check_time = 0
end

local function _destroy_update_task_timer(self)
    if self.update_task_timer ~= nil then
        timer.destroy_timer(self.update_task_timer)
        self.update_task_timer = nil
    end
end

--不考虑npc位置,这里只检查完成条件
local function check_task_done(self,task_id)
    if self.task_list[task_id] == nil then
        flog("tmlDebug","check_task_done have not this task,id "..task_id)
        return false
    end

    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil then
        flog("tmlDebug","check_task_done have not task_config,id "..task_id)
        return false
    end
    if task_config.TaskType == task_type.collect then
        self.task_list[task_id].param1 = self:get_item_count_by_id(task_config.CompleteTaskParameter1[1])
        if #task_config.CompleteTaskParameter1 == 2 and self:is_enough_by_id(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2]) then
            return true
        end
    elseif task_config.TaskType == task_type.talk then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= 1 then
            return true
        end
    elseif task_config.TaskType == task_type.use_item then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= task_config.CompleteTaskParameter3[2] then
            return true
        end
    elseif task_config.TaskType == task_type.trigger_mechanism then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= 1 then
            return true
        end
    elseif task_config.TaskType == task_type.kill_monster then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= task_config.CompleteTaskParameter3[1] then
            return true
        end
    elseif task_config.TaskType == task_type.kill_player then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= task_config.CompleteTaskParameter1[1] then
            return true
        end
    elseif task_config.TaskType == task_type.daily_activity then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= math.floor(tonumber(task_config.CompleteTaskParameter2)) then
            return true
        end
    elseif task_config.TaskType == task_type.main_dungeon then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= 1 then
            return true
        end
    elseif task_config.TaskType == task_type.team_dungeon then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= math.floor(tonumber(task_config.CompleteTaskParameter2)) then
            return true
        end
    elseif task_config.TaskType == task_type.level then
        self.task_list[task_id].param1 = self.level
        if self.task_list[task_id].param1 >= task_config.CompleteTaskParameter1[1] then
            return true
        end
    elseif task_config.TaskType == task_type.fight_power then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= task_config.CompleteTaskParameter1[1] then
            return true
        end
    elseif task_config.TaskType == task_type.gather then
        local current_count = self:get_item_count_by_id(task_config.CompleteTaskParameter4[1])
        if self.task_list[task_id].param1 ~= current_count then
            self.update_flag = true
            self.task_list[task_id].param1 = current_count
        end
        if self.task_list[task_id].param1 >= task_config.CompleteTaskParameter4[2] then
            return true
        end
        return false
    elseif task_config.TaskType == task_type.system_operation then
        if task_config.CompleteTaskParameter1[1] == task_system_operation.capture_pet then
            --self.task_list[task_id].param1 = self:get_pet_number()
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.seal then
            self.task_list[task_id].param1 = self:get_seal_level()
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.equipment_strengthen then
            self.task_list[task_id].param1 = self:get_equipment_strengthen_level()
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.fashion then

        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.qinggong then

        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.faction then
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.shop then

        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.gem then

        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.dress_equipment then
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.arena_guide then
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.activity_guide then
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.team_guide then
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.contry_guide then
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.businessman_guide then
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.equip_skill then
        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.hangup_guide then

        elseif task_config.CompleteTaskParameter1[1] == task_system_operation.upgrade_skill then
            self.task_list[task_id].param1 = self:get_upgrade_skill_level()
        end
        if self.task_list[task_id].param1 == nil or self.task_list[task_id].param1 < task_config.CompleteTaskParameter1[2] then
            return false
        else
            return true
        end
    elseif task_config.TaskType == task_type.task_dungeon then
        if self.task_list[task_id].param1 ~= nil and self.task_list[task_id].param1 >= 1 then
            return true
        end
    end
    return false
end

local function update_task_timer_handle(self)
    if self.check_flag == true then
        flog("tmlDebug","update_task_timer_handle check_flag == true")
        self.check_flag = false
        for _,task in pairs(self.task_list) do
            flog("tmlDebug","update_task_timer_handle task.state "..task.state..",task.id "..task.id)
            if task.state == task_state.doing and check_task_done(self,task.id) then
                task.state = task_state.submit
                self.update_flag = true
            end
        end
    end
    if self.update_flag == true then
        self.update_flag = false
        self:on_get_task_info(nil,nil)
    end
    if self.daily_cycle_task_check ~= nil then
        local all_reply = true
        for actor_id,result in pairs(self.daily_cycle_task_check) do
            if result == -1 then
                all_reply = false
            end
        end
        if all_reply or _get_now_time_second() - self.daily_cycle_task_check_time > 15 then
            self:daily_cycle_task_check_over(all_reply)
        end
    end
end

local function create_update_task_timer(self)
    _destroy_update_task_timer(self)
    local function _update_task_timer_handle()
        update_task_timer_handle(self)
    end
    self.update_task_timer = timer.create_timer(_update_task_timer_handle,1000,const.INFINITY_CALL)
end

local function add_task(self,id,state)
    if id ~= nil then
        local task_config = system_task_config.get_task_config(id)
        if task_config ~= nil then
            self.task_list[id] = {}
            self.task_list[id].id = id
            self.task_list[id].task_sort = task_config.TaskSort
            self.task_list[id].receive_time = get_now_time_second()
            if state == nil then
                if task_config.LevelLimit <= self.level then
                    self.task_list[id].state = task_state.acceptable
                else
                    self.task_list[id].state = task_state.unacceptable
                end
            else
                self.task_list[id].state = state
            end
            self.update_flag = true
            if task_config.TaskType == task_type.talk or task_config.TaskType == task_type.use_item or task_config.TaskType == task_type.trigger_mechanism or task_config.TaskType == task_type.kill_monster or task_config.TaskType == task_type.kill_player or task_config.TaskType == task_type.daily_activity or task_config.TaskType == task_type.main_dungeon or task_config.TaskType == task_type.team_dungeon or task_config.TaskType == task_type.task_dungeon then
                self.task_list[id].param1 = 0
            elseif task_config.TaskType == task_type.level then
                self.task_list[id].param1 = self.level
            elseif task_config.TaskType == task_type.fight_power then
                self.task_list[id].param1 = self.fight_power
            elseif task_config.TaskType == task_type.collect then
                self.task_list[id].param1 = self:get_item_count_by_id(task_config.CompleteTaskParameter1[1])
            elseif task_config.TaskType == task_type.gather then
                self.task_list[id].param1 = self:get_item_count_by_id(task_config.CompleteTaskParameter4[1])
            elseif task_config.TaskType == task_type.system_operation then
                self.task_list[id].param1 = 0
                if task_config.CompleteTaskParameter1[1] == task_system_operation.equip_skill and self:is_equip_skill() then
                    self.task_list[id].param1 = 1
                end
                if task_config.CompleteTaskParameter1[1] == task_system_operation.fashion and self:is_equip_fashion() then
                    self.task_list[id].param1 = 1
                end
            end
            return true
        end
    end
    return false
end

local function trigger_branch_task(self)
    local branch_groups = system_task_config.get_branch_groups()
    for group_id,group in pairs(branch_groups) do
        if self.task_done.branch_task[group_id] == nil then
            local task_config = system_task_config.get_task_config(group.first_task_id)
            local is_trigger = true
            if task_config ~= nil then
                if task_config.PrepositionTask > 0 and self.task_done.main_task[task_config.PrepositionTask] == nil then
                    is_trigger = false
                end
                if is_trigger and task_config.TaskTriggerCondition[1] ~= task_trigger_condition.none then
                    if task_config.TaskTriggerCondition[1] == task_trigger_condition.level then
                        if task_config.TaskTriggerCondition[2] > self.level then
                            is_trigger = false
                        end
                    elseif task_config.TaskTriggerCondition[1] == task_trigger_condition.fight_power then
                        if task_config.TaskTriggerCondition[2] > self.fight_power then
                            is_trigger = false
                        end
                    end
                end
            end
            if is_trigger and add_task(self,group.first_task_id) then
                self.task_done.branch_task[group_id] = {}
                self.task_done.branch_task[group_id].done = false
                self.task_done.branch_task[group_id].done_task = {}
            end
        elseif self.task_done.branch_task[group_id].current_task ~= nil then
            repeat
                if self.task_list[self.task_done.branch_task[group_id].current_task] ~= nil then
                    break
                end
                local next_branch_task = system_task_config.get_next_branch_task(group_id,self.task_done.branch_task[group_id].current_task)
                if next_branch_task == nil then
                    break
                end

                local task_config = system_task_config.get_task_config(next_branch_task)
                if task_config == nil then
                    break
                end

                if task_config.AbandonSign == 1 then
                    break
                end
                local is_trigger = true
                if task_config.PrepositionTask > 0 and self.task_done.branch_task[group_id].done_task[task_config.PrepositionTask] == nil then
                    is_trigger = false
                end
                if is_trigger and task_config.TaskTriggerCondition[1] ~= task_trigger_condition.none then
                    if task_config.TaskTriggerCondition[1] == task_trigger_condition.level then
                        if task_config.TaskTriggerCondition[2] > self.level then
                            is_trigger = false
                        end
                    elseif task_config.TaskTriggerCondition[1] == task_trigger_condition.fight_power then
                        if task_config.TaskTriggerCondition[2] > self.fight_power then
                            is_trigger = false
                        end
                    end
                end
                if is_trigger and add_task(self,next_branch_task) then
                    self.task_done.branch_task[group_id].done = false
                end
            until(true)
        end
    end
end

local function task_done(self,task_id)
    if self.task_list[task_id] == nil then
        flog("warn","you have not this task!id "..task_id)
        return const.error_task_have_not_task
    end

    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil then
        flog("error","can not find task config,id "..task_id)
        return const.error_data
    end

    --完成操作
    if task_config.TaskType == task_type.collect then
        if #task_config.CompleteTaskParameter1 ~= 2 or self:is_enough_by_id(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2]) == false then
            return const.error_item_not_enough
        end
        self:remove_item_by_id(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2])
    elseif task_config.TaskType == task_type.gather then
--        local count = self:get_item_count_by_id(task_config.CompleteTaskParameter4[1])
--        if count > task_config.CompleteTaskParameter4[2] then
--            count = task_config.CompleteTaskParameter4[2]
--        end
        if #task_config.CompleteTaskParameter4 ~= 2 or self:is_enough_by_id(task_config.CompleteTaskParameter4[1],task_config.CompleteTaskParameter4[2]) == false then
            return const.error_item_not_enough
        end
        self:remove_item_by_id(task_config.CompleteTaskParameter4[1],task_config.CompleteTaskParameter4[2])
    end
    self.task_list[task_id] = nil
    --发奖励
    local rewards = {}
    for i=1,4,1 do
        if #task_config["TaskReward"..i] == 2 then
            local item_id = task_config["TaskReward"..i][1]
            local count = task_config["TaskReward"..i][2]
            --奇门遁甲任务第一个奖励为经验奖励并根据等级表给经验
            if task_config.TaskSort == task_sort.daily_cycle and i==1 then
                local level_config = common_level_config.get_level_config(self.level)
                if level_config ~= nil then
                    count = math.floor(count*level_config.ExpPara/10000)
                end
            elseif task_config.TaskSort == task_sort.daily_cycle and i==1 then
                --阵营任务第一个任务奖励
                local exp_config = system_task_config.get_country_task_exp_reward(self.country_task_current_turn)
                if exp_config ~= nil then
                    count = math.floor(count*exp_config.ExpRatio/100)
                end
            end
            if rewards[item_id] == nil then
                rewards[item_id] =count
            else
                rewards[item_id] = rewards[item_id] + count
            end
        end
    end
    --阵营任务超过次数不给奖励
    if task_config.TaskSort ~= task_sort.country or self.country_task_current_count < system_task_config.get_country_task_max_count() then
        if table.isEmptyOrNil(rewards) == false then
            self:add_new_rewards(rewards)
            local info = {}
            self:imp_assets_write_to_sync_dict(info)
            self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
            self:send_message(const.SC_MESSAGE_LUA_REQUIRE, rewards)
        end
    end
    --下一任务
    if task_config.TaskSort == task_sort.main then
        self.main_task_id = task_id
        self.task_done.main_task[task_id] = true
        local next_main_task = system_task_config.get_next_main_task(self.main_task_id)
        if next_main_task ~= nil and add_task(self,next_main_task) then
            self.main_task_id = next_main_task
        end
        trigger_branch_task(self)
    elseif task_config.TaskSort == task_sort.branch then
        self.task_done.branch_task[task_config.TaskGroup].done_task[task_id] = true
        local next_branch_task = system_task_config.get_next_branch_task(task_config.TaskGroup,task_id)
        self.task_done.branch_task[task_config.TaskGroup].current_task = task_id
        if next_branch_task == nil then
            self.task_done.branch_task[task_config.TaskGroup].done = true
        else
            trigger_branch_task(self)
        end
    elseif task_config.TaskSort == task_sort.daily_cycle then
        self.daily_cycle_task_current_count = self.daily_cycle_task_current_count + 1
        local next_daily_cycle_task = system_task_config.get_next_daily_cycle_task(task_id)
        if next_daily_cycle_task ~= nil then
            add_task(self,next_daily_cycle_task)
        end
        self:finish_activity("cycle_task")
    elseif task_config.TaskSort == task_sort.country then
        self.country_task_current_count = self.country_task_current_count + 1
        self.country_task_current_turn = self.country_task_current_turn + 1
        if self.country_task_current_turn > system_task_config.get_country_task_max_turn() then
            self.country_task_current_turn = self.country_task_current_turn - system_task_config.get_country_task_max_turn()
        end
        if self.country_task_current_turn > 1 then
            local next_task_id = system_task_config.get_country_task(self.country,self.level)
            if next_task_id == nil then
                flog("debug","imp_task.task_done can not find country task,country "..self.country..",level "..self.level)
            else
                add_task(self,next_task_id)
            end
        end
        self:finish_activity("country_task")
    end
    self.update_flag = true
    return 0
end

local function init_player_task(self)
    local task_config = nil
    if self.task_list == nil then
        self.task_list = {}
    end
    if self.task_done == nil then
        self.task_done = {}
    end
    if self.task_done.main_task == nil then
        self.task_done.main_task = {}
    end
    if self.task_done.branch_task == nil then
        self.task_done.branch_task = {}
    end

    --检查任务是否已废弃
    if self.task_list ~= nil then
        for tid,task in pairs(self.task_list) do
            task_config = system_task_config.get_task_config(tid)
            --已废弃
            if task_config.AbandonSign == 1 then
                self.task_list[tid] = nil
                local pre_task_id = system_task_config.get_preposition_task(tid)
                if task_config.TaskSort == task_sort.main then
                    if pre_task_id == 0 then
                        self.main_task_id = system_task_config.get_first_main_task_id(self.country)
                        add_task(self,self.main_task_id)
                    else
                        self.main_task_id = pre_task_id
                        local next_main_task = system_task_config.get_next_main_task(self.main_task_id)
                        if next_main_task ~= nil and add_task(self,next_main_task) then
                            self.main_task_id = next_main_task
                        end
                    end
                elseif task_config.TaskSort == task_sort.branch then
                    if pre_task_id ~= 0 then
                        local next_branch_task = system_task_config.get_next_branch_task(task_config.TaskGroup,pre_task_id)
                        if next_branch_task == nil or add_task(self,next_branch_task) == false then
                            self.task_done.branch_task[task_config.TaskGroup].done = true
                        end
                    end
                end
            end
            --检查是否状态错误(有可能因为配置修改导致可完成的任务无法完成)
            if task.state == task_state.submit and not check_task_done(self,task.id) then
                task.state = task_state.doing
            end
        end
    end

    --检查主线任务
    if self.main_task_id == nil then
        self.main_task_id = system_task_config.get_first_main_task_id(self.country)
        add_task(self,self.main_task_id)
    elseif self.task_list[self.main_task_id] == nil then
        if self.task_done.main_task[self.main_task_id] == true then
            local next_main_task = system_task_config.get_next_main_task(self.main_task_id)
            if next_main_task ~= nil and add_task(self,next_main_task) then
                self.main_task_id = next_main_task
            end
        end
    end
    --检查支线任务
    trigger_branch_task(self)
    create_update_task_timer(self)
end

local function on_player_logout(self,input,sync_data)
    _destroy_update_task_timer(self)
end

local function refresh_daily_cycle_task_count(self)
    flog("tmlDebug", "imp_task  refresh_daily_cycle_task_count")
    self.daily_cycle_task_current_count = 0
    self.country_task_current_count = 0
end

--[[
--当前任务task_list{[task_id]={id,task_sort,state,param1,param2,param3,receive_time}}
--已完成任务task_done{main_task={[task_id]=true},branch_task={[group_id]=true}}
]]
function imp_task.imp_task_init_from_dict(self, dict)
    local task = table.get(dict,"task",{})
    for i, v in pairs(params) do
        if task[i] ~= nil then
            self[i] = task[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    if task.task_list ~= nil then
        self.task_list = table.copy(task.task_list)
    end
    if task.task_done ~= nil then
        self.task_done = table.copy(task.task_done)
    end
    if task.main_task_id ~= nil then
        self.main_task_id = task.main_task_id
    end
    init_player_task(self)
    if task.daily_cycle_task_last_refresh_time == nil then
        task.daily_cycle_task_last_refresh_time = _get_now_time_second()
    end
    self.daily_cycle_task_refresher = daily_refresher(refresh_daily_cycle_task_count, task.daily_cycle_task_last_refresh_time, const.REFRESH_HOUR)
    self.daily_cycle_task_refresher:check_refresh(self)
end

function imp_task.imp_task_init_from_other_game_dict(self,dict)
    self:imp_task_init_from_dict(dict)
end

function imp_task.imp_task_write_to_dict(self, dict)
    self.daily_cycle_task_refresher:check_refresh(self)
    dict.task = {}
    for i, v in pairs(params) do
        if v.db then
            dict.task[i] = self[i]
        end
    end
    dict.task.task_list = table.copy(self.task_list)
    dict.task.task_done = table.copy(self.task_done)
    dict.task.main_task_id = self.main_task_id
    dict.task.daily_cycle_task_last_refresh_time = self.daily_cycle_task_refresher:get_last_refresh_time()
end

function imp_task.imp_task_write_to_other_game_dict(self,dict)
    self:imp_task_write_to_dict(dict)
end

function imp_task.imp_task_write_to_sync_dict(self, dict)
    self.daily_cycle_task_refresher:check_refresh(self)
    dict.task = {}
    for i, v in pairs(params) do
        if v.sync then
            dict.task[i] = self[i]
        end
    end
    dict.task.task_list = {}
    dict.task.main_task_id = self.main_task_id
    if self.task_list ~= nil then
        dict.task.task_list = table.copy(self.task_list)
    end
end

local function send_data_to_client(self,func_name)
    local data = {}
    data.result = 0
    data.func_name = func_name
    self:imp_task_write_to_sync_dict(data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,data)
end

function imp_task.on_get_task_info(self,input,sync_data)
    send_data_to_client(self,"GetTaskInfoRet")
end

local function check_receive_task(self,task_id)
    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil or task_config.AbandonSign == 1 then
        return const.error_task_can_not_find
    end

    if task_config.PrepositionTask ~= 0 then
        if task_config.TaskSort == task_sort.main then
            if self.task_done.main_task[task_config.PrepositionTask] == nil then
                return const.error_task_preposition_is_not_complete
            end
        elseif task_config.TaskSort == task_sort.branch then
            local preposition_config = system_task_config.get_task_config(task_config.PrepositionTask)
            if preposition_config == nil then
                return const.error_task_preposition_is_not_complete
            end
            if preposition_config.TaskSort == task_sort.main then
                if self.task_done.main_task[task_config.PrepositionTask] == nil then
                    return const.error_task_preposition_is_not_complete
                end
            elseif task_config.TaskSort == task_sort.branch then
                if self.task_done.branch_task[task_config.TaskGroup].done_task[task_config.PrepositionTask] == nil then
                    return const.error_task_preposition_is_not_complete
                end
            end
        end
    end

    if task_config.TaskTriggerCondition ~= nil and #task_config.TaskTriggerCondition >= 2 then
        if task_config.TaskTriggerCondition[1] == task_trigger_condition.level then
            if self.level < task_config.TaskTriggerCondition[2] then
                return const.error_task_level_not_enough
            end
        elseif task_config.TaskTriggerCondition[1] == task_trigger_condition.fight_power then
            if self.fight_power < task_config.TaskTriggerCondition[2] then
                return const.error_task_fight_power_not_enough
            end
        end
    end

    if self.level < task_config.LevelLimit then
        return const.error_task_level_not_enough
    end

    return 0
end

local function receive_task(self,task_id,result)
    if result ~= 0 then
        flog("tmlDebug","imp_task.on_receive_task receive_task result "..result)
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=result,func_name="ReceiveTaskRet"})
        return
    end
    if self.task_list[task_id] ~= nil then
        self.task_list[task_id].state = task_state.doing
        self.task_list[task_id].receive_time = get_now_time_second()
    else
        add_task(self,task_id,task_state.doing)
    end

    self.check_flag = true
    self.update_flag = true
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=result,func_name="ReceiveTaskRet"})
end

function imp_task.on_receive_task(self,input,sync_data)
    if input.task_id == nil then
        flog("info",'imp_task.on_receive_task task_id is nil!!!')
        return
    end
    flog("tmlDebug","imp_task.on_receive_task task id "..input.task_id)

    if self.task_list[input.task_id] == nil then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_task_have_not_task,func_name="ReceiveTaskRet"})
        return
    end

    if self.task_list[input.task_id].state == task_state.doing then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_task_already_receive,func_name="ReceiveTaskRet"})
        return
    end

    local result = check_receive_task(self,input.task_id)
    if result ~= 0 then
        flog("tmlDebug","imp_task.on_receive_task check_receive_task result "..result)
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=result,func_name="ReceiveTaskRet"})
        return
    end
    local task_config = system_task_config.get_task_config(input.task_id)
    --接取第三参数
    if task_config.TaskType == task_type.use_item or task_config.TaskType == task_type.collect then
        if #task_config.ReceiveTaskNPCParameter3 == 2 then
            if self:get_first_empty() == nil then
                result =const.error_no_empty_cell
                self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , {func_name="ReceiveTaskRet",result = result})
                return
            end
            local item = {}
            item[task_config.ReceiveTaskNPCParameter3[1]] = task_config.ReceiveTaskNPCParameter3[2]
            self:add_new_rewards(item)
        end
    end
    if task_config.ReceiveTaskNPCParameter1[1] == nil then
        receive_task(self,input.task_id,0)
        return
    end
    if self.in_fight_server then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_check_receive_task_distance",task_id=input.task_id})
    else
        local check_distance = self:check_distance_with_scene_unit(task_config.ReceiveTaskNPCParameter1[1],task_config.ReceiveTaskNPCParameter1[2],task_config.ReceiveTaskNPCParameter2[1])
        if check_distance == true then
            receive_task(self,input.task_id,0)
        else
            receive_task(self,input.task_id,const.error_task_distance_not_enough)
        end
    end
end

function imp_task.on_check_receive_task_distance_reply(self,input,sync_data)
    if input.check_distance == true then
        receive_task(self,input.task_id,0)
    else
        receive_task(self,input.task_id,const.error_task_distance_not_enough)
    end
end

function imp_task.update_task_when_player_level_up(self)
    --检查是否触发分支任务
    trigger_branch_task(self)
    for _,task in pairs(self.task_list) do
        local task_config = system_task_config.get_task_config(task.id)
        repeat
            if task_config == nil then
                return
            end

            if task.state == task_state.unacceptable then
                if task_config.LevelLimit > self.level then
                    break
                end
                task.state = task_state.acceptable
                self.update_flag = true
            elseif task.state == task_state.doing then
                if task_config.TaskType == task_type.level then
                    task.param1 = self.level
                    self.check_flag = true
                    self.update_flag = true
                end
            end
        until(true)
    end
end

function imp_task.update_task_when_player_fight_power_change(self)
    trigger_branch_task(self)
    for _,task in pairs(self.task_list) do
        local task_config = system_task_config.get_task_config(task.id)
        repeat
            if task_config == nil then
                break
            end

            if task.state ~= task_state.doing then
                break
            end

            if task_config.TaskType ~= task_type.fight_power then
                break
            end
            task.param1 = self.fight_power
            self.check_flag = true
            self.update_flag = true
        until(true)
    end
end

local function submit_task(self,task_id,result)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="SubmitTaskRet",result=result,task_id=task_id})
        return
    end
    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil then
        return
    end
    if task_config.TaskSort == task_sort.daily_cycle and self:is_team_captain() then
        local members = self:get_team_members()
        local team_members = {}
        for actor_id,_ in pairs(members) do
            table.insert(team_members,actor_id)
        end
        self:send_message_to_team_server({func_name="daily_cycle_task_submit",actors=team_members,task_id=task_id})
        return
    end

    local result = task_done(self,task_id)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="SubmitTaskRet",result=result,task_id=task_id})
end

function imp_task.daily_cycle_task_submit(self,input,sync_data)
    if input.task_id == nil then
        return
    end
    if self.task_list[input.task_id] == nil or self.task_list[input.task_id].state ~= task_state.submit then
        flog("tmlDebug","imp_task.daily_cycle_task_submit have not task or task can not submit!task id "..input.task_id)
        return
    end
    task_done(self,input.task_id)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="SubmitTaskRet",result=0,task_id=input.task_id})
end

function imp_task.on_submit_task(self,input,sync_data)
    if input.task_id == nil then
        flog("info","imp_task.on_submit_task input.task_id == nil!!!")
        return
    end
    if check_task_done(self,input.task_id) == false then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="SubmitTaskRet",result=const.error_task_can_not_submit,task_id=input.task_id})
        return
    end
    local task_config = system_task_config.get_task_config(input.task_id)
--    if task_config.AutoComplete == 1 then
--        submit_task(self,input.task_id,0)
--        return
--    end

    if task_config.CompleteTaskNPCParameter1[1] ~= nil then
        if task_config.CompleteTaskNPCParameter1[1] == const.SCENE_TYPE.WILD or task_config.CompleteTaskNPCParameter1[1] == const.SCENE_TYPE.CITY then
            local check_distance = self:check_distance_with_scene_unit(task_config.CompleteTaskNPCParameter1[1],task_config.CompleteTaskNPCParameter1[2],task_config.CompleteTaskNPCParameter2[1])
            if check_distance == true then
                submit_task(self,input.task_id,0)
            else
                submit_task(self,input.task_id,const.error_task_distance_not_enough)
            end
        elseif self.in_fight_server == true then
            self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_check_submit_task_distance",task_id=input.task_id})
        end
    else
        submit_task(self,input.task_id,0)
    end
end

function imp_task.on_check_submit_task_distance_reply(self,input,sync_data)
    if input.check_distance == true then
        submit_task(self,input.task_id,0)
    else
        submit_task(self,input.task_id,const.error_task_distance_not_enough)
    end
end

function imp_task.auto_complete_task(self,task_id)
    task_done(task_id)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="SubmitTaskRet",result=0,task_id=task_id})
end

function imp_task.on_give_up_task(self,input,sync_data)
    if input.task_id == nil then
        flog("info","imp_task.on_give_up_task input.task_id == nil!!!")
        return
    end
    local task_config = system_task_config.get_task_config(input.task_id)
    if task_config == nil then
        flog("info","imp_task.on_give_up_task task_config == nil!!!id "..input.task_id)
        return
    end

    if task_config.Aandon == 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GiveUpTaskRet",result=const.error_task_can_not_give_up})
        return
    end

    if self.task_list[input.task_id] == nil or self.task_list[input.task_id].state ~= task_state.doing then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GiveUpTaskRet",result=const.error_task_no_doing})
        return
    end
    if task_config.TaskSort == task_sort.main then
        flog("tmlDebug","this task can not be give up!!!id "..input.task_id)
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GiveUpTaskRet",result=const.error_task_can_not_give_up})
        return
    elseif task_config.TaskSort == task_sort.branch then
        self.task_list[input.task_id].state = task_state.acceptable
        self.task_list[input.task_id].receive_time = get_now_time_second()
        self.task_list[input.task_id].param1 = nil
        self.task_list[input.task_id].param2 = nil
        self.task_list[input.task_id].param3 = nil
        self.update_flag = true
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GiveUpTaskRet",result=0})
    elseif task_config.TaskSort == task_sort.daily_cycle then
        self.task_list[input.task_id] = nil
        self.update_flag = true
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GiveUpTaskRet",result=0})
    elseif task_config.TaskSort == task_sort.country then
        self.country_task_current_turn = 1
        self.task_list[input.task_id] = nil
        self.update_flag = true
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GiveUpTaskRet",result=0})
    else
        flog("tmlDebug","this task can not be give up!!!id "..input.task_id)
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GiveUpTaskRet",result=const.error_task_can_not_give_up})
        return
    end
end

local function task_gather(self,task_id,result)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskGatherRet",result=result})
        return
    end

    if self.task_list[task_id] == nil then
        return
    end

    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil then
        return
    end

    local empty_cell = self:get_first_empty()
    if empty_cell == nil then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskGatherRet",result=const.error_no_empty_cell})
        return
    end

    local rewards = {}
    rewards[task_config.CompleteTaskParameter4[1]] = 1
    self:add_new_rewards(rewards)
    self.task_list[task_id].param1 = self:get_item_count_by_id(task_config.CompleteTaskParameter4[1])
    self.check_flag = true
    self.update_flag = true
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskGatherRet",result=result})
end

function imp_task.on_task_gather(self,input,sync_data)
    if input.task_id == nil then
        flog("info","imp_task.on_task_gather input.task_id == nil actor_id "..self.actor_id)
        return
    end

    local task_id = input.task_id
    if self.task_list[task_id] == nil then
        flog("info","imp_task.on_task_gather have not task,id "..task_id..", actor_id "..self.actor_id)
        return
    end

    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil then
        flog("info","imp_task.on_task_gather task_config == nil")
        return
    end

    if #task_config.CompleteTaskParameter1 ~= 2 then
        flog("error","imp_task.on_task_use_item task_config.CompleteTaskParameter1 error,task id "..task_id)
        return
    end

    if #task_config.CompleteTaskParameter4 ~= 2 then
        flog("error","imp_task.on_task_use_item task_config.CompleteTaskParameter3 error,task id "..task_id)
        return
    end

    local current_count = self:get_item_count_by_id(task_config.CompleteTaskParameter4[1])
    if self.task_list[task_id].param1 ~= current_count then
        self.task_list[task_id].param1 = current_count
        self.update_flag = true
    end

    self.task_list[task_id].param1 = self:get_item_count_by_id(task_config.CompleteTaskParameter4[1])
    if task_config.CompleteTaskParameter3[1] <= self.task_list[task_id].param1 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskGatherRet",result=const.error_task_gather_count_enough})
        return
    end

    local empty_cell = self:get_first_empty()
    if empty_cell == nil then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskGatherRet",result=const.error_no_empty_cell})
        return
    end

    if task_config.CompleteTaskParameter1[1] == scene_type.WILD or task_config.CompleteTaskParameter1[1] == scene_type.CITY then
        local check_distance = self:check_distance_with_scene_position(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2],task_config.CompleteTaskParameter2)
        if check_distance == true then
            task_gather(self,task_id,0)
        else
            task_gather(self,task_id,const.error_task_distance_not_enough)
        end
    elseif self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_check_task_gather_distance",task_id=input.task_id})
    else
        task_gather(self,task_id,const.error_task_distance_not_enough)
    end
end

function imp_task.on_check_task_gather_distance_reply(self,input,sync_data)
    task_gather(self,input.task_id,input.check_distance)
end

local function task_use_item(self,task_id,result)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskUseItemRet",result=result})
        return
    end

    if self.task_list[task_id] == nil then
        return
    end

    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil then
        return
    end

    if self:is_enough_by_id(task_config.CompleteTaskParameter3[1],1) == false then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskUseItemRet",result=const.error_item_not_enough,item_id=task_config.CompleteTaskParameter3[1]})
        return
    end

    self:remove_item_by_id(task_config.CompleteTaskParameter3[1],1)
    self.task_list[task_id].param1 = (self.task_list[task_id].param1 or 0) + 1
    self.check_flag = true
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskUseItemRet",result=result})
end

function imp_task.on_task_use_item(self,input,sync_data)
    if input.task_id == nil then
        flog("info","imp_task.on_task_use_item input.task_id == nil actor_id "..self.actor_id)
        return
    end

    local task_id = input.task_id
    if self.task_list[task_id] == nil then
        flog("info","imp_task.on_task_use_item have not task,id "..task_id..", actor_id "..self.actor_id)
        return
    end

    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil then
        flog("info","imp_task.on_task_use_item task_config == nil")
        return
    end

    if #task_config.CompleteTaskParameter3 ~= 2 then
        flog("error","imp_task.on_task_use_item task_config.CompleteTaskParameter3 error,task id "..task_id)
        return
    end

    if #task_config.CompleteTaskParameter1 ~= 2 then
        flog("error","imp_task.on_task_use_item task_config.CompleteTaskParameter1 error,task id "..task_id)
        return
    end

    if self:is_enough_by_id(task_config.CompleteTaskParameter3[1],1) == false then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskUseItemRet",result=const.error_item_not_enough,item_id=task_config.CompleteTaskParameter3[1]})
        return
    end

    if task_config.CompleteTaskParameter1[1] == scene_type.WILD or task_config.CompleteTaskParameter1[1] == scene_type.CITY then
        local check_distance = self:check_distance_with_scene_position(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2],task_config.CompleteTaskParameter2)
        if check_distance == true then
            task_use_item(self,task_id,0)
        else
            task_use_item(self,task_id,const.error_task_distance_not_enough)
        end
    elseif self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_check_task_use_item_distance",task_id=input.task_id})
    else
        task_use_item(self,task_id,const.error_task_distance_not_enough)
    end
end

function imp_task.on_check_task_use_item_distance_reply(self,input,sync_data)
    task_use_item(self,input.task_id,input.check_distance)
end

local function task_trigger_mechanism(self,task_id,result)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskTriggerMechanismRet",result=result})
        return
    end

    if self.task_list[task_id] == nil then
        return
    end

    local task_config = system_task_config.get_task_config(task_id)
    self.task_list[task_id].param1 = 1
    self.check_flag = true
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskTriggerMechanismRet",result=0})
end

function imp_task.on_task_trigger_mechanism(self,input,sync_data)
    if input.task_id == nil then
        flog("info","imp_task.on_task_trigger_mechanism input.task_id == nil actor_id "..self.actor_id)
        return
    end

    local task_id = input.task_id
    if self.task_list[task_id] == nil then
        flog("info","imp_task.on_task_trigger_mechanism have not task,id "..task_id..", actor_id "..self.actor_id)
        return
    end

    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil then
        flog("info","imp_task.on_task_trigger_mechanism task_config == nil")
        return
    end

    if #task_config.CompleteTaskParameter1 ~= 2 then
        flog("error","imp_task.on_task_trigger_mechanism task_config.CompleteTaskParameter1 error,task id "..task_id)
        return
    end

    if task_config.CompleteTaskParameter1[1] == scene_type.WILD or task_config.CompleteTaskParameter1[1] == scene_type.CITY then
        local check_distance = self:check_distance_with_scene_unit(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2],math.floor(tonumber(task_config.CompleteTaskParameter2)))
        if check_distance == true then
            task_trigger_mechanism(self,task_id,0)
        else
            task_trigger_mechanism(self,task_id,const.error_task_distance_not_enough)
        end
    elseif self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_check_task_trigger_mechanism_distance",task_id=input.task_id})
    else
        task_trigger_mechanism(self,task_id,const.error_task_distance_not_enough)
    end
end

function imp_task.on_check_task_trigger_mechanism_distance_reply(self,input,sync_data)
    task_trigger_mechanism(self,input.task_id,input.check_distance)
end


local function task_talk(self,task_id,result)
    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskTalkRet",result=result})
        return
    end

    if self.task_list[task_id] == nil then
        return
    end

    local task_config = system_task_config.get_task_config(task_id)
    self.task_list[task_id].param1 = 1
    self.check_flag = true
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="TaskTalkRet",result=0})
end

function imp_task.on_task_talk(self,input,sync_data)
    if input.task_id == nil then
        flog("info","imp_task.on_task_talk input.task_id == nil actor_id "..self.actor_id)
        return
    end

    local task_id = input.task_id
    if self.task_list[task_id] == nil then
        flog("info","imp_task.on_task_talk have not task,id "..task_id..", actor_id "..self.actor_id)
        return
    end

    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil then
        flog("info","imp_task.on_task_talk task_config == nil")
        return
    end

    if #task_config.CompleteTaskParameter1 ~= 2 then
        flog("error","imp_task.on_task_talk task_config.CompleteTaskParameter1 error,task id "..task_id)
        return
    end

    if task_config.CompleteTaskParameter1[1] == scene_type.WILD or task_config.CompleteTaskParameter1[1] == scene_type.CITY then
        local check_distance = self:check_distance_with_scene_unit(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2],math.floor(tonumber(task_config.CompleteTaskParameter2)))
        if check_distance == true then
            task_talk(self,task_id,0)
        else
            task_talk(self,task_id,const.error_task_distance_not_enough)
        end
    elseif self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_check_task_on_task_talk_distance",task_id=input.task_id})
    else
        task_talk(self,task_id,const.error_task_distance_not_enough)
    end
end

function imp_task.on_check_task_talk_distance_reply(self,input,sync_data)
    task_talk(self,input.task_id,input.check_distance)
end

function imp_task.update_task_kill_monster(self,scene_type,scene_id,unit_id)
    flog("tmlDebug","imp_task.update_task_kill_monster")
    local task_config = nil
    for _,task in pairs(self.task_list) do
        if task.state == task_state.doing then
            task_config = system_task_config.get_task_config(task.id)
            if task_config ~= nil and task_config.TaskType == task_type.kill_monster and #task_config.CompleteTaskParameter1 == 2 then
                if task_config.CompleteTaskParameter1[1] == scene_type and task_config.CompleteTaskParameter1[2] == scene_id and math.floor(tonumber(task_config.CompleteTaskParameter2)) == unit_id then
                    task.param1 = (task.param1 or 0) + 1
                    self.check_flag = true
                    self.update_flag = true
                end
            end
        end
    end
end

function imp_task.on_fight_server_kill_task_monster(self,input,sync_data)
    self:update_task_kill_monster(input.scene_type,input.scene_id,input.unit_id)
end

function imp_task.update_task_kill_player(self)
    local scene = self:get_scene()
    if scene == nil then
        return
    end
    if self.scene:get_scene_type() ~= const.SCENE_TYPE.WILD and self.scene:get_scene_type() ~= const.SCENE_TYPE.CITY then
        return
    end

    local task_config = nil
    for _,task in pairs(self.task_list) do
        if task.state == task_state.doing then
            task_config = system_task_config.get_task_config(task.id)
            if task_config ~= nil and task_config.TaskType == task_type.kill_player then                
                task.param1 = (task.param1 or 0) + 1
                self.check_flag = true
                self.update_flag = true
            end
        end
    end
end

function imp_task.update_task_dungeon(self,tasktype,dungeon_id)
    flog("tmlDebug","imp_task.update_task_dungeon")
    local task_config = nil
    for _,task in pairs(self.task_list) do
        repeat
            task_config = system_task_config.get_task_config(task.id)
            if task_config == nil then
                break
            end
            if task_config.TaskType ~= tasktype then
                break
            end
            if task_config.TaskType == task_type.task_dungeon then
                --任务副本取第三个参数
                if dungeon_id ~= task_config.CompleteTaskParameter3[1] then
                    break
                end
            else
                if dungeon_id ~= task_config.CompleteTaskParameter1[1] then
                    break
                end
            end

            if task.state ~= task_state.doing then
                break
            end
            task.param1 = (task.param1 or 0) + 1
            self.check_flag = true
        until(true)
    end
end

function imp_task.update_task_system_operation(self,type)
    local task_config = nil
    for _,task in pairs(self.task_list) do
        repeat
            task_config = system_task_config.get_task_config(task.id)
            if task_config == nil then
                break
            end
            if task_config.TaskType ~= task_type.system_operation then
                break
            end
            if type ~= task_config.CompleteTaskParameter1[1] then
                break
            end

            if task.state ~= task_state.doing then
                break
            end

            if task.param1 == nil or task.param1 < task_config.CompleteTaskParameter1[2] then
                task.param1 = (task.param1 or 0) + 1
                --task.param1 = task_config.CompleteTaskParameter1[2]
            end

            self.check_flag = true
        until(true)
    end
end

function imp_task.on_update_task_system_operation(self,input,sync_data)
    self:update_task_system_operation(input.type)
end

function imp_task.update_task_collect(self)
    local task_config = nil
    for _,task in pairs(self.task_list) do
        repeat
            task_config = system_task_config.get_task_config(task.id)
            if task_config == nil then
                break
            end
            if task_config.TaskType ~= task_type.collect then
                break
            end
            if task.state ~= task_state.doing then
                break
            end
            task.param1 = self:get_item_count_by_id(task_config.CompleteTaskParameter1[1])
            self.check_flag = true
            self.update_flag = true
        until(true)
    end
end

local function gm_set_main_task(self,task_id)
    flog("tmlDebug","imp_task.gm_set_task "..task_id)
    local tid = tonumber(task_id)
    local task_config = system_task_config.get_task_config(tid)
    if task_config == nil or task_config.TaskSort ~= task_sort.main or task_config.AbandonSign ~= 0 then
        flog("tmlDebug","imp_task.gm_set_task task_config == nil or task_config.TaskSort ~= task_sort.main")
        return false
    end

    local done_main_task = {}
    local last_tid = system_task_config.get_preposition_task(task_config.PrepositionTask)
    self.main_task_id = last_tid
    --所有前置任务设置为完成
    while(last_tid > 0)
    do
        task_config = system_task_config.get_task_config(last_tid)
        if task_config == nil then
            flog("tmlDebug","task_config == nil")
            break
        end
        self.task_done.main_task[last_tid] = true
        done_main_task[last_tid] = true
        last_tid = system_task_config.get_preposition_task(task_config.PrepositionTask)
    end
    --所有后续任务设置为未完成
    for _tid,v in pairs(self.task_done.main_task) do
        self.task_done.main_task[_tid] = done_main_task[_tid]
    end
    --当前主线任务取消
    for _tid,task in pairs(self.task_list) do
        task_config = system_task_config.get_task_config(_tid)
        if task_config == nil or task_config.TaskSort == task_sort.main then
            self.task_list[_tid] = nil
        end
    end
    --新任务
    local next_main_task = system_task_config.get_first_main_task_id(self.country)
    if self.main_task_id ~= 0 then
        next_main_task = system_task_config.get_next_main_task(self.main_task_id)
    end
    if next_main_task ~= nil and add_task(self,next_main_task) then
        self.main_task_id = next_main_task
    end
    trigger_branch_task(self)
    self.check_flag = true
    self.update_flag = true
    return true
end

--命令设置任务
function imp_task.gm_set_task(self,task_id)
    flog("tmlDebug","imp_task.gm_set_task "..task_id)
    local tid = tonumber(task_id)
    local gm_task_config = system_task_config.get_task_config(tid)
    if gm_task_config == nil or gm_task_config.AbandonSign ~= 0 then
        flog("tmlDebug","imp_task.gm_set_task gm_task_config == nil")
        return
    end
    if gm_task_config.TaskSort == task_sort.main then
        gm_set_main_task(self,task_id)
    elseif gm_task_config.TaskSort == task_sort.branch then
        if gm_task_config.Camp ~= self.country then
            return
        end
        local first_branch_task_id = system_task_config.get_group_first_task_id(gm_task_config.TaskGroup)
        if first_branch_task_id == nil then
            return
        end
        local first_branch_task_config = system_task_config.get_task_config(first_branch_task_id)
        if first_branch_task_config == nil then
            return
        end
        if first_branch_task_config.PrepositionTask > 0 then
            local main_task_config = system_task_config.get_task_config(first_branch_task_config.PrepositionTask)
            if main_task_config ~= nil then
                if main_task_config.TaskSort ~= task_sort.main then
                    return
                end
                if self.task_done.main_task[first_branch_task_config.PrepositionTask] ~= true then
                    local next_main_task_config = system_task_config.get_task_config(system_task_config.get_next_main_task(first_branch_task_config.PrepositionTask))
                    if next_main_task_config == nil then
                        return
                    end
                    if gm_set_main_task(self,next_main_task_config.TaskID) == false then
                        return
                    end

                    if task_id == first_branch_task_id then
                        return
                    end
                end
            end
        end
        if self.task_done.branch_task[gm_task_config.TaskGroup] == nil then
            self.task_done.branch_task[gm_task_config.TaskGroup] = {}
            self.task_done.branch_task[gm_task_config.TaskGroup].done = false
            self.task_done.branch_task[gm_task_config.TaskGroup].done_task = {}
        end
        local done_branch_task = {}
        local last_tid = system_task_config.get_preposition_task(gm_task_config.PrepositionTask)
        self.task_done.branch_task[gm_task_config.TaskGroup].current_task = last_tid
        --所有前置任务设置为完成
        while(last_tid > 0)
        do
            local task_config = system_task_config.get_task_config(last_tid)
            if task_config == nil then
                break
            end
            if task_config.TaskSort == task_sort.main then
                break
            end
            self.task_done.branch_task[task_config.TaskGroup].done_task[last_tid] = true
            done_branch_task[last_tid] = true
            self.task_list[last_tid] = nil
            last_tid = system_task_config.get_preposition_task(task_config.PrepositionTask)
            flog("tmlDebug","last_tid "..last_tid)
        end
        --所有后续任务设置为未完成
        for _tid,v in pairs(self.task_done.branch_task[gm_task_config.TaskGroup].done_task) do
            self.task_done.branch_task[gm_task_config.TaskGroup].done_task[_tid] = done_branch_task[_tid]
        end

        --当前任务取消
        for _tid,task in pairs(self.task_list) do
            local current_task_config = system_task_config.get_task_config(_tid)
            if current_task_config == nil or (current_task_config.TaskSort == task_sort.branch and current_task_config.TaskGroup == gm_task_config.TaskGroup) then
                self.task_list[_tid] = nil
            end
        end

        trigger_branch_task(self)
        self.check_flag = true
        self.update_flag = true
    end
end

function imp_task.check_daily_cycle_task(self)
    self.daily_cycle_task_refresher:check_refresh(self)
    if self.daily_cycle_task_current_count >= system_task_config.get_daily_cycle_task_count() then
        return const.error_cycle_task_count_not_enough
    end
    if self.level < system_task_config.get_daily_cycle_task_level() then
        return const.error_cycle_task_level_not_enough
    end
    return 0
end
--日常环线任务
function imp_task.on_receive_daily_cycle_task(self,input,sync_data)
    flog("tmlDebug","imp_task.on_receive_daily_cycle_task")
    if self.daily_cycle_task_check ~= nil then
        flog("info","imp_task.on_receive_daily_cycle_task self.daily_cycle_task_check ~= nil")
        return
    end

    if not self:is_team_captain() then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_cycle_task_is_not_captain,func_name="ReceiveDailyCycleTaskRet"})
        return
    end
    if system_task_config.get_daily_cycle_task_player_count() > self:get_team_members_number() then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_cycle_task_player_count_not_enough,func_name="ReceiveDailyCycleTaskRet"})
        return
    end

    for _,task in pairs(self.task_list) do
        if task.task_sort == task_sort.daily_cycle then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_cycle_task_is_exist,func_name="ReceiveDailyCycleTaskRet"})
            return
        end
    end

    local members = self:get_team_members()
    self.daily_cycle_task_check = {}
    for actor_id,_ in pairs(members) do
        self.daily_cycle_task_check[actor_id] = -1
    end
    self.daily_cycle_task_check_flag = daily_cycle_task_flag.receive
    self.daily_cycle_task_check_time = _get_now_time_second()
    self:send_message_to_team_server({func_name="daily_cycle_task_check",flag = self.daily_cycle_task_check_flag,actors=table.copy(self.daily_cycle_task_check),captain_game_id=self.game_id})
end

local function receive_daily_cycle_task_check_over(self)
    flog("tmlDebug","imp_task.receive_daily_cycle_task_check_over")
    local daily_cycle_task_id = system_task_config.get_daily_cycle_task_first(self.country)
    if daily_cycle_task_id == nil then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_cycle_task_receive,func_name="ReceiveDailyCycleTaskRet",actor_id=self.actor_id})
        return
    end
    self:send_message_to_team_server({func_name="on_add_daily_cycle_task",actors=table.copy(self.daily_cycle_task_check),daily_cycle_task_id=daily_cycle_task_id})
end

local function enter_daily_cycle_task_check_over(self)
    flog("tmlDebug","imp_task.enter_daily_cycle_task_check_over")
    local task_id = nil
    for _,task in pairs(self.task_list) do
        if task.task_sort == task_sort.daily_cycle then
            task_id = task.id
        end
    end
    if task_id == nil then
        return
    end

    self:send_message_to_team_server({func_name="on_add_daily_cycle_task",actors=table.copy(self.daily_cycle_task_check),daily_cycle_task_id=task_id})
    local task_config = system_task_config.get_task_config(task_id)
    self:send_message_to_team_server({func_name="start_team_task_dungeon",team_id=self.team_id,dungeon_id=task_config.CompleteTaskParameter3[1]})
end

function imp_task.daily_cycle_task_check_over(self,all_reply)
    flog("tmlDebug","imp_task.daily_cycle_task_check_over")
    if not all_reply then
        flog("tmlDebug","imp_task.daily_cycle_task_check_over all reply is false!!!")
        reset_daily_cycle_task_flag(self)
        return
    end
    local success = true
    local func_name = "ReceiveDailyCycleTaskRet"
    if self.daily_cycle_task_check_flag == daily_cycle_task_flag.enter then
        func_name = "EnterTaskDungeonRet"
    end
    for actor_id,result in pairs(self.daily_cycle_task_check) do
        if result > 0 then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=result,func_name=func_name,actor_id=self.actor_id})
            success = false
        end
    end

    if not success then
        reset_daily_cycle_task_flag(self)
        return
    end

    if self.daily_cycle_task_check_flag == daily_cycle_task_flag.receive then
        receive_daily_cycle_task_check_over(self)
    elseif self.daily_cycle_task_check_flag == daily_cycle_task_flag.enter then
        enter_daily_cycle_task_check_over(self)
    end
    reset_daily_cycle_task_flag(self)
end

--team服务器询问成员任务状况
function imp_task.on_daily_cycle_task_check(self,input,sync_data)
    flog("tmlDebug","imp_task.on_daily_cycle_task_check")
    if input.captain_id == nil or input.flag == nil or input.captain_game_id == nil then
        return
    end
    local result = self:check_daily_cycle_task()
    self:send_message_to_team_server({func_name="on_daily_cycle_task_check_reply",flag = input.flag,captain_id=input.captain_id,captain_game_id=input.captain_game_id,result=result})
    if result ~= 0 and self.actor_id ~= input.captain_id then
        if input.flag == 1 then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=result,func_name="ReceiveDailyCycleTaskRet"})
        else
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=result,func_name="EnterTaskDungeonRet"})
        end
    end
end

--team服务器反馈给队长成员任务状况
function imp_task.on_daily_cycle_task_check_reply(self,input,sync_data)
    flog("tmlDebug","imp_task.on_daily_cycle_task_check_reply")
    if input.member_id == nil or input.result == nil or input.flag == nil then
        flog("tmlDebug","imp_task.on_daily_cycle_task_check_reply input.member_id == nil or input.result == nil or input.flag == nil")
        return
    end
    if self.daily_cycle_task_check == nil or self.daily_cycle_task_check[input.member_id] == nil or self.daily_cycle_task_check_flag ~= input.flag then
        flog("tmlDebug","imp_task.on_daily_cycle_task_check_reply self.daily_cycle_task_check == nil or self.daily_cycle_task_check[input.member_id] == nil or self.daily_cycle_task_check_flag ~= input.flag")
        return
    end
    self.daily_cycle_task_check[input.member_id] = input.result
end

function imp_task.on_add_daily_cycle_task(self,input,sync_data)
    flog("tmlDebug","imp_task.on_add_daily_cycle_task")
    if input.daily_cycle_task_id == nil then
        return
    end

    for _,task in pairs(self.task_list) do
        if task.task_sort == task_sort.daily_cycle then
            self.task_list[task.id] = nil
        end
    end
    add_task(self,input.daily_cycle_task_id,task_state.doing)
end

function imp_task.on_enter_daily_cycle_task_dungeon(self,task_id)
    flog("tmlDebug","imp_task.on_enter_daily_cycle_task_dungeon")
    if not self:is_team_captain() then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_cycle_task_is_not_captain,func_name="EnterTaskDungeonRet"})
        return
    end
    if system_task_config.get_daily_cycle_task_player_count() > self:get_team_members_number() then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_cycle_task_player_count_not_enough,func_name="EnterTaskDungeonRet"})
        return
    end

    local members = self:get_team_members()
    self.daily_cycle_task_check = {}
    for actor_id,_ in pairs(members) do
        self.daily_cycle_task_check[actor_id] = -1
    end
    self.daily_cycle_task_check_flag = daily_cycle_task_flag.enter
    self.daily_cycle_task_check_time = _get_now_time_second()
    self:send_message_to_team_server({func_name="daily_cycle_task_check",flag = self.daily_cycle_task_check_flag,actors=table.copy(self.daily_cycle_task_check),captain_game_id=self.game_id})
end

function imp_task.on_enter_task_dungeon(self,input,sync_data)
    if input.task_id == nil then
        return
    end

    if self.in_fight_server then
        flog("info","in fight server,can not enter task dungeon!")
        return
    end

    local task_id = input.task_id
    if self.task_list[task_id] == nil then
        flog("info","imp_task.enter_task_dungeon have not task,id "..task_id..", actor_id "..self.actor_id)
        return
    end

    local task_config = system_task_config.get_task_config(task_id)
    if task_config == nil or task_config.TaskType ~= task_type.task_dungeon then
        flog("info","imp_task.enter_task_dungeon task_config == nil")
        return
    end

    local dungeon_id = task_config.CompleteTaskParameter3[1]
    local dungeon_config = system_task_config.get_task_dungeon_config(dungeon_id)
    if dungeon_config == nil then
        flog("info","imp_task.enter_task_dungeon have not dungeon task_id "..task_id..",dungeon_id "..dungeon_id)
        return
    end

    --奇门遁甲
    if task_config.TaskSort == task_sort.daily_cycle then
        self:on_enter_daily_cycle_task_dungeon(input.task_id)
        return
    end
end

function imp_task.on_create_task_dungeon_complete(self,input,sync_data)
    if not input.success then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="EnterTaskDungeonRet",result=const.error_can_not_task_dungeon})
        return
    end
    if self.in_fight_server then
        flog("info","in fight server,can not enter task dungeon!")
        return
    end
    --team_follow.remove_team_follower(self:get_team_captain(), self)
    self:set_fight_server_info(input.fight_server_id,input.ip,input.port,input.token,input.fight_id,input.fight_type)
    local data = {}
    if self:is_in_team() then
        data.team_id = self.team_id
    end
    data.dungeon_id = input.dungeon_id
    self:send_fight_info_to_fight_server(data)
    for task_id,_ in pairs(self.task_list) do
        local task_config = system_task_config.get_task_config(task_id)
        if task_config.TaskSort == task_sort.daily_cycle then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="EnterTaskDungeonRet",result=0,task_id=task_id})
            break
        end
    end
end

function imp_task.destroy_update_task_timer(self)
    _destroy_update_task_timer(self)
end

function imp_task.set_task_update_flag(self,value)
    self.update_flag = value
end

function imp_task.on_receive_country_task(self)
    for _,task in pairs(self.task_list) do
        if task.task_sort == task_sort.country then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnReceiveCountryTaskRet",result=const.error_task_country_already_receive})
            return
        end
    end
    --判断等级需求等
    if not common_system_list_config.check_unlock(const.SYSTEM_NAME_TO_ID.country_task,self.level) then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnReceiveCountryTaskRet",result=const.error_level_not_enough})
        return
    end

    local task_id = system_task_config.get_country_task(self.country,self.level)
    if task_id == nil then
        flog("debug","imp_task.on_receive_country_task can not find country task,country "..self.country..",level "..self.level)
        return
    end
    add_task(self,task_id)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnReceiveCountryTaskRet",result=0})
end

register_message_handler(const.SS_MESSAGE_LUA_USER_LOGOUT,on_player_logout)

imp_task.__message_handler = {}
imp_task.__message_handler.on_player_logout = on_player_logout

return imp_task
