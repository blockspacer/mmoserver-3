--------------------------------------------------------------------
-- 文件名:	imp_property.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/10
-- 描  述:	角色及怪物、npc等实体的属性
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local growing_actor = require "data/growing_actor"
local common_fight_base = require "data/common_fight_base"
local common_parameter_formula_config = require "configs/common_parameter_formula_config"

local name_to_index = const.PROPERTY_NAME_TO_INDEX

local base_move_speed = common_fight_base.Parameter[29].Value   --基础移动值
local base_fly_power = common_fight_base.Parameter[31].Value  --基础轻功值
local flying_move_speed = common_fight_base.Parameter[36].Value  --轻功状态下移动速度
local base_pet_move_speed = common_fight_base.Parameter[26].Value  --宠物基础移动速度

--宠物属性计算公式
--a表示基础属性，b表示等级，c表示资质
local formula_str = require("data/common_parameter_formula").Formula[5].Formula      --宠物攻击属性计算公式
formula_str =  "return function (a, b, c) return "..formula_str.." end"
local pet_attack_prop_func = loadstring(formula_str)()

formula_str = require("data/common_parameter_formula").Formula[6].Formula      --宠物防御属性计算公式
formula_str =  "return function (a, b, c) return "..formula_str.." end"
local pet_defence_prop_func = loadstring(formula_str)()

formula_str = require("data/common_parameter_formula").Formula[7].Formula      --宠物血量属性计算公式
formula_str =  "return function (a, b, c) return "..formula_str.." end"
local pet_hp_prop_func = loadstring(formula_str)()

formula_str = require("data/common_parameter_formula").Formula[15].Formula      --宠物血量属性计算公式
formula_str =  "return function (a, b, c) return "..formula_str.." end"
local pet_resist_prop_func = loadstring(formula_str)()

local params =
{
    physic_attack = {scheme = "PhysicAttack", intable = true},     --物理攻击
    magic_attack = {scheme = "MagicAttack", intable = true},       --魔法攻击
    physic_defence  = {scheme = "PhysicDefence", intable = true},  --物理防御
    magic_defence = {scheme = "MagicDefence", intable = true},     --魔法防御
    hp_max = {scheme = "Hp", intable = true},                          --最大生命
    mp_max = {scheme = "Mp", intable = true},                          --最大魔法
    hit = {scheme = "Hit", intable = true},                        --命中
    crit = {scheme = "Crit", intable = true},                      --暴击
    miss = {scheme = "Miss", intable = true},                      --闪避
    resist_crit = {scheme = "ResistCrit", intable = true},         --抗暴
    block = {scheme = "Block", intable = true},                    --格挡
    break_up = {scheme = "BreakUp", intable = true},               --击破
    puncture = {scheme = "Puncture", intable = true},              --穿刺
    guardian = {scheme = "Guardian", intable = true},              --守护
    move_speed = {scheme = "MoveSpeed", intable = true},           --移动速度

    gold_attack =  {intable = true},
    wood_attack =  {intable = true},
    water_attack = {intable = true},
    fire_attack =  {intable = true},
    soil_attack =  {intable = true},
    wind_attack =  {intable = true},
    light_attack = {intable = true},
    dark_attack = {intable = true},
    gold_defence = {intable = true},
    wood_defence = {intable = true},
    water_defence = {intable = true},
    fire_defence =  {intable = true},
    soil_defence =  {intable = true},
    wind_defence = {intable = true},
    light_defence = {intable = true},
    dark_defence =  {intable = true},

    fly_power = {intable = true},
    spritual = {intable = true},                    --灵力

    crit_ratio = {intable = true},                    --暴击伤害倍率
    resist_petrified = {intable = true},              --石化抗性
    ignore_resist_petrified = {intable = true},       --忽视石化抗性
    resist_stun = {intable = true},                   --眩晕抗性
    ignore_resist_stun = {intable = true},            --忽视眩晕抗性
    resist_charm = {intable = true},                  --魅惑抗性
    ignore_resist_charm = {intable = true},           --忽视魅惑抗性
    resist_fear = {intable = true},                   --恐惧抗性
    ignore_resist_fear = {intable = true},            --忽视恐惧抗性

    real_spritual = {db=true}
}

local property_name = const.BASE_PROPERTY_NAME

local imp_property = {}
imp_property.__index = imp_property

setmetatable(imp_property, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_property.__params = params

function imp_property.__ctor(self)
    self.real_spritual = 0
end

--根据dict初始化
function imp_property.imp_property_init_from_dict(self, dict)
    local property_info = table.get(dict, "property", {})

    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.intable then
            self[i] = property_info[name_to_index[i]] or 0
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
end

function imp_property.imp_property_init_from_other_game_dict(self,dict)
    self:imp_property_init_from_dict(dict)
    self.total_power = dict.total_power
end

function imp_property.imp_property_write_to_dict(self, dict)
    dict.property = {}
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        elseif v.intable then
            dict.property[name_to_index[i]] = self[i]
        end
    end
end

function imp_property.imp_property_write_to_other_game_dict(self,dict)
    self:imp_property_write_to_dict(dict)
    dict.total_power = self.total_power
end

function imp_property.imp_property_write_to_sync_dict(self, dict)
    dict.property = {}
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        elseif v.intable then
            dict.property[name_to_index[i]] = self[i]
        end
    end
    dict.fight_power = self.fight_power
    dict.total_power = self.total_power

    local puppet = self:get_puppet()
    if puppet then
        dict.spritual = puppet.spritual()
        flog("syzDebug", "self.spritual "..dict.spritual)
        dict.spritual = math.floor(dict.spritual)
    end
end

local function calculate_fight_power(self)
    local attack = self.physic_attack+self.magic_attack
    local defence = self.physic_defence + self.magic_defence
    local resist = self.hit+self.crit+self.miss+self.resist_crit+self.block+self.break_up+self.puncture+self.guardian
    local element_attack = self.gold_attack + self.wood_attack + self.water_attack + self.fire_attack + self.soil_attack + self.wind_attack + self.light_attack + self.dark_attack
    local element_defence = self.gold_defence + self.wood_defence + self.water_defence + self.fire_defence + self.soil_defence + self.wind_defence + self.light_defence + self.dark_defence
    local control = self.resist_petrified + self.resist_stun + self.resist_charm + self.resist_fear
    local ingnore_control = self.ignore_resist_petrified + self.ignore_resist_stun + self.ignore_resist_charm + self.ignore_resist_fear
    local skill_level = self:get_skill_level_sum()
    return common_parameter_formula_config.calculate_fight_power(self.hp_max,self.mp_max,attack,defence,resist,element_attack,element_defence, control, ingnore_control, skill_level)
end

local function arena_dummy_recalc(self)
    if self.hp_max > 0 then
        return
    end
    local key = string.format("%d_%d", self.level, self.vocation)
    local base_attib = growing_actor.Attribute[key]
    if base_attib == nil then
        flog("error", string.format("player_recalc: key %s not exist", key))
        return
    end
    for i, v in pairs(params) do
        if base_attib[v.scheme] ~= nil then
            self[i] = base_attib[v.scheme]
        else
            self[i] = 0
        end
    end

    self["move_speed"] = base_move_speed
    self["fly_power"] = base_fly_power
end

local function player_recalc(self)
    local old_spritual = self.spritual
    local old_hp_max = self.hp_max
    local old_mp_max = self.mp_max
    local key = string.format("%d_%d", self.level, self.vocation)
    local base_attib = growing_actor.Attribute[key]
    if base_attib == nil then
        flog("error", string.format("player_recalc: key %s not exist", key))
        return
    end
    for i, v in pairs(params) do
        if base_attib[v.scheme] ~= nil then
            self[i] = base_attib[v.scheme]
        else
            self[i] = 0
        end
    end

    self["move_speed"] = base_move_speed
    self["fly_power"] = base_fly_power

    --装备属性加成
    local property_addtion = self:get_equipment_attrib()
    for i, v in pairs(property_addtion) do
        if self[i] ~= nil then
            self[i] = self[i] + v
        else
            self[i] = v
        end
    end

    local old_spritual = self.real_spritual
    self.real_spritual = self.spritual + self.spritual_total_addition + self.spritual_weekly_addition
    if old_spritual ~= self.real_spritual then
        if self:is_in_team() then
            self:send_message_to_team_server({func_name="update_team_member_info",property_name="real_spritual",value=self.real_spritual})
        end
    end
    self.spritual = self.spritual + self.spritual_total_addition + self.spritual_weekly_addition + self:get_faction_altar_share_spritual()
    for i, v in pairs(self.pet_on_fight_entity) do
        self.spritual = self.spritual + v.pet_star
    end

    if old_spritual ~= self.spritual then
        self:update_player_info_to_arena("spritual",self.spritual)
    end

    -- 战斗力计算
    local fight_power = math.floor(calculate_fight_power(self))
    local fight_power_change = false
    if fight_power ~= self.fight_power then
        fight_power_change = true
    end
    self.fight_power = fight_power
    if self.type == const.ENTITY_TYPE_PLAYER then
        if fight_power_change then
            self:update_player_info_to_arena("fight_power",self.fight_power)
            self:update_task_when_player_fight_power_change()
        end

        self:update_player_value_to_rank_list("fight_power")
        --[[for i, v in pairs(self.pet_on_fight_entity) do
            self.total_power = self.total_power + v.fight_power
        end]]
        local first_power = 0
        local second_power = 0
        for _,pet in pairs(self.pet_list) do
            if pet.fight_power > first_power then
                if first_power > second_power then
                    second_power = first_power
                end
                first_power = pet.fight_power
            elseif pet.fight_power > second_power then
                second_power = pet.fight_power
            end
        end
        local pet_power = first_power + second_power
        self.total_power = common_parameter_formula_config.calculate_total_power(self.fight_power, self.spritual, pet_power)
        self:update_player_value_to_rank_list("total_power")
    end

    local hp_change_percent
    local mp_change_percent

    if self.hp_max ~= old_hp_max and old_hp_max ~= 0 then
        hp_change_percent = math.floor(100 * self.hp_max / old_hp_max)
    end

    if self.mp_max ~= old_mp_max and old_mp_max ~= 0 then
        mp_change_percent = math.floor(100 * self.mp_max / old_mp_max)
    end

    --暂时判断类别，竞技场假人优化时可以去掉
    if self.in_fight_server and self.type == const.ENTITY_TYPE_PLAYER then
        local output = {}
        output.func_name = "on_update_fight_avatar_property"
        output.data = {}
        self:imp_property_write_to_sync_dict(output.data)
        output.hp_change_percent = hp_change_percent
        output.mp_change_percent = mp_change_percent
        self:send_to_fight_server( const.GD_MESSAGE_LUA_GAME_RPC, output)
    end

    return hp_change_percent, mp_change_percent
end

local function monster_recalc(self)
    local key = string.format("%d_%d_%d", self.level, self.monster_power, self.monster_type)
    local base_attib = common_fight_base.Attribute[key]
    if base_attib == nil then
        flog("error", string.format("monster_recalc: key %s not exist!", key))
        return
    end
    for i, v in pairs(params) do
        if base_attib[v.scheme] ~= nil then
            self[i] = base_attib[v.scheme]
        end
    end
end

local function pet_recalc(self)
    local old_hp_max = self.hp_max
    for _, name in pairs(property_name) do
        local base_prop_name = "base_"..name
        local quality_name = name.."_quality"
        if self[base_prop_name] ~= nil then
            if name == "physic_attack" or name == "magic_attack" then
                self[name] = pet_attack_prop_func(self[base_prop_name], self.pet_level, self[quality_name])
            elseif name == "physic_defence" or name == "magic_defence" then
                self[name] = pet_defence_prop_func(self[base_prop_name], self.pet_level, self[quality_name])
            elseif name == "hp_max" then
                self[name] = pet_hp_prop_func(self[base_prop_name], self.pet_level, self[quality_name])
            else
                self[name] = pet_resist_prop_func(self[base_prop_name], self.pet_level, self[quality_name])
            end
        end
    end
    self["move_speed"] = base_pet_move_speed
    self:calc_score()
    self.fight_power = math.floor(calculate_fight_power(self))

    local hp_change_percent
    if self.hp_max ~= old_hp_max and old_hp_max ~= 0 then
        local puppet = self:get_puppet()
        if puppet ~= nil and old_hp_max ~= 0 then
            hp_change_percent = math.floor(puppet.hp * self.hp_max / old_hp_max)
        end
    end
    return hp_change_percent
end

function imp_property.recalc(self)
    local hp_change_percent
    local mp_change_percent
    if self.type == const.ENTITY_TYPE_PLAYER then
        hp_change_percent, mp_change_percent = player_recalc(self)
    elseif self.type == const.ENTITY_TYPE_PET then
        hp_change_percent = pet_recalc(self)
    elseif self.type == const.ENTITY_TYPE_ARENA_DUMMY then
        arena_dummy_recalc(self)
    else
        flog("error", string.format("imp_property.recalc: wrong type %d", self.type))
    end

    self:update_property_to_puppet(hp_change_percent, mp_change_percent)
end

function imp_property.get_property_str(self)
    local string_table = {}
    for _, name in pairs(property_name) do
        local str = string.format("%s:%d ",name, self[name])
        table.insert(string_table, str)
    end
    return table.concat(string_table)
end

return imp_property