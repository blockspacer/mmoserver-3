--------------------------------------------------------------------
-- 文件名:	item.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/08
-- 描  述:	单个道具类
--------------------------------------------------------------------
local get_chinese_text = require "basic/chinese"
local flog = require "basic/log"
local scheme_items = require "data/common_item"
local const = require "Common/constant"
local equipment_base = require "data/equipment_base"
local attrib_lib = equipment_base.ClearAttibules
local attrib_type = equipment_base.Attribute
local level_max = 99999
local scheme_param = require("data/common_parameter_formula").Parameter
local objectid = objectid

local equip_type_name = const.equip_type_to_name
local property_name_to_index = const.PROPERTY_NAME_TO_INDEX
local property_index_to_name = const.PROPERTY_INDEX_TO_NAME

--初始化元素属性表
local element_name = {"gold","wood","water","fire","soil","wind","light","dark", }
local scheme_fun = require "basic/scheme"
local create_add_up_table = scheme_fun.create_add_up_table
local get_random_index_with_weight_by_count = scheme_fun.get_random_index_with_weight_by_count

local equip_weight_table = {}
for i, v in pairs(equipment_base.ElementType) do
    local weight_table = {}
    for j, p in ipairs(element_name) do
        table.insert(weight_table, v[p])
    end
    equip_weight_table[v.part] = create_add_up_table(weight_table)
end
--产生装备元素属性
local function get_equipment_element(part_name)
    local add_up_table = equip_weight_table[part_name]
    local index = get_random_index_with_weight_by_count(add_up_table)
    return element_name[index]
end
--初始化元素属性数字累积表
local weight_table_element_value = {}
for i, v in ipairs(equipment_base.ElementValue) do
    table.insert(weight_table_element_value, v.weight)
end
local add_up_element_value = create_add_up_table(weight_table_element_value)
local function get_value_element()
    local index = get_random_index_with_weight_by_count(add_up_element_value)
    return index
end

--初始化各种装备可用属性
local usable_attrib_list = {}   --可用属性列表
for i, v in pairs(attrib_type) do
    for j, p in pairs(equip_type_name) do
        if usable_attrib_list[p] == nil then
            usable_attrib_list[p] = {}
        end

        if v[p] == 1 then
            usable_attrib_list[p][v.ID] = true
        end
    end
end

--初始化等级限制可用属性表
local level_period = {}
local index = 1
for i, v in ipairs(attrib_lib) do
    if level_period[index] == nil then
        table.insert(level_period, v.level)
    elseif level_period[index] ~= v.level then
        table.insert(level_period, v.level)
        index = index + 1
    end
end

local function get_level_limit_arrange(level_limit)
    local floor
    local top
    for i, v in ipairs(level_period) do
        if level_limit >= v then
            floor = v
        end

        if top == nil and level_limit < v then
            top = v - 1
            break
        end
    end

    if top == nil then
        top = level_max
    end

    return floor, top
end

local quality_arrange_name =
{
    [1] = {"WhiBasicRan", "WhiRareRan"},
    [2] = {"GreBasicRan", "GreRareRan"},
    [3] = {"BluBasicRan", "BluRareRan"},
    [4] = {"PurBasicRan", "PurRareRan"},
    [5] = {"GolBasicRan", "GolRareRan"},
}

local VALUE_TYPE_TEN_THOUSAND_RATIO = 1
local VALUE_TYPE_NUMBER = 2

local MAX_ADDITIONAL_PROP_NUM = 9           --最大洗练属性数目

local formula_str = require("data/common_parameter_formula").Formula[3].Formula      --随机数的策划表公式
formula_str =  "return function (a, b) return "..formula_str.." end"
local formula_func = loadstring(formula_str)()
local function formula_random(a, b)
    local randn = formula_func(a, b)
    if randn < a then
        randn = a
    elseif randn > b then
        randn = b
    end
    return randn
end

-------------------------------------------------------------------------

local item_class = {}
item_class.__index = item_class

setmetatable(item_class, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

function item_class.__ctor(self)
    self.id = 0
    self.cnt = 0
    self.attrib = nil
    self.max_cnt = 0
    self.base_prop = nil
    self.additional_prop = nil
    self.element = nil
end

function item_class.init(self)
    if self.id == nil then
        flog("error", "CreateItem init: count is nil")
        return 0
    end

    if self.cnt == nil then
        flog("error", "CreateItem init: count is nil")
        return 0
    end

    if scheme_items == nil or scheme_items.Item == nil then
        flog("error", "common_item read error!")
        return 0
    elseif scheme_items.Item[self.id] == nil then
        flog("error", "No item:"..self.id)
        return 0
    end
    self.attrib = scheme_items.Item[self.id]
    self.max_cnt = self.attrib.OverlayNum

    if self.cnt > self.max_cnt then
        self.cnt = self.max_cnt
    end

    --flog("syzDebug", "create item success"..self.id)
    return self.cnt
end

function item_class.init_from_dict(self, dict)
    self.id = dict.id
    self.uid = dict.uid
    self.cnt = dict.count
    if dict.base_prop ~= nil then
        self.base_prop = table.copy(dict.base_prop)
    end
    if dict.additional_prop ~= nil then
        self.additional_prop = table.copy(dict.additional_prop)
    end

    self.element = dict.element
    if dict.location ~= nil then
        self.location = table.copy(dict.location)
    end

    return item_class.init(self)
end

function item_class.write_to_dict(self, dict)
    dict.id = self.id
    dict.count = self.cnt
    dict.uid = self.uid

    if self.base_prop ~= nil then
        dict.base_prop = table.copy(self.base_prop)
    end
    if self.additional_prop ~= nil then
        dict.additional_prop = table.copy(self.additional_prop)
    end
    if self.element ~= nil then
        dict.element = self.element
    end
    if self.location ~= nil then
        dict.location = table.copy(self.location)
    end
end

function item_class.get_id(self)
    return self.id
end

function item_class.get_count(self)
    return self.cnt
end

function item_class.add_count(self, count)
    if count < 0 then
        flog("error", "item_class.add_count: Error add count:"..count)
        return 0
    end

    local add_num = count
    self.cnt = self.cnt + count
    if self.cnt > self.max_cnt then
        add_num = count - (self.cnt - self.max_cnt)
        self.cnt = self.max_cnt
    end
    return add_num
end

function item_class.has_enough(self, count)
    if count < 0 then
        return false
    end
    return self.cnt >= count
end

function item_class.remove_count(self, count)
    if count < 0 then
        return false
    end
    if self:has_enough(count) then
        self.cnt = self.cnt - count
        return true
    else
        return false
    end
end

function item_class.is_empty(self)
    return self.cnt <= 0
end

function item_class.get_addable_num(self)
    return self.max_cnt - self.cnt
end

function item_class.is_same_item(self, item)
    if item:get_id() ~= self.id then
        return false
    end
    --TODO: 后续会有uid、等级、宝石镶嵌等属性判断
    return true
end

function item_class._create_equipment_attrib(self)
    local equip_part_name = equip_type_name[self.attrib.Type]
    if equip_part_name == nil then
        flog("error", "this is not a equipment "..self.attrib.Type..",item id "..self.attrib.ID)
        return
    end

    self.base_prop = {}
    self.additional_prop = {}

    --基础属性
    local equip_mod = equipment_base.equipTemplate[self.id]
    for i = 1, 3 do
        local base_prop_id = equip_mod["BasicAttriID"..i]
        if base_prop_id ~= 0 then
            local attrib_range = equip_mod["AttriRange"..i]
            local logic_id = attrib_type[base_prop_id].LogicID
            self.base_prop[logic_id] = formula_random(attrib_range[1], attrib_range[2])
        end
    end

    --基础属性-元素属性
    local element_attri_pro = equip_mod.ElementAttriPro

    if element_attri_pro > 0 then
        local rand_num = math.random(100)
        if rand_num <= element_attri_pro then  --会有元素属性
            --决定是哪个元素属性
            self.element = get_equipment_element(equip_part_name)
            --计算元素数值
            local value = get_value_element()
            local prop_index = property_name_to_index[self.element.."_attack"]
            self.base_prop[prop_index] = value
        end
    end

    --洗练属性
    local clear_attri_num = math.random(equip_mod.ClearAttriMin, equip_mod.ClearAttriMax)   --随机洗练属性数目
    if clear_attri_num > MAX_ADDITIONAL_PROP_NUM then
        clear_attri_num = MAX_ADDITIONAL_PROP_NUM
    end

    local level_limit = self.attrib.LevelLimit   --物品使用等级

    local current_usable = usable_attrib_list[equip_part_name]
    local got_rare = false
    local weight_table = {}     --存放可用属性的权重
    local index_table = {}      --存放属性索引
    local total_weight = 0
    for i, v in pairs(attrib_lib) do
        local floor, top = get_level_limit_arrange(level_limit)
        if current_usable[v.AttriID] and v.level >= floor and v.level <= top then
            total_weight = total_weight + v.Weight
            table.insert(weight_table, total_weight)
            table.insert(index_table, i)
        end
    end

    for n = 1, clear_attri_num do
        if total_weight == 0 or #weight_table == 0 then
            break
        end
        --flog("syzDebug", "create_equipment_attrib: weight_table "..table.serialize(weight_table))
        --flog("syzDebug", "create_equipment_attrib: index_table "..table.serialize(index_table))

        --根据权重随机出属性
        local index = get_random_index_with_weight_by_count(weight_table)

        local attri_id = attrib_lib[index_table[index]].AttriID      --属性的id
        local logic_id = attrib_type[attri_id].LogicID      --逻辑id

        --计算属性的值
        local quality = self.attrib.Quality
        if quality_arrange_name[quality] == nil then
            flog("error", "create_equipment_attrib: no quality "..quality)
        end

        local attrib_value
        local is_rare = false
        local qindex = 0
        local rare_ratio = equipment_base.equipTemplate[self.id].RareAttriPro
        if got_rare == false and math.random(100) <= rare_ratio then    --获得珍稀属性
            got_rare = true
            is_rare = true
            qindex = 2
        else                                                             --获得普通属性
            qindex = 1
        end
        local arrange = attrib_lib[index_table[index]][quality_arrange_name[quality][qindex]]
        if arrange == nil then
            flog("error", "create_equipment_attrib: Get nil arrange --quality "..quality)
        end

        attrib_value = formula_random(arrange[1], arrange[2])

        local current_attrib_type = attrib_type[attri_id]
        local prop_index = logic_id
        table.insert(self.additional_prop, {prop_index, attrib_value, is_rare, current_attrib_type.ValueType,attri_id})

        --flog("syzDebug", "create_equipment_attrib: add "..table.serialize({prop_index, attrib_value, is_rare, current_attrib_type.ValueType}))
        --把同类型属性从随机列表中删除
        local value_type = current_attrib_type.TypeID
        total_weight = 0
        local new_weight_table = {}     --存放可用属性的权重
        local new_index_table = {}      --存放属性索引

        for _, v in ipairs(index_table) do
            local aid = attrib_lib[v].AttriID
            if value_type ~= attrib_type[aid].TypeID then
                total_weight = total_weight + attrib_lib[v].Weight
                table.insert(new_weight_table, total_weight)
                table.insert(new_index_table, v)
            end
        end

        weight_table = new_weight_table
        index_table = new_index_table
    end
end

function item_class.create_attrib(self)
    if math.floor(self.attrib.Type / 100) == const.EQUIPMENT_HEAD then   --创建装备属性
        self:_create_equipment_attrib()

        if self.attrib.Quality >= const.RARE_GOODS_LEVEL then
            self.uid = objectid()
        end
    end
end

function item_class.get_base_prop(self)
    return self.base_prop
end

function item_class.get_additional_prop(self)
    return self.additional_prop
end

function item_class.get_equipment_part_name(self)
    return equip_type_name[self.attrib.Type]
end

function item_class.is_equipable(self, level, vocation)
    if math.floor(self.attrib.Type / 100) ~= const.EQUIPMENT_HEAD then   --非装备
        return const.error_item_can_not_equip
    end

    if level < self.attrib.LevelLimit then   --未达到使用等级
        return const.error_level_not_enough
    end

    --判断是否满足职业要求
    local is_match = false
    local faction_in_need = equipment_base.equipTemplate[self.id].Faction
    if faction_in_need == nil then
        flog("error", "item_class.is_equipable faction_in_need is nil")
        return const.error_vocation_not_match
    end

    for i, v in pairs(faction_in_need) do
        if v == vocation then
            is_match = true
            break
        end
    end
    if not is_match then
        return const.error_vocation_not_match
    end

    return 0
end


--attr1被替换属性索引
--attr2替换属性数据
function item_class.refine_equip(self, attr1,attr2)
    if self.additional_prop == nil then
        self.additional_prop = {}
    end
    if attr1 == 0 then
        self.additional_prop[#self.additional_prop+1] = attr2
    else
        self.additional_prop[attr1] = attr2
    end
end

function item_class.get_max_cnt(self)
    return self.max_cnt
end

--test
if false then
    flog("syzDebug", "CreateItem Debug**********************")
    for i = 1, 10 do
        local a = CreateItem()
        a:init_from_dict({id = 2008, count = 1})
        a:create_attrib()
        local dict = {}
        a:write_to_dict(dict)
        flog("syzDebug", table.serialize(dict))
    end
end

return item_class