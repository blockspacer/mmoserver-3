----------------------------------------------------------------------
-- 文件名:	imp_skill.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/11/12
-- 描  述:	玩家模块，玩家特有的一些属性
--------------------------------------------------------------------
local const = require "Common/constant"
local upgrade_cost = require("data/growing_skill").UpgradeCost
local skill_moves = require("data/growing_skill").SkillMoves
local flog = require "basic/log"
local skill_unlock = require("data/growing_skill").SkillUnlock
local is_command_cool_down = require("helper/command_cd").is_command_cool_down


local params = {
    cur_plan = {db = true,sync = true, default = 1},
}

local imp_skill = {}
imp_skill.__index = imp_skill

setmetatable(imp_skill, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_skill.__params = params

function imp_skill.__ctor(self)
    self.skill_level = {}
    self.skill_plan = {}
end

--根据dict初始化
function imp_skill.imp_skill_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.skill_level = table.copy(table.get(dict, "skill_level", {1,1,1,1}))
    self.skill_plan = table.copy(table.get(dict, "skill_plan", {{},{},{}}))
end

function imp_skill.imp_skill_init_from_other_game_dict(self,dict)
    self:imp_skill_init_from_dict(dict)
end

function imp_skill.imp_skill_write_to_dict(self, dict, to_other_game)
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
    dict.skill_level = self.skill_level
    dict.skill_plan = self.skill_plan
end

function imp_skill.imp_skill_write_to_other_game_dict(self,dict)
    self:imp_skill_write_to_dict(dict, true)
end

function imp_skill.imp_skill_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
    dict.skill_level = table.copy(self.skill_level)
    dict.skill_plan = table.copy(self.skill_plan)
end

local function freshDummySkills(self,syn_data)

    if self.in_fight_server then
        local output = {}
        output.func_name = "on_update_fight_avatar_skill_info"
        output.data = syn_data
        self:send_to_fight_server( const.GD_MESSAGE_LUA_GAME_RPC, output)
    end

    local EntityManager = self:get_entity_manager()
    if not EntityManager then
        flog("info", ' find no entitymanager with entity_id = ' .. self.actor_id)
        return
    end
    local unit = EntityManager.GetPuppet(self.actor_id)
    if unit then
        self:imp_skill_write_to_sync_dict(unit.data)
        unit:RefreshSkills()
    end
end

local function on_skill_upgrade(self, input, syn_data)
    local place = input.place
    self.skill_level[place] = self.skill_level[place] or 1
    local level = self.skill_level[place]
    local key = string.format("%d_%d", place, level)
    if upgrade_cost[key] == nil then
        flog("warn", "on_skill_upgrade upgrade_cost[key] is nil")
        self:send_message(const.SC_MESSAGE_LUA_SKILL_UPGRADE , {result = const.error_impossible_param})
        return
    end

    local player_lv = upgrade_cost[key].PlayerLv
    if player_lv == nil or self.level < player_lv then
        self:send_message(const.SC_MESSAGE_LUA_SKILL_UPGRADE , {result = const.error_level_reach_ceil})
        return
    end

    local items_need = {}
    local items_lack = {}
    local is_enough = true
    for i = 1, 2 do
        local itm = upgrade_cost[key]["Cost"..i]
        if itm ~= nil then
            local item_id = itm[1]
            local count = itm[2]
            if not self:is_enough_by_id(item_id, count) then
                is_enough = false
                table.insert(items_lack, item_id)
            end
            items_need[item_id] = count
        end
    end

    if is_enough then
        --扣除材料
        for item_id, count in pairs(items_need) do
            self:remove_item_by_id(item_id, count)
        end
        self.skill_level[place] = self.skill_level[place] + 1

        self:imp_assets_write_to_sync_dict(syn_data)
        self:imp_skill_write_to_sync_dict(syn_data)
        self:send_message(const.SC_MESSAGE_LUA_SKILL_UPGRADE , {result = 0})

        -- 重新刷新技能
        freshDummySkills(self,syn_data)
        self:update_task_system_operation(const.TASK_SYSTEM_OPERATION.upgrade_skill)
    else
        self:send_message(const.SC_MESSAGE_LUA_SKILL_UPGRADE , {result = const.error_item_not_enough, items_lack = items_lack})
    end

end

local function on_skill_change(self, input, syn_data)
    local skill_id = input.skill_id
    local place = input.place
    local moves_id = self.vocation * 1000 + place   --根据职业和place计算招式组合的id
    local plan_index = self.cur_plan
    if plan_index > const.MAX_SKILL_PLAN or skill_moves[moves_id] == nil then
        flog("warn", "on_skill_change : error_impossible_param is nil, plan_index: "..plan_index.." id: "..moves_id)
        self:send_message(const.SC_MESSAGE_LUA_SKILL_CHANGE , {result = const.error_impossible_param})
        return
    end

    if self.level < skill_unlock[skill_id].PlayerLv then
        self:send_message(const.SC_MESSAGE_LUA_SKILL_CHANGE , {result = const.error_skill_not_unlock})
        return
    end

    local is_match = false
    for _, v in pairs(skill_moves[moves_id].SkillID) do
        if v == skill_id then
            is_match = true
            break
        end
    end
    if not is_match then
        flog("warn", "on_skill_change : skill id not match, place: "..place.." id: "..moves_id)
        self:send_message(const.SC_MESSAGE_LUA_SKILL_CHANGE , {result = const.error_impossible_param})
        return
    end

    self.skill_plan[plan_index] = self.skill_plan[plan_index] or {}
    self.skill_plan[plan_index][place] = skill_id
    self:imp_skill_write_to_sync_dict(syn_data)
    self:send_message(const.SC_MESSAGE_LUA_SKILL_CHANGE , {result = 0})
    self:update_task_system_operation(const.TASK_SYSTEM_OPERATION.equip_skill)

    -- 重新刷新技能
    freshDummySkills(self,syn_data)
end

local function on_plan_change(self, input, syn_data)
    local plan_index = input.plan_index

    if plan_index > const.MAX_SKILL_PLAN then
        flog("warn", "on_skill_change : error_impossible_param is nil, plan_index: "..plan_index)
        self:send_message(const.CS_MESSAGE_LUA_PLAN_SWITCH , {result = const.error_impossible_param})
        return
    end
    self.cur_plan = plan_index

    self:imp_skill_write_to_sync_dict(syn_data)
    self:send_message(const.CS_MESSAGE_LUA_PLAN_SWITCH , {result = 0})

    -- 重新刷新技能
    freshDummySkills(self,syn_data)
end


--获取升级总等级
function imp_skill.get_upgrade_skill_level(self)
    local total_level = 0
    for i=1,4,1 do
        total_level = total_level + self.skill_level[i] - 1
    end
    return total_level
end

--是否已装备技能
function imp_skill.is_equip_skill(self)
    for _,plan in pairs(self.skill_plan) do
        if not table.isEmptyOrNil(plan) then
            return true
        end
    end
    return false
end

function imp_skill.get_skill_level_sum(self)
    local total_level = 0
    for i=1,4,1 do
        total_level = total_level + self.skill_level[i]
    end
    return total_level
end

register_message_handler(const.CS_MESSAGE_LUA_SKILL_UPGRADE, on_skill_upgrade)
register_message_handler(const.CS_MESSAGE_LUA_SKILL_CHANGE, on_skill_change)
register_message_handler(const.CS_MESSAGE_LUA_PLAN_SWITCH, on_plan_change)

imp_skill.__message_handler = {}
imp_skill.__message_handler.on_skill_upgrade = on_skill_upgrade
imp_skill.__message_handler.on_skill_change = on_skill_change
imp_skill.__message_handler.on_plan_change = on_plan_change

return imp_skill