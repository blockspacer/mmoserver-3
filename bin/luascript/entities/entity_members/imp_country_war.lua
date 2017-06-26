--------------------------------------------------------------------
-- 文件名:	imp_country_war.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/5/8 0008
-- 描  述:	阵营大攻防
--------------------------------------------------------------------
local const = require "Common/constant"
local BATTLE_SCENE_LIST = const.BATTLE_SCENE_LIST
local common_scene_config = require "configs/common_scene_config"
local get_scene_detail_config = common_scene_config.get_scene_detail_config
local fix_string = require "basic/fix_string"
local get_config_name = require("basic/scheme").get_config_name
local entity_common = require "entities/entity_common"
local _get_now_time_second = _get_now_time_second
local tostring = tostring
local pairs = pairs
local country_monster = require("boss/country_monster")
local table = table
local pvp_country_war_config = require "configs/pvp_country_war_config"
local flog = require "basic/log"
local db_hiredis = require "basic/db_hiredis"

local imp_country_war = {}
imp_country_war.__index = imp_country_war

local params = {
    country_war_score = {db = true, sync = true},              --大攻防战功
    last_country_war_start_time = {db = true, sync = true, default = 100},    --最近一次大攻防时间
    country_war_submit_arrow = {db=true,sync=true,default = 0},
    country_war_recovery_blood = {db=true,sync=true,default = 0},
}

setmetatable(imp_country_war, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_country_war.__params = params

function imp_country_war.__ctor(self)
    self.hatred_list = {}
    self.country_war_task = {}
    self.attack_monster_list = {}
    self.country_war_task_refresh_count = {}
    self.submit_material_id = 0
    self.attack_transport_fleets = {}
end

local function refresh_task_param(self)
    for num,task in pairs(self.country_war_task) do
        if task.status == const.COUNTRY_WAR_TASK_STATUS.doing then
            local task_config = pvp_country_war_config.get_country_war_task(task.id)
            if task_config.LogicID == const.COUNTRY_WAR_TASK_LOGIC_ID.win then
                if country_monster.is_in_battle_time() then
                    task.param = 0
                else
                    local past_winner = db_hiredis.get("country_war_winner") or {}
                    if past_winner ~= nil and past_winner.winner == self.country then
                        task.param = 1
                        task.status = const.COUNTRY_WAR_TASK_STATUS.done
                    else
                        task.param = 0
                    end
                end
            elseif task_config.LogicID == const.COUNTRY_WAR_TASK_LOGIC_ID.attack_monster then
                if self.attack_monster_list[task_config.para1] ~= nil and self.attack_monster_list[task_config.para1][task_config.para2] ~= nil then
                    task.param = 1
                    task.status = const.COUNTRY_WAR_TASK_STATUS.done
                else
                    task.param = 0
                end
            elseif task_config.LogicID == const.COUNTRY_WAR_TASK_LOGIC_ID.country_score then
                task.param = country_monster.get_country_total_score()[self.country]
                if task.param >= task_config.para1 then
                    task.status = const.COUNTRY_WAR_TASK_STATUS.done
                end

            elseif task_config.LogicID == const.COUNTRY_WAR_TASK_LOGIC_ID.player_score then
                task.param = self.country_war_score
                if self.country_war_score >= task_config.para1 then
                    task.status = const.COUNTRY_WAR_TASK_STATUS.done
                end
            elseif task_config.LogicID == const.COUNTRY_WAR_TASK_LOGIC_ID.attack_transport_fleet then
                task.param = 0
                for _,_ in pairs(self.attack_transport_fleets) do
                    task.param = task.param + 1
                end
                if task.param >= task_config.para1 then
                    task.status = const.COUNTRY_WAR_TASK_STATUS.done
                end
            elseif task_config.LogicID == const.COUNTRY_WAR_TASK_LOGIC_ID.submit_arrow then
                task.param = self.country_war_submit_arrow
                if self.country_war_submit_arrow >= task_config.para1 then
                    task.status = const.COUNTRY_WAR_TASK_STATUS.done
                end
            elseif task_config.LogicID == const.COUNTRY_WAR_TASK_LOGIC_ID.recovery_blood then
                task.param = self.country_war_recovery_blood
                if self.country_war_recovery_blood >= task_config.para1 then
                    task.status = const.COUNTRY_WAR_TASK_STATUS.done
                end
            end
        end
    end
end

local function refresh_task(self)
    self.country_war_task = {}
    self.attack_monster_list = {}
    self.attack_transport_fleets = {}
    self.country_war_submit_arrow = 0
    self.country_war_recovery_blood = 0
    self.country_war_task_refresh_count = {}
    local tasks = pvp_country_war_config.refresh_country_war_task(self.country)
    for num,id in pairs(tasks) do
        self.country_war_task[num] = {}
        self.country_war_task[num].id = id
        self.country_war_task[num].param = 0
        self.country_war_task[num].status = const.COUNTRY_WAR_TASK_STATUS.doing
        self.country_war_task_refresh_count[num] = 0
    end
    refresh_task_param(self)
end

local function _refresh_data(self)
    self.hatred_list = {}
    self:change_value_on_rank_list("country_war_score", 0)
    refresh_task(self)
end

local function _check_data_effective(self)
    local country_war_start_time = country_monster.get_country_war_start_time()
    if self.last_country_war_start_time < country_war_start_time then
        _refresh_data(self)
        self.last_country_war_start_time = country_war_start_time
    end
end

--根据dict初始化
function imp_country_war.imp_country_war_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.country_war_task = table.copy(dict.country_war_task) or {}
    self.attack_monster_list = table.copy(dict.attack_monster_list) or {}
    self.attack_transport_fleets = table.copy(dict.attack_transport_fleets) or {}
    self.country_war_task_refresh_count = table.copy(dict.country_war_task_refresh_count) or {}
    _check_data_effective(self)
    refresh_task_param(self)
end

function imp_country_war.imp_country_war_init_from_other_game_dict(self,dict)
    self:imp_country_war_init_from_dict(dict)

    self.hatred_list = dict.hatred_list
end

function imp_country_war.imp_country_war_write_to_dict(self, dict)
    _check_data_effective(self)
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
    dict.country_war_task = table.copy(self.country_war_task)
    dict.attack_monster_list = table.copy(self.attack_monster_list)
    dict.attack_transport_fleets = table.copy(self.attack_transport_fleets)
    dict.country_war_task_refresh_count = table.copy(self.country_war_task_refresh_count)
end

function imp_country_war.imp_country_war_write_to_other_game_dict(self,dict)
    self:imp_country_war_write_to_dict(dict)

    dict.hatred_list = self.hatred_list
end

function imp_country_war.imp_country_war_write_to_sync_dict(self, dict)
    _check_data_effective(self)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
    dict.country_war_task = table.copy(self.country_war_task)
    dict.country_war_task_refresh_count = {}
    for id,_ in pairs(self.country_war_task) do
        dict.country_war_task_refresh_count[id] = self.country_war_task_refresh_count[id] or 0
    end
end

function imp_country_war.on_get_country_war_score(self, input)
    _check_data_effective(self)
    self:change_value_on_rank_list("country_war_score", input.country_war_score)
    local score_addition = input.score_addition
    local message_id = input.message_id
    local monster_name = input.monster_name

    self:send_system_message_by_id(message_id, nil, nil, monster_name,tostring(score_addition))
end

function imp_country_war.on_get_country_war_basic_info(self, input)
    _check_data_effective(self)
    input.func_name = "get_country_war_basic_info"
    input.country_war_score = self.country_war_score
    self:send_message_to_country_server(input)
end

function imp_country_war.on_be_attacked(self, enemy_id, damage)
    local parent_on_be_attacked = entity_common.get_parent_func(self, "on_be_attacked")
    parent_on_be_attacked(self, enemy_id, damage)

    local enemy_player = self:get_scene_entity_by_id(enemy_id)
    if enemy_player ~= nil and enemy_player.on_get_owner ~= nil then
        enemy_player = enemy_player:on_get_owner()
    end
    if enemy_player == nil or enemy_player.type ~= const.ENTITY_TYPE_PLAYER or enemy_player.country == self.country then
        return
    end

    local current_time = _get_now_time_second()
    self.hatred_list[enemy_id] = self.hatred_list[enemy_id] or {damage = 0, name = enemy_player.actor_name, level = enemy_player.level}
    local hatred_info = self.hatred_list[enemy_id]
    hatred_info.damage = hatred_info.damage + damage
    hatred_info.last_time = current_time
end

function imp_country_war.imp_country_war_on_kill_player(self, dead_entity)
    if dead_entity == nil or dead_entity.hatred_list == nil or dead_entity.country == self.country then
        return
    end
    _check_data_effective(dead_entity)

    local current_time = _get_now_time_second()
    local output = {}
    output.func_name = "kill_player_in_country_war"
    output.killer_id = self.actor_id
    output.killer_name = self.actor_name
    output.killer_level = self.level

    dead_entity.hatred_list[self.actor_id] = nil
    for hatred_id, hatred_info in pairs(dead_entity.hatred_list) do
        if current_time - hatred_info.last_time > const.ASSIST_IN_COUNT_SEC then
            dead_entity.hatred_list[hatred_id] = nil
        end
    end

    output.hatred_list = dead_entity.hatred_list
    output.country = self.country
    output.dead_id = dead_entity.actor_id
    output.dead_name = dead_entity.actor_name
    output.dead_level = dead_entity.level
    self:send_message_to_country_server(output)

    dead_entity.hatred_list = {}
end

function imp_country_war.on_get_detail_battle_achievement_list(self, input)
    input.func_name = "get_detail_battle_achievement_list"
    input.actor_id = self.actor_id
    input.country = self.country
    self:send_message_to_country_server(input)
end

function imp_country_war.gm_start_country_war(self, last_time)
    local output = {func_name = "gm_start_country_war", last_time = last_time }
    self:send_message_to_country_server(output)
end


function imp_country_war.rpc_add_country_monster_hp(self, monster_scene_id, hp_persent, callback_table)
    local output = {func_name = "on_add_hp" }
    output.monster_scene_id = monster_scene_id
    output.hp_persent = hp_persent
    output.callback_table = callback_table
    output.actor_id = self.actor_id
    self:send_message_to_country_server(output)
end

function imp_country_war.rpc_add_archer_tower_arrow(self, monster_scene_id, arrow_num, max_arrow_num, callback_table)
    local output = {func_name = "on_add_arrow" }
    output.monster_scene_id = monster_scene_id
    output.arrow_num = arrow_num
    output.callback_table = callback_table
    output.actor_id = self.actor_id
    output.max_arrow_num = max_arrow_num
    self:send_message_to_country_server(output)
end


function imp_country_war.refresh_country_war_task(self,input,sync_data)
    flog("tmlDebug","imp_country_war.refresh_country_war_task")
    if input.task_num == nil then
        return
    end
    if self.country_war_task[input.task_num] == nil then
        flog("debug","imp_country_war.refresh_country_war_task task_num is out of range!task_num "..input.task_num)
        return
    end
    if self.country_war_task[input.task_num].status == const.COUNTRY_WAR_TASK_STATUS.reward then
        flog("debug","imp_country_war.refresh_country_war_task task status is reward!task_num "..input.task_num)
        return
    end

    if not country_monster.is_in_battle_time() then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_country_war_not_start,func_name="RefreshCountryWarTaskRet"})
        return
    end

    if self.country_war_task_refresh_count[input.task_num] == nil then
        self.country_war_task_refresh_count[input.task_num] = 0
    end
    local cost = pvp_country_war_config.get_country_war_task_refresh_cost(self.country_war_task_refresh_count[input.task_num]+1)
    if #cost == 2 then
        if not self:is_enough_by_id(cost[1],cost[2]) then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_item_not_enough,func_name="RefreshCountryWarTaskRet"})
            return
        end
    end
    local new_id = pvp_country_war_config.refresh_country_war_task_by_num(self.country,input.task_num,self.country_war_task[input.task_num].id)
    if new_id == nil then
        flog("debug","imp_country_war.refresh_country_war_task can not find new task id!task_num "..input.task_num..",current_id "..self.country_war_task[input.task_num].id)
        return
    end
    if #cost == 2 then
        self:remove_item_by_id(cost[1],cost[2])
    end
    self.country_war_task[input.task_num].id = new_id
    self.country_war_task[input.task_num].status = const.COUNTRY_WAR_TASK_STATUS.doing
    self.country_war_task[input.task_num].param = 0
    self.country_war_task_refresh_count[input.task_num] = self.country_war_task_refresh_count[input.task_num] + 1
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="RefreshCountryWarTaskRet"})
    self:imp_assets_write_to_sync_dict(sync_data)
    self:get_country_war_info({})
end

function imp_country_war.get_country_war_info(self,input)
    if input.refresh == nil or input.refresh then
        refresh_task_param(self)
    end

    local data = {}
    data.result = 0
    data.func_name = "GetCountryWarInfoRet"
    self:imp_country_war_write_to_sync_dict(data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,data)
end

function imp_country_war.get_country_war_task_reward(self,input,sync_data)
    if input.task_num == nil then
        return
    end
    if self.country_war_task[input.task_num] == nil then
        flog("debug","imp_country_war.get_country_war_task_reward task_num is out of range!task_num "..input.task_num)
        return
    end
    if self.country_war_task[input.task_num].status == const.COUNTRY_WAR_TASK_STATUS.doing then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_country_war_task_not_done,func_name="GetCountryWarTaskRewardRet"})
        return
    end
    if self.country_war_task[input.task_num].status == const.COUNTRY_WAR_TASK_STATUS.reward then
        flog("debug","imp_country_war.get_country_war_task_reward task status is reward!task_num "..input.task_num)
        return
    end
    local task_config = pvp_country_war_config.get_country_war_task(self.country_war_task[input.task_num].id)
    if task_config == nil then
        flog("debug","imp_country_war.get_country_war_task_reward task_config == nil!task_num "..input.task_num)
        return
    end

    local need_cell = 0
    local rewards = {}
    for i = 1,4,1 do
        if #task_config["Reward"..i] == 2 then
            rewards[task_config["Reward"..i][1]] = task_config["Reward"..i][2]
            if const.RESOURCE_ID_TO_NAME[task_config["Reward"..i][1]] == nil then
                need_cell = need_cell + 1
            end
        end
    end
    if self:get_empty_slot_number() < need_cell then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_bag_is_full,func_name="GetCountryWarTaskRewardRet"})
        return
    end
    self:add_new_rewards(rewards)
    self.country_war_task[input.task_num].status = const.COUNTRY_WAR_TASK_STATUS.reward
    self:get_country_war_info({refresh=false})
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="GetCountryWarTaskRewardRet"})
    self:imp_assets_write_to_sync_dict(sync_data)
end

function imp_country_war.submit_country_war_arrow(self,value)
    self.country_war_submit_arrow = self.country_war_submit_arrow + value
end

function imp_country_war.country_war_monster_recovery_blood(self)
    self.country_war_recovery_blood = self.country_war_recovery_blood + 1
end

function imp_country_war.country_war_attack_monster(self,scene_id,element_id)
    flog("tmlDebug","imp_country_war.country_war_attack_monster")
    if not country_monster.is_in_battle_time() then
        flog("tmlDebug"," not country_monster.is_in_battle_time()")
        return
    end
    if pvp_country_war_config.check_country_war_task_monster(scene_id,element_id) then
        if self.attack_monster_list[scene_id] == nil then
            self.attack_monster_list[scene_id] = {}
        end
        if self.attack_monster_list[scene_id][element_id] == nil then
            self.attack_monster_list[scene_id][element_id] = 1
        end
    else
        flog("tmlDebug","is not country war task monster!")
    end
end

function imp_country_war.country_war_attack_transport_fleet(self,uid)
    if not country_monster.is_in_battle_time() then
        return
    end
    if self.attack_transport_fleets[uid] == nil then
        self.attack_transport_fleets[uid] = 1
    end
end

function imp_country_war.submit_material_callback(self,input)
    if input.result ~= 0 then
        self.submit_material_id = 0
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=input.result,func_name="SubmitCountryWarMaterialsRet"})
        return
    end
     local task_config = pvp_country_war_config.get_npc_task(self.submit_material_id)
    if task_config == nil then
        flog("debug","submit_material_callback task_config == nil,submit_material_id "..self.submit_material_id)
        self.submit_material_id = 0
        return
    end
    self.submit_material_id = 0
    if task_config.TaskType == const.COUNTRY_NPC_TASK_TYPE.recovery_blood then
        self:country_war_monster_recovery_blood()
    elseif task_config.TaskType == const.COUNTRY_NPC_TASK_TYPE.submit_arrow then
        self:submit_country_war_arrow(task_config.Item[2])
    end
    local rewards = {}
    if #task_config.Reward1 == 2 then
        rewards[task_config.Reward1[1]] = (rewards[task_config.Reward1[1]] or 0) + task_config.Reward1[2]
    end
    if #task_config.Reward2 == 2 then
        rewards[task_config.Reward2[1]] = (rewards[task_config.Reward2[1]] or 0) + task_config.Reward2[2]
    end
    if #task_config.Reward3 == 2 then
        rewards[task_config.Reward3[1]] = (rewards[task_config.Reward3[1]] or 0) + task_config.Reward3[2]
    end
    self:remove_item_by_id(task_config.Item[1],task_config.Item[2])
    self:add_new_rewards(rewards)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="SubmitCountryWarMaterialsRet"})
    local data = {}
    self:imp_assets_write_to_sync_dict(data)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE,data)
end

function imp_country_war.submit_country_war_materials(self,input,sync_data)
    if input.id == nil then
        return
    end
    if self.submit_material_id ~= 0 then
        flog("debug","self.submit_material_id ~= 0")
        return
    end

    local task_config = pvp_country_war_config.get_npc_task(input.id)
    if task_config == nil then
        flog("tmlDebug","submit_country_war_materials task_config == nil id "..input.id)
        return
    end
    if #task_config.Item ~= 2 then
        flog("tmlDebug","submit_country_war_materials task_config.Item ~= 2 id "..input.id)
        return
    end
    if not self:is_enough_by_id(task_config.Item[1],task_config.Item[2]) then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_item_not_enough,func_name="SubmitCountryWarMaterialsRet"})
        return
    end

    local callback_table = {}
    callback_table.func_name = "submit_material_callback"

    if task_config.TaskType == const.COUNTRY_NPC_TASK_TYPE.recovery_blood then
        self.submit_material_id = input.id
        self:rpc_add_country_monster_hp(task_config.ElementID,task_config.Recovery,callback_table)
    elseif task_config.TaskType == const.COUNTRY_NPC_TASK_TYPE.submit_arrow then
        if #task_config.ItemMax ~= 2 then
            return
        end
        self.submit_material_id = input.id
        self:rpc_add_archer_tower_arrow(task_config.ElementID,task_config.Item[2],task_config.ItemMax[2],callback_table)
    else
        flog("debug","submit_country_war_materials task_config.TaskType is error!")
    end
end

function imp_country_war.query_country_npc_info(self,input)
    local data = {result = 0 ,npcs_status={} }
    data.func_name = "QueryCountryNpcInfoRet"
    local npc_tasks = pvp_country_war_config.get_npc_tasks()
    for id,task in pairs(npc_tasks) do
        data.npcs_status[id] = {}
        data.npcs_status[id].hp,data.npcs_status[id].max_hp = country_monster.get_country_monster_hp(task.ElementID)
        if task.TaskType == const.COUNTRY_NPC_TASK_TYPE.recovery_blood then
            data.npcs_status[id].energy = 0
            data.npcs_status[id].energy_max = 1
        elseif task.TaskType == const.COUNTRY_NPC_TASK_TYPE.submit_arrow then
            data.npcs_status[id].energy = country_monster.get_archer_tower_arrow_num(task.ElementID)
            data.npcs_status[id].energy_max = task.ItemMax[2]
        end
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,data)
end

function imp_country_war.on_get_transport_fleet_position(self, input)
    local scene_id = input.scene_id
    local transport_fleet_pos = country_monster.get_transport_fleet_position(scene_id)
    local output = {func_name = "GetTransportFleetPositionRet", transport_fleet_pos = transport_fleet_pos }
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

return imp_country_war