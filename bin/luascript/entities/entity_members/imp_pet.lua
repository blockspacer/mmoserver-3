----------------------------------------------------------------------
-- 文件名:	imp_pet.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/10/08
-- 描  述:	宠物模块，宠物特有的一些属性
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"

local scheme_fun = require "basic/scheme"
local create_add_up_table = scheme_fun.create_add_up_table
local get_random_index_with_weight_by_count = scheme_fun.get_random_index_with_weight_by_count
local get_open_day = scheme_fun.get_open_day
local growing_pet = require("data/growing_pet")
local pet_attrib = growing_pet.Attribute
local hp_grow_table = growing_pet.HpGrow
local skill_up_table = growing_pet.Skillup
local scheme_field_unlock = growing_pet.SkillnumUnlock
local scheme_devour_random = growing_pet.Devourpro
local level_scheme = require("data/common_levels").Level
local growing_pet_config = require "configs/growing_pet_config"
local get_pet_config = growing_pet_config.get_pet_config
local common_fight_base_config = require "configs/common_fight_base_config"

local math_random = math.random
local math_floor = math.floor
local appearance_scheme = growing_pet.Shape
local get_config_name = require("basic/scheme").get_config_name
local _get_now_time_second = _get_now_time_second

local skill_num_init_weight = {}
for i, v in pairs(growing_pet.Skillnum) do
    skill_num_init_weight[i] = v.Weight
end

local skill_field_weight_array = create_add_up_table(skill_num_init_weight)

--初始化宠物资质\初始属性评分表
local property_scheme_table = growing_pet.TypeGrow
local property_score_table = {}
for _, v in ipairs(property_scheme_table) do
    local prop_name = const.PET_PROPERTY_TYPE_TO_NAME[v.Type]
    property_score_table[prop_name] = property_score_table[prop_name] or {}
    table.insert(property_score_table[prop_name], v)
end

--初始化产出表
local output_pet_scheme = growing_pet.OutputPet
local base_prop_output_index = {}
local quality_output_index = {}
local hp_output_index = {}
for _, v in ipairs(output_pet_scheme) do
    if v.Type == 1 then
        if base_prop_output_index[v.Label] == nil then
            base_prop_output_index[v.Label] = {}
        end
        table.insert(base_prop_output_index[v.Label], v)
    elseif v.Type == 2 then
        if quality_output_index[v.Label] == nil then
            quality_output_index[v.Label] = {}
        end
        table.insert(quality_output_index[v.Label], v)
    elseif v.Type == 3 then
        if hp_output_index[v.Label] == nil then
            hp_output_index[v.Label] = {}
        end
        table.insert(hp_output_index[v.Label], v)
    end
end
local function _get_from_output_index(open_day, output_index)
    local index
    for i, v in ipairs(output_index) do
        if open_day < v.OpenDay then
            index = i - 1
            break
        end
    end
    if index == nil then
        index = #output_index
    end
    if index < 1 or index > #output_index then
        flog("error", "_get_from_output_index: index error "..index)
    end
    return output_index[index]
end


local function get_property_score(prop_name, rate)
    local score_table = property_score_table[prop_name]
    if score_table == nil then
        return 0
    end

    local index
    for i, v in ipairs(score_table) do
        if rate <= v.NatureLower then
            break
        end
        index = i
    end
    if index == nil then
        index = #score_table
    end
    local data = score_table[index]
    return data.Score * (rate - data.NatureLower) + data.TotalScore
end


local params = {
    base_physic_attack = {scheme = "PhysicAttack", intable = "base"},     --基础物理攻击
    base_magic_attack = {scheme = "MagicAttack", intable = "base"},       --基础魔法攻击
    base_physic_defence  = {scheme = "PhysicDefence", intable = "base"},  --基础物理防御
    base_magic_defence = {scheme = "MagicDefence", intable = "base"},     --基础魔法防御
    base_hp_max = {scheme = "Hp", intable = "base"},                          --基础最大生命
    base_hit = {scheme = "Hit", intable = "base"},                        --基础命中
    base_crit = {scheme = "Crit", intable = "base"},                      --基础暴击
    base_miss = {scheme = "Miss", intable = "base"},                      --基础闪避
    base_resist_crit = {scheme = "ResistCrit", intable = "base"},         --基础抗暴
    base_block = {scheme = "Block", intable = "base"},                    --基础格挡
    base_break_up = {scheme = "BreakUp", intable = "base"},               --基础击破
    base_puncture = {scheme = "Puncture", intable = "base"},              --基础穿刺
    base_guardian = {scheme = "Guardian", intable = "base"},              --基础守护

    physic_attack_quality = {scheme = "PhyAttQuality", intable = "quality"},             --物理攻击资质
    magic_attack_quality = {scheme = "MagAttQuality", intable = "quality"},              --魔法攻击资质
    physic_defence_quality = {scheme = "PhyDefQuality", intable = "quality"},            --物理防御资质
    magic_defence_quality = {scheme = "MagDefQuality", intable = "quality"},             --魔法防御资质
    hp_max_quality = {scheme = "HpQuality", intable = "quality"},                            --最大生命资质
    hit_quality = {scheme = "HitQuality", intable = "quality"},                          --命中资质
    crit_quality = {scheme = "CritQuality", intable = "quality"},                        --暴击资质
    miss_quality = {scheme = "MissQuality", intable = "quality"},                        --闪避资质
    resist_crit_quality = {scheme = "ResistCritQuality", intable = "quality"},           --抗暴资质
    block_quality = {scheme = "BlockQuality", intable = "quality"},                      --格挡资质
    break_up_quality = {scheme = "BreakUpQuality", intable = "quality"},                 --击破资质
    puncture_quality = {scheme = "PunctureQuality", intable = "quality"},                --穿刺资质
    guardian_quality = {scheme = "GuardianQuality", intable = "quality"},                --守护资质

    pet_level = {db = true,sync = true, default = 1},               --宠物等级
    pet_id = {db = true,sync = true, default = 1},                  --宠物id
    pet_score = {db = true, sync = true,},                          --宠物评分
    pet_name = {db = true, sync = true,},                                                   --宠物名字
    pet_star = {db = true, sync = true,},                           --宠物星级
    entity_id = {db = true, sync = true,},                          --entity id,唯一标识符
    skill_field_num = {db = true,sync = true, default = 2},         --技能解锁栏位
    owner_id = {sync = true },                                      --拥有者id
    fight_index = {db = true,sync = true, default = -1},             --宠物出战索引
    current_hp = {db = true, sync = true},          --血量
    highest_property_rank = {db = true,sync = true, default = -1},    --最高的属性排名
    pet_score_rank = {db = true,sync = true, default = -1},       --宠物评分排名
    pet_appearance = {db = true,sync = true, default = 1},       --宠物外观
    output_type = {db=true,sync=true,default=1 },
    fight_power = {db=true,sync=true},                              --战斗力
    pet_exp = {db=true,sync=true},                                      --经验值
    devour_times = {db=true,sync=true},                                 --吞噬次数
    merge_times = {db=true,sync=true},                                 --融合次数

    score_debug_detail = {db=true, sync=false, default = ""}                         --分数详细计算信息
}

local property_name = const.BASE_PROPERTY_NAME

local basic_property_name = {
    physic_attack = true,
    magic_attack = true,
    physic_defence = true,
    magic_defence = true,
    }

local in_score_property = {
    "base_physic_attack",                --基础物理攻击
    "base_magic_attack",                 --基础魔法攻击
    "base_physic_defence",               --基础物理防御
    "base_magic_defence",                --基础魔法防御
    "physic_attack_quality",             --物理攻击资质
    "magic_attack_quality",              --魔法攻击资质
    "physic_defence_quality",            --物理防御资质
    "magic_defence_quality",             --魔法防御资质
}

local base_name_to_index = const.BASE_NAME_TO_INDEX
local quality_name_to_index = const.QUALITY_NAME_TO_INDEX

local SEVEN_DAYS_SECS = 604800                  --七天秒数
local THIRTY_DAYS_SECS = 2592000                --三十天秒数
local ONE_HUNDRED_YEARS_SECS = 3153600000       --一百年的秒数，作为永久购买时间
local TIME_FOREVER = const.TIME_FOREVER

local imp_pet = {}
imp_pet.__index = imp_pet

setmetatable(imp_pet, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_pet.__params = params

function imp_pet.__ctor(self)
    self.skill_info = {}
    property_score_table = property_score_table
    self.appearance_expire_time = {0, 0, 0}     --宠物外观失效时间
end

function imp_pet.imp_pet_init_from_dict(self, dict)

    local base_info = table.get(dict, "base", {})
    local quality_info = table.get(dict, "quality", {})
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.intable == "base" then
            self[i] = base_info[base_name_to_index[i]] or 0
        elseif v.intable == "quality" then
            self[i] = quality_info[quality_name_to_index[i]] or 0
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.appearance_expire_time = table.copy(dict.appearance_expire_time) or {0,0,0}

    self.skill_info = {}
    dict.skill_info = dict.skill_info or {}
    for i, v in pairs(dict.skill_info) do
        self.skill_info[i] = {id = v[1], level = v[2], type = v[3]}
    end
end

function imp_pet.imp_pet_write_to_dict(self, dict)
    dict.base = {}
    dict.quality = {}
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        elseif v.intable == "base" then
            dict.base[base_name_to_index[i]] = self[i]
        elseif v.intable == "quality" then
            dict.quality[quality_name_to_index[i]] = self[i]
        end
    end

    dict.appearance_expire_time = self.appearance_expire_time

    dict.skill_info = {}
    for i, v in pairs(self.skill_info) do
        dict.skill_info[i] = {v.id, v.level, v.type}
    end
end

function imp_pet.imp_pet_write_to_sync_dict(self, dict)
    dict.quality = {}
    dict.base = {}
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        elseif v.intable == "base" then
            dict.base[base_name_to_index[i]] = self[i]
        elseif v.intable == "quality" then
            dict.quality[quality_name_to_index[i]] = self[i]
        end
    end

    dict.appearance_expire_time = self.appearance_expire_time

    dict.skill_info = {}
    for i, v in pairs(self.skill_info) do
        dict.skill_info[i] = {v.id, v.level, v.type}
    end
    dict.dead_time = self.dead_time
    dict.rebirth_time = self.rebirth_time
end

function imp_pet.calc_score(self)
    --计算血量资质评分
    local pet_attrib_this = pet_attrib[self.pet_id]
    if pet_attrib_this == nil or pet_attrib_this.HpQuality == 0 then
        flog("error", "imp_pet.calc_score : pet_attrib_this.HpQuality cannot be 0")
    end

    if pet_attrib_this.HpQuality == 0 then
        flog("error", "pet_attrib_this.HpQuality is 0")
    end
    local hp_quality_rate = self.hp_max_quality * 100 / pet_attrib_this.HpQuality
    if hp_quality_rate < 0 then
        flog("error", "imp_pet.calc_score : hp_quality_rate less than 0")
    end

    local hp_grow
    for i, v in ipairs(hp_grow_table) do
        if v.HpLower > hp_quality_rate then
            hp_grow = hp_grow_table[i - 1]
            break
        end
    end
    if hp_grow == nil then
        hp_grow = hp_grow_table[#hp_grow_table]
    end
    local quality_score = math.floor((hp_quality_rate - hp_grow.HpLower) * hp_grow.Score + hp_grow.TotalScore)
    self.score_debug_detail = "hp_quality_score: "..quality_score

    local score_info_table = {}
    --计算资质评分/初始属性评分
    local floor = math_floor
    for v, _ in pairs(basic_property_name) do
        local base_prop_name = "base_"..v
        local base_value = pet_attrib_this[params[base_prop_name].scheme]
        if base_value <= 0 then
            flog("error", string.format("pet base attrib error %s : %d", base_prop_name, base_value))
        end
        local base_rate = self[base_prop_name] / base_value
        base_rate = floor(base_rate * 100)
        local base_score = get_property_score(base_prop_name, base_rate)

        local quality_name = v.."_quality"
        local quality_value = pet_attrib_this[params[quality_name].scheme]
        if quality_value <= 0 then
            flog("error", string.format("pet quality attrib error %s : %d", quality_name, quality_value))
        end
        local quality_rate = self[quality_name] / quality_value
        quality_rate = floor(quality_rate * 100)
        local property_score = get_property_score(quality_name, quality_rate)
        quality_score = quality_score + base_score + property_score

        local score_info = string.format(" | %s: %d | %s: %d", base_prop_name, base_score, quality_name, property_score)
        table.insert(score_info_table, score_info)
    end
    self.score_debug_detail = self.score_debug_detail..table.concat(score_info_table)

    --计算稀有度评分
    local rare_score = pet_attrib[self.pet_id].Rarity

    self.score_debug_detail = string.format("%s | rare_score: %d", self.score_debug_detail, rare_score)

    self.pet_score = quality_score + rare_score
    self.pet_star = math_floor(self.pet_score / 100)
end

local function _get_random_property(create_type, output_config, p_name, pet_id)
    local low_name = "Lowest"..create_type
    local high_name = "Highest"..create_type

    local c = output_config[low_name]
    local d = output_config[high_name]
    local MAX_RAND = 10000
    local k = math_random(MAX_RAND)
    k = k / MAX_RAND
    k = k * k * k
    local rate = k * (d - c) + c
    local rst = pet_attrib[pet_id][params[p_name].scheme] * rate / 100
    return math_floor(rst)
end


local function _create_base_property(self, open_day, create_type)
    create_type = create_type or "A"

    local total_num = #in_score_property
    local rand_prop_name = in_score_property[math_random(total_num)]
    local pet_id = self.pet_id

    for _, v in pairs(property_name) do
        local base_prop_name = "base_"..v
        local quality_name = v.."_quality"
        if basic_property_name[v] then
            local base_prop_output = _get_from_output_index(open_day, base_prop_output_index[self.output_type])
            if base_prop_name == rand_prop_name and create_type == "B" then
                self[base_prop_name] = _get_random_property("B", base_prop_output, base_prop_name, pet_id)
            else
                self[base_prop_name] = _get_random_property("A", base_prop_output, base_prop_name, pet_id)
            end

            local quality_output = _get_from_output_index(open_day, quality_output_index[self.output_type])
            if quality_name == rand_prop_name and create_type == "B" then
                self[quality_name] = _get_random_property("B", quality_output, quality_name, pet_id)
            else
                self[quality_name] = _get_random_property("A", quality_output, quality_name, pet_id)
            end
        else
            local pet_config = get_pet_config(self.pet_id)
            self[base_prop_name] = pet_config[params[base_prop_name].scheme] or 0
            self[quality_name] = pet_config[params[quality_name].scheme] or 0
        end
    end

    local prop_output = _get_from_output_index(open_day, hp_output_index[self.output_type])
    local hp_prop_name = {"base_hp_max", "hp_max_quality" }
    for _, prop_name in pairs(hp_prop_name) do
        self[prop_name] = _get_random_property("A", prop_output, prop_name, pet_id)
    end

    self:recalc()
end

local function _create_base_skill(self)
    local self_attrib = pet_attrib[self.pet_id]
    local min_num = self_attrib.SkillNumMin
    local max_num = self_attrib.SkillNumMax
    self.skill_field_num = get_random_index_with_weight_by_count(skill_field_weight_array, max_num, min_num - 1)
    self.skill_info[1] = {id = self_attrib.skill, level = 1, type = const.PET_SKILL_ACTIVE_TYPE}        --主动技能
end

function imp_pet.create_new_pet(self, create_type)
    local open_day = get_open_day()
    _create_base_property(self, open_day, create_type)
    _create_base_skill(self)

    self.pet_name = get_config_name(pet_attrib[self.pet_id])
end


function imp_pet.get_advantage_property(self, other_pet)
    local adv_property = {}
    for v, _ in pairs(basic_property_name) do
        local base_prop_name = "base_"..v
        if self[base_prop_name] > other_pet[base_prop_name] then
            table.insert(adv_property, base_prop_name)
        end

        local quality_name = v.."_quality"
        if self[quality_name] > other_pet[quality_name] then
            table.insert(adv_property, quality_name)
        end
    end

    return adv_property
end


function imp_pet.upgrade(self, new_level)
    if new_level == nil then
        self.pet_level = self.pet_level + 1
    else
        self.pet_level = new_level
    end
    self:recalc()

    local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:SetLevel(self.pet_level)
    end
end

function imp_pet.get_skill_info(self, index)
    return self.skill_info[index]
end

function imp_pet.pet_skill_upgrade(self, index, self_skill_index, book_skill_id, book_skill_type, study_mode)
    if study_mode == "study" then
        if index == nil then
            local first_empty_index
            for i = 1, self.skill_field_num do
                if self.skill_info[i] == nil then
                    first_empty_index = i
                    break
                end
            end
            if first_empty_index ~= nil then
                self.skill_info[first_empty_index] = {id = book_skill_id, level = 1, type = book_skill_type }
            else
                flog("error", "pet_skill_upgrade : first_empty_index is empty!")
            end
            return first_empty_index
        else
            self.skill_info[index] = {id = book_skill_id, level = 1, type = book_skill_type}
            return index
        end
    elseif study_mode == "upgrade" then
        self.skill_info[self_skill_index].level = self.skill_info[self_skill_index].level + 1
        return self_skill_index
    else
        flog("pet_skill_upgrade : error study_mode "..study_mode)
    end
end

function imp_pet.pet_skill_upgrade_cost(self, index, book_id, book_skill_id, skill_type, study_mode)
    if index ~= nil and index > self.skill_field_num then
        return const.error_pet_field_not_unlock
    end

    local self_skill_index
    for i, v in pairs(self.skill_info) do
        if v ~= nil and v.id == book_skill_id then
            self_skill_index = i
            break
        end
    end

    local skill_level = 0
    if study_mode == "study" then
        if index == 1 then
            return const.error_pet_unique_skill_can_not_replace
        end
        if self_skill_index ~= nil then
            return const.error_pet_skill_already_learn
        else
            if skill_type == const.PET_SKILL_ACTIVE_TYPE then
                return const.error_pet_active_skill_can_not_learn
            end
            if index == nil then
                local first_empty_index
                for i = 1, self.skill_field_num do
                    if self.skill_info[i] == nil then
                        first_empty_index = i
                        break
                    end
                end
                if first_empty_index == nil then
                    return const.error_pet_skill_no_field_to_learn
                end
            end

            skill_level = 0
        end
    elseif study_mode == "upgrade" then
        if self_skill_index ~= nil then
            skill_level = self.skill_info[self_skill_index].level
        else
            return const.error_pet_skill_not_learn
        end
    else
        flog("error", "pet_skill_upgrade_cost : error study_mode "..study_mode)
        return const.error_impossible_param
    end


    local scheme_cost = skill_up_table[skill_level + 1]
    if scheme_cost == nil then
        return const.error_pet_skill_level_max
    end
    local total_cost = {}
    total_cost[book_id] = scheme_cost.SkillBook

    local common_cost = scheme_cost.cost
    local length = #common_cost
    if length < 0 or length % 2 ~= 0 then
        flog("error", "pet_skill_upgrade_cost: error common_cost length :"..length)
    end
    for i = 1, length - 1, 2 do
        total_cost[common_cost[i]] = common_cost[i+1]
    end

    return 0, total_cost, self_skill_index
end

function imp_pet.pet_field_unlock_cost(self)
    --local self_attrib = pet_attrib[self.pet_id]
    local common_cost = scheme_field_unlock[self.skill_field_num].Item
    if self.skill_field_num >= const.MAX_PET_SKILL_FIELD or common_cost == nil then
        return const.error_pet_field_num_max
    end

    local total_cost = {}
    local length = #common_cost
    if length < 0 or length % 2 ~= 0 then
        flog("error", "pet_skill_upgrade_cost: error common_cost length :"..length)
    end
    for i = 1, length - 1, 2 do
        total_cost[common_cost[i]] = common_cost[i+1]
    end
    return 0, total_cost
end

function imp_pet.random_field_unlock(self, action_type)
    local scheme_unlock = scheme_field_unlock[self.skill_field_num]
    if scheme_unlock == nil then
        return false
    end
    local rate = scheme_unlock[action_type]
    if rate == nil then
        flog("error", "random_field_unlock: error action_type "..action_type)
        return false
    end
    local rand_num = math_random(10000)
    if rand_num < rate then
        return true
    end
    return false
end

function imp_pet.field_unlock(self)
    if self.skill_field_num < const.MAX_PET_SKILL_FIELD then
        self.skill_field_num = self.skill_field_num + 1
    else
        return false
    end
    return true, self.skill_field_num
end

function imp_pet.devour_random_skill_upgrade(self, assist_pet)
    local same_skill_index_array = {}
    for i, v in pairs(self.skill_info) do
        for j, k in pairs(assist_pet.skill_info) do
            if v.id == k.id then
                table.insert(same_skill_index_array, i)
            end
        end
    end

    local upgrade_array = {}
    for _, v in pairs(same_skill_index_array) do
        repeat
            local scheme_unlock = scheme_devour_random[self.skill_info[v].level]
            if scheme_unlock == nil then
                break
            end
            local rate = scheme_unlock.Devourpro
            local rand_num = math_random(10000)
            if rand_num < rate then
                table.insert(upgrade_array, v)
            end
        until(true)
    end
    return upgrade_array
end

function imp_pet.set_owner_id(self,owner_id)
    self.owner_id = owner_id
end

function imp_pet.add_skill_level(self, index, add_num)
    add_num = add_num or 1
    self.skill_info[index].level = self.skill_info[index].level + add_num
    return true
end

function imp_pet.change_pet_appearance(self, appearance_rank)
    appearance_rank = appearance_rank or 1
    if appearance_rank < 1 or appearance_rank > 3 then
        flog("error", "change_pet_appearance: appearance_rank wrong "..appearance_rank)
    end
    self.pet_appearance = appearance_rank
end

function imp_pet.pet_appearance_buyable(self, appearance_rank)
    appearance_rank = appearance_rank or 1
    if appearance_rank < 2 or appearance_rank > 3 then
        flog("error", "change_pet_appearance: appearance_rank wrong "..appearance_rank)
    end
    local config = appearance_scheme[appearance_rank]
    if self.pet_level < config.UnlockLv then
        return const.error_pet_level_not_enough
    end

    if self.appearance_expire_time[appearance_rank] > TIME_FOREVER then
        return const.error_already_buy_forever
    end

    return 0
end

function imp_pet.is_pet_appearance_available(self, appearance_rank)
    appearance_rank = appearance_rank or 1
    if appearance_rank < 1 or appearance_rank > 3 then
        flog("error", "change_pet_appearance: appearance_rank wrong "..appearance_rank)
    end

    if appearance_rank == 1 then
        return true
    end
    local current_time = _get_now_time_second()
    local config = appearance_scheme[appearance_rank]
    if self.pet_level < config.UnlockLv then
        return false
    end

    if self.appearance_expire_time[appearance_rank] > current_time then
        return true
    end

    if self.highest_property_rank ~= -1 and self.highest_property_rank <= config.PropertyRanking then
        return true
    end

    if self.pet_score_rank ~= -1 and self.pet_score_rank <= config.StarRanking then
        return true
    end

    return false
end

function imp_pet.get_pet_appearance_cost(self, appearance_rank, time_mode)
    appearance_rank = appearance_rank or 1
    if appearance_rank < 2 or appearance_rank > 3 then
        flog("error", "get_pet_appearance_cost: appearance_rank wrong "..appearance_rank)
    end

    local config = appearance_scheme[appearance_rank]

    local cost_config
    if time_mode == "7days" then
        cost_config = config.Buy7Days
    elseif time_mode == "30days" then
        cost_config = config.Buy30Days
    elseif time_mode == "permanent" then
        cost_config = config.PermanentPurchase
    else
        time_mode = time_mode or "nil"
        flog("error", "get_pet_appearance_cost error time_mode "..time_mode)
    end
    local cost = {}
    cost[cost_config[1]] = cost_config[2]
    return cost
end

function imp_pet.buy_pet_appearance_success(self, appearance_rank, time_mode)
    appearance_rank = appearance_rank or 1
    if appearance_rank < 2 or appearance_rank > 3 then
        flog("error", "buy_pet_appearance_success: appearance_rank wrong "..appearance_rank)
    end

    local current_time = _get_now_time_second()
    local start_count_time = self.appearance_expire_time[appearance_rank]
    if self.appearance_expire_time[appearance_rank] < current_time then
        start_count_time = current_time
    end

    if time_mode == "7days" then
        self.appearance_expire_time[appearance_rank] = start_count_time + SEVEN_DAYS_SECS
    elseif time_mode == "30days" then
        self.appearance_expire_time[appearance_rank] = start_count_time + THIRTY_DAYS_SECS
    elseif time_mode == "permanent" then
        self.appearance_expire_time[appearance_rank] = start_count_time + ONE_HUNDRED_YEARS_SECS
    else
        time_mode = time_mode or "nil"
        flog("error", "buy_pet_appearance_success error time_mode "..time_mode)
    end
end

function imp_pet.on_get_owner(self)
    local scene = self:get_scene()
    if scene == nil then
        return
    end
    return scene:get_entity(self.owner_id)
end

function imp_pet.is_pet_upgradeable(self, player_level)
    if self.pet_level >= player_level + 5 then   --大于人物等级5级不升级
        return false
    end
    return true
end

function imp_pet.get_exp(self, exp, player_level)
    local is_level_changed = false
    if not self:is_pet_upgradeable(player_level) then
        return is_level_changed
    end

    local exp = self.pet_exp + exp
    local level_exp = level_scheme[self.pet_level].PetExp
    local level = self.pet_level
    while exp > level_exp do
        exp = exp - level_exp
        level = level + 1
        level_exp = level_scheme[level].PetExp
        if not self:is_pet_upgradeable(player_level) then
            break
        end
    end

    self.pet_exp = exp
    if level ~= self.pet_level then
        self:upgrade(level)
        is_level_changed = true
    end
    return is_level_changed
end

function imp_pet.entity_die(self,killer_id)
    self.dead_time = _get_now_time_second()
    self.rebirth_time = self.dead_time + common_fight_base_config.get_pet_rebirth_time()
    local scene = self:get_scene()
    if scene ~= nil then
        local owner = scene:get_entity(self.owner_id)
        --竞技场假人不处理宠物复活?
        if owner ~= nil and owner.pet_die ~= nil then
            owner:pet_die(self.entity_id,self.dead_time,self.rebirth_time)
        end
    end
end

function imp_pet.get_rebirth_time(self)
    return self.rebirth_time
end

function imp_pet.reset_rebirth_time(self)
    self.rebirth_time = nil
    self.dead_time = nil
end

function imp_pet.get_skill_level_sum(self)
    local total_level = 0
    for i, v in pairs(self.skill_info) do
        total_level = total_level + v.level
    end
    return total_level
end

return imp_pet