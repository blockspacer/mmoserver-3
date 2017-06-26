--------------------------------------------------------------------
-- 文件名:	drop_manager.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/1/5 0005
-- 描  述:	 怪物掉落
--------------------------------------------------------------------
local item_scheme = require("data/common_item").Item
local const = require "Common/constant"
local flog = require "basic/log"
local objectid = objectid
local random = math.random
local PROTECT_TIME = require("data/common_parameter_formula").Parameter[30].Parameter     --所属权保护时间
local DISAPPEAR_TIME = require("data/common_parameter_formula").Parameter[31].Parameter   --物品消失时间
local equipment_base = require "data/equipment_base"
local get_sequence_index = require("basic/scheme").get_sequence_index
local anger_reward_scheme = require("data/common_scene").AngerReward
local main_dungeon_scheme = require "data/challenge_main_dungeon"
local team_dungeon_scheme = require "data/challenge_team_dungeon"
local no_dungeon_scheme = require "data/common_scene"
local get_random_index_with_weight_by_count = require("basic/scheme").get_random_index_with_weight_by_count
local wild_elite_boss_scheme_original = require("data/common_scene").FieldBossID
local recreate_scheme_table_with_key = require("basic/scheme").recreate_scheme_table_with_key
local wild_elite_boss_scheme = recreate_scheme_table_with_key(wild_elite_boss_scheme_original, "MonsterID")
local task_dungeon_scheme = require "data/system_task"
local get_random_n = require("basic/scheme").get_random_n

local anger_reward_weight_table = {}
for i, v in pairs(anger_reward_scheme) do
    local weight_table = {}
    weight_table[1] = v.SmallDrop
    weight_table[2] = weight_table[1] + v.MidDrop
    weight_table[3] = weight_table[2] + v.LargeDrop
    anger_reward_weight_table[i] = weight_table
end

local DROP_INDEX_TO_NAME = {
    [1] = "SmallDrop",
    [2] = "MidDrop",
    [3] = "LargeDrop",
}

local function _init_drop_table(scheme_data)
    local drop_table = {}
    for _, v in pairs(scheme_data) do
        local id = v.DropID
        drop_table[id] = drop_table[id] or {}
        table.insert(drop_table[id], v)
    end
    return drop_table
end
local main_drop_table = _init_drop_table(main_dungeon_scheme.Drop)
local team_drop_table = _init_drop_table(team_dungeon_scheme.Drop)
local wild_drop_table = _init_drop_table(no_dungeon_scheme.Drop)
local task_drop_table = _init_drop_table(task_dungeon_scheme.Drop)


local drop_manager = {}
drop_manager.__index = drop_manager

setmetatable(drop_manager, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function drop_manager.__ctor(self, dungeon_type)
    if dungeon_type == "main_dungeon" then
        self.dungeon_scheme = main_dungeon_scheme
        self.scene_setting = main_dungeon_scheme.NormalTranscript
        self.drop_table = main_drop_table
    elseif dungeon_type == "team_dungeon" then
        self.dungeon_scheme = team_dungeon_scheme
        self.scene_setting = team_dungeon_scheme.TeamDungeons
        self.drop_table = team_drop_table
    elseif dungeon_type == "no_dungeon" then
        self.dungeon_scheme = no_dungeon_scheme
        self.scene_setting = no_dungeon_scheme.MainScene
        self.drop_table = wild_drop_table
    elseif dungeon_type == "task_dungeon" then
        self.dungeon_scheme = task_dungeon_scheme
        self.scene_setting = task_dungeon_scheme.MainTaskTranscript
        self.drop_table = task_drop_table
    else
        flog("error", "drop_manager.__ctor error dungeon_type "..dungeon_type)
    end
    self.total_drops = {}
end

local function _get_drop_item(self, drop_id, monster_level, owner_id, is_team_own, dungeon_id)
    local item_all = self.drop_table[drop_id]
    if item_all == nil then
        drop_id = drop_id or "nil"
        flog("error", "_get_drop_item no drop_id "..drop_id)
    end
    local drop_set = {}
    local current_time = _get_now_time_second()
    local cnt = 0
    for _, v in pairs(item_all) do
        if monster_level <= v.UpperLimit and monster_level >= v.LowerLimit then
            local rand_times = v.Number
            local rand_rate = v.Probability
            for i = 1, rand_times do
                if random(1, 10000) <= rand_rate then
                    local drop_entity_id = objectid()
                    local drop_data = {}
                    drop_data.id = drop_entity_id
                    drop_data.item_id = v.Reward[1]
                    drop_data.count = v.Reward[2]
                    drop_data.create_time = current_time
                    drop_data.owner_id = owner_id
                    drop_data.is_team_own = is_team_own
                    drop_data.scene_id = dungeon_id
                    self.total_drops[drop_entity_id] = drop_data
                    drop_set[drop_entity_id] = drop_data
                    cnt = cnt + 1
                end
            end
        end
    end

    return drop_set
end

function drop_manager.get_monster_info(self, monster_scene_id, dungeon_id)
    local brief_setting = self.scene_setting[dungeon_id]
    local scene_setting_scheme = self.dungeon_scheme[brief_setting.SceneSetting]
    if scene_setting_scheme[monster_scene_id] == nil then
        return 0
    end

    local drop_id = scene_setting_scheme[monster_scene_id].DropID
    local  monster_id = scene_setting_scheme[monster_scene_id].MonsterID
    if monster_id == 0 then
        flog("error", "drop_manager.create_drop_on_monster_die get drop_id or monster_id fail!")
        return 0
    end

    --[[local monster_level = self.dungeon_scheme.MonsterSetting[monster_id].Level
    if monster_level == 0 then
        flog("error", "drop_manager.create_drop_on_monster_die monster_level == 0")
        return 0
    end]]

    return drop_id, monster_id
end

function drop_manager.create_drop_on_monster_die(self, monster_scene_id, dungeon_id, owner_id, is_team_own, monster_level, anger_value)
    if dungeon_id == const.DUNGEON_NOT_EXIST then
        return
    end

    local drop_id, monster_id = self:get_monster_info(monster_scene_id, dungeon_id)
    local monster_config = self.dungeon_scheme.MonsterSetting[monster_id]
    if monster_config == nil then
        return
    end
    local monster_type = monster_config.Type
    if monster_type == const.MONSTER_TYPE.WILD_ELITE_BOSS then
        if anger_value == nil then
            monster_scene_id = monster_scene_id or nil
            flog("error", "anger_value is nil "..monster_scene_id)
        end
        local anger_index = get_sequence_index(anger_reward_scheme, "Reward", anger_value)
        local drop_index = get_random_index_with_weight_by_count(anger_reward_weight_table[anger_index])
        local drop_name = DROP_INDEX_TO_NAME[drop_index]
        drop_id = wild_elite_boss_scheme[monster_id][drop_name]
        if drop_id == nil then
            flog("error", "drop_manager.create_drop_on_monster_die get drop_id fail")
        end
        local drop_set = _get_drop_item(self, drop_id, monster_level, owner_id, is_team_own, dungeon_id)
        for _, drop_data in pairs(drop_set) do
            drop_data.boss_reward = true
        end
        return drop_set
    else
        if drop_id == nil or drop_id == 0 then
            return
        end
        return _get_drop_item(self, drop_id, monster_level, owner_id, is_team_own)
    end
end

function drop_manager.auto_roll_item(self, members_with_score, drop_entity_id)
    if self.total_drops[drop_entity_id] == nil then
        return
    else
        self.total_drops[drop_entity_id] = nil
    end

    local max_sign = 0
    local max_sign_id
    for id, v in pairs(members_with_score) do
        if v == nil or v == -1 then
            flog("error", "drop_manager.auto_roll_item not initalize "..table.serialize(members_with_score))
        end
        if v > max_sign then
            max_sign = v
            max_sign_id = id
        end
    end
    return max_sign_id
end

function drop_manager.manual_roll_item(self, drop_entity_id)
    local members_need = {}
    local members_greedy = {}
    local drop_data = self.total_drops[drop_entity_id]
    local members = drop_data.waiting_members
    for id, v in pairs(members) do
        local select = v.select
        if select == "in_need" then             --需求
            members_need[id] = v.score
        elseif select == "greedy" then         --贪婪
            members_greedy[id] = v.score
        elseif select == "give_up" then        --不要
        else
            select = select or "nil"
            flog("error", "drop_manager.manual_roll_item error select mode "..select)
        end
    end

    if table.isEmptyOrNil(members_need) then
        return drop_manager.auto_roll_item(self, members_greedy, drop_entity_id)
    else
        return drop_manager.auto_roll_item(self, members_need, drop_entity_id)
    end
end

function drop_manager.on_pick_drop(self, drop_entity_id, actor_id, team_id, mode)
    local drop_data = self.total_drops[drop_entity_id]

    if drop_data == nil then
        return const.error_drop_item_is_not_exist, true
    end
    local current_time = _get_now_time_second()
    local diff_time = current_time - drop_data.create_time
    if diff_time > DISAPPEAR_TIME then
        self.total_drops[drop_entity_id] = nil
        return const.error_drop_item_is_not_exist, true
    end
    if diff_time > PROTECT_TIME then
        drop_data.owner_id = nil
        drop_data.is_team_own = nil
    end

    if drop_data.waiting_members ~= nil then
        return const.error_drop_item_in_manual_roll, true
    end
    if drop_data.owner_id ~= nil then
        if drop_data.is_team_own then
            if team_id ~= drop_data.owner_id then
                return const.error_drop_item_in_protect_time, false
            end
        else
            if actor_id ~= drop_data.owner_id then
                return const.error_drop_item_in_protect_time, false
            end
        end
    end


    if drop_data.is_team_own then
        local item_roll_type = item_scheme[drop_data.item_id].Roll
        local roll_type
        if item_roll_type == 2 then
            roll_type = "manual_roll"
        end
        if mode == "auto" then
            roll_type = roll_type or "auto_roll"
        end
        roll_type = roll_type or "direct_get"
        if roll_type == "direct_get" then
            self.total_drops[drop_entity_id] = nil
        end

        return 0, true, roll_type, drop_data
    else
        self.total_drops[drop_entity_id] = nil
        return 0, true, "direct_get", drop_data
    end

    return 0, true, "direct_get", drop_data
end

function drop_manager.add_manual_roll_waiting_member(self, drop_entity_id, member_id)
    local drop_data = self.total_drops[drop_entity_id]
    if drop_data == nil then
        return const.error_drop_item_is_not_exist
    end

    drop_data.waiting_members = drop_data.waiting_members or {}
    drop_data.waiting_members[member_id] = {select = -1}
end

function drop_manager.gen_manual_roll_waiting_member_score(self, drop_entity_id)
    local drop_data = self.total_drops[drop_entity_id]
    if drop_data == nil then
        return
    end
    local waiting_members = drop_data.waiting_members
    if table.isEmptyOrNil(waiting_members) then
        return
    end
    local member_number = table.getnum(waiting_members)
    local score_list = get_random_n(member_number, 100)
    local i = 1
    for id, _ in pairs(waiting_members) do
        waiting_members[id] = {score = score_list[i], select = -1}
        i = i + 1
    end
end

local function _is_in_need(item_id, vocation)
    local item_attrib = item_scheme[item_id]
    if math.floor(item_attrib.Type / 100) ~= const.EQUIPMENT_HEAD then   --非装备
        return true
    end

    --判断是否满足职业要求
    local is_match = false
    local faction_in_need = equipment_base.equipTemplate[item_id].Faction
    if faction_in_need == nil then
        flog("error", "_is_in_need faction_in_need is nil")
        return false
    end

    for _, v in pairs(faction_in_need) do
        if v == vocation then
            is_match = true
            break
        end
    end
    if not is_match then
        return false
    end
    return true
end


function drop_manager.reply_manual_roll(self, drop_entity_id, actor_id, is_want, vocation)
    local drop_data = self.total_drops[drop_entity_id]
    if drop_data == nil then
        return const.error_drop_item_is_not_exist
    end
    if drop_data.waiting_members == nil then
        flog("error", "drop_manager.reply_manual_roll error_manual_roll_waiting_member_not_exsit")
        return const.error_manual_roll_waiting_member_not_exsit
    end
    local is_find = false
    local is_all_reply = true
    for id, _ in pairs(drop_data.waiting_members) do
        if id == actor_id then
            is_find = true
            local is_need = _is_in_need(drop_data.item_id, vocation)
            if not is_want then
                drop_data.waiting_members[id].select = "give_up"
            elseif is_need then
                drop_data.waiting_members[id].select = "in_need"
            else
                drop_data.waiting_members[id].select = "greedy"
            end
        end
        if drop_data.waiting_members[id].select == -1 then
            is_all_reply = false
        end
    end
    if is_find then
        return 0, is_all_reply, drop_data
    else
        flog("error", "drop_manager.reply_manual_roll error_manual_roll_waiting_member_not_exsit not find member")
        return const.error_manual_roll_waiting_member_not_exsit
    end
end


return drop_manager