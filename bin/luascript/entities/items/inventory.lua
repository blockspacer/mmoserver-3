--------------------------------------------------------------------
-- 文件名:	inventory.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/08
-- 描  述:	道具仓库，管理item类
--------------------------------------------------------------------
local create_item = require "entities/items/item"
local const = require "Common/constant"
local flog = require "basic/log"
local math = require "math"

local level_scheme = require("data/common_levels").Level
local scheme_param = require("data/common_parameter_formula").Parameter
local INIT_CELL_SIZE = scheme_param[16].Parameter   --背包初始默认开启的格子数量
local MAX_IVENTORY_CELL = scheme_param[17].Parameter --背包最大格子数量

local unlock_cost_list = require("data/common_item").BackpackDeblocking
local item_attrib = require("data/common_item").Item
local common_item_config = require "configs/common_item_config"
local string_split = require("basic/scheme").string_split
local string_format = string.format

local resource_id_to_name = const.RESOURCE_ID_TO_NAME
local resource_name_to_id = const.RESOURCE_NAME_TO_ID

local inventory = {}
inventory.__index = inventory

setmetatable(inventory, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

function inventory.__ctor(self)
    self.items = {}
    self.resource = {}
    for _, v in pairs(resource_id_to_name) do
        self.resource[v] = 0
    end
    self.max_unlock_cell = INIT_CELL_SIZE
    self.current_unlock_cell = 0
end

function inventory.init_from_dict(self, dict)
    local dict_items = table.get(dict, "items", {})
    self.max_unlock_cell = table.get(dict, "max_unlock_cell", INIT_CELL_SIZE)
    self.current_unlock_cell = table.get(dict, "current_unlock_cell", 0)
    self.max_unlock_cell = INIT_CELL_SIZE + self.current_unlock_cell
    for i, v in pairs(dict_items) do
        local new_item = create_item()
        new_item:init_from_dict(v)
        self.items[i] = new_item
    end

    for i, v in pairs(resource_id_to_name) do
        if v == "tili" and dict[v] == nil then
            self.resource[v] = level_scheme[1].Vit
        else
            self.resource[v] = table.get(dict, v, 0)
        end
    end
end

function inventory.write_to_dict(self, dict, only_res)
    dict.items = {}
    local dict_items = dict.items
    for i, v in pairs(resource_id_to_name) do
        dict[v] = self.resource[v]
    end
    if only_res then
        return
    end

    dict.max_unlock_cell = self.max_unlock_cell
    dict.current_unlock_cell = self.current_unlock_cell
    for i, v in pairs(self.items) do
        local item_info = {}
        v:write_to_dict(item_info)
        dict_items[i] = item_info
    end
end

function inventory.get_resource_by_id(self,item_id)
    if resource_id_to_name[item_id] == nil then
        return 0
    end
    if item_id == resource_name_to_id.bind_coin then
        return self:get_resource(resource_id_to_name[item_id]) + self:get_resource_by_id(resource_name_to_id.coin)
    end
    return self:get_resource(resource_id_to_name[item_id])
end

function inventory.get_first_empty(self)
    for i = 1, self.max_unlock_cell do
        if self.items[i] == nil then
            return i
        end
    end
    return nil
end

function inventory.add_item_by_id(self, item_id, count)
    if resource_id_to_name[item_id] ~= nil then
        --flog("error", "inventory.add_item_by_id: resource type can not use this interface")
        return self:add_resource(resource_id_to_name[item_id], count)
    end

    if count == 0 then
        return 0
    elseif count < 0 then
        flog("error", "inventory.add_item_by_id: count cannot be lower than 0")
        return const.error_count_can_not_negative
    end

    --自动打开包
    local item_config = common_item_config.get_item_config(item_id)
    if item_config.Type == const.TYPE_AUTO_PACKAGE then
        local item_strings = string_split(item_config.Para1,'=')
        if #item_strings == 2 then
            return self:add_item_by_id(tonumber(item_strings[1]),tonumber(item_strings[2])*count)
        end
    end

    local last_count = count

    for i = 1, self.max_unlock_cell do
        local v = self.items[i]
        if v ~= nil then
            if v:get_id() == item_id then
                local num = v:add_count(last_count)
                if num == last_count then
                    return 0
                else
                    last_count = last_count - num
                end
            end
        end
    end

    while last_count > 0 do
        local first_empty = self:get_first_empty()
        if first_empty == nil then
            flog("syzDebug", "inventory.add_item_by_id: no empty cell")
            return const.error_no_empty_cell, last_count
        end

        local new_item = create_item()
        local num = new_item:init_from_dict({id = item_id, count = last_count})
        self.items[first_empty] = new_item
        if num == last_count then
            return 0
        else
            last_count = last_count - num
            first_empty = self:get_first_empty()
            if first_empty == nil then
                flog("syzDebug", "inventory.add_item_by_id: no empty cell")
                return const.error_no_empty_cell, last_count
            end
        end
    end
    return 0
end

function inventory.is_item_addable(self, item_id, count)
    if resource_id_to_name[item_id] ~= nil then
        return true
    end

    if count == 0 then
        return true
    elseif count < 0 then
        flog("error", "inventory.add_item_by_id: count cannot be lower than 0")
        return false
    end

    local last_count = count

    for i = 1, self.max_unlock_cell do
        local v = self.items[i]
        if v ~= nil then
            if v:get_id() == item_id then
                local num = v:get_addable_num()
                if num >= last_count then
                    return true
                else
                    last_count = last_count - num
                end
            end
        end
    end

    if last_count > 0 then
        local empty_num = self:get_empty_slot_number()

        local new_item = create_item()
        new_item:init_from_dict({id = item_id, count = last_count})
        local max_cnt = new_item:get_max_cnt()
        if last_count > empty_num * max_cnt then
            return false
        else
            return true
        end
    end
    return true
end

function inventory.add_item_by_pos(self, pos, item_id, count)
    if count == 0 then
        return 0
    elseif count < 0 then
        flog("error", "inventory.add_item_by_pos: count cannot be lower than 0")
        return const.error_count_can_not_negative
    end

    local item = self.items[pos]

    if item == nil then
        local new_item = create_item()
        local num = new_item:init_from_dict({id = item_id, count = count})
        if num < count then
            return const.error_position_not_addable
        end
        self.items[pos] = new_item
        return 0
    end

    if item:get_id() ~= item_id then
        return const.error_item_id_not_match
    end

    if item:get_addable_num() < count then
        return const.error_position_not_addable
    end
    item:add_count(count)
    return 0
end

function inventory.remove_resource_by_id(self,resource_id,count)
    if resource_id_to_name[resource_id] == nil then
        flog("error","inventory.remove_resource_by_id:resource type can not use this interface!")
    end
    if self:get_resource_by_id(resource_id) < count then
        return const.error_item_not_enough
    end
    --绑定铜钱特殊处理
    if resource_id == resource_name_to_id.bind_coin then
        if count < 0 then
            flog("error", "inventory.remove_resource_by_id: count can not < 0 --"..count)
            return const.error_count_can_not_negative
        end
        if self.resource[resource_id_to_name[resource_id]] < count then
            self:remove_resource_by_id(resource_name_to_id.coin, count - self.resource[resource_id_to_name[resource_id]])
            self.resource[resource_id_to_name[resource_id]] = 0
        else
            self.resource[resource_id_to_name[resource_id]] = self.resource[resource_id_to_name[resource_id]] - count
        end
        return 0
    end
    return self:remove_resource(resource_id_to_name[resource_id], count)
end

function inventory.remove_item_by_id(self, item_id, count, actor_id)
    if resource_id_to_name[item_id] ~= nil then
        --flog("error", "inventory.remove_item_by_id: resource type can not use this interface")
        return self:remove_resource_by_id(item_id, count)
    end

    if count == 0 then
        return 0
    elseif count < 0 then
        flog("error", "inventory.remove_item_by_id: count cannot be lower than 0")
        return const.error_count_can_not_negative
    end

    local need_count = count
    local remove_id_list = {}
    for i = 1, self.max_unlock_cell do
        local v = self.items[i]
        if v ~= nil then
            if v:get_id() == item_id then
                if v.uid ~= nil then
                    flog("salog", string_format("Equipment %d remove uid %s", v.id, v.uid), actor_id)
                end

                if v:has_enough(need_count) then
                    v:remove_count(need_count)
                    if v:is_empty() then
                        self.items[i] = nil
                    end
                    need_count = 0
                    break
                else
                    table.insert(remove_id_list, i)
                    need_count = need_count - v:get_count()
                end
            end
        end
    end

    if need_count > 0 then
        return const.error_item_not_enough
    end

    --flog("syzDebug", "inventory.remove_item_by_id: remove list:"..table.serialize(remove_id_list))

    for i, v in pairs(remove_id_list) do
        self.items[v] = nil
    end

    return 0
end

function inventory.remove_item_by_pos(self, pos, count)
    if count == 0 then
        return 0
    elseif count < 0 then
        flog("error", "inventory.remove_item_by_pos: count cannot be lower than 0")
        return count.error_count_can_not_negative
    end

    local item = self.items[pos]
    if item == nil or not item:has_enough(count) then
        return const.error_item_not_enough
    end

    item:remove_count(count)
    if item:is_empty() then
        self.items[pos] = nil
    end
    return 0
end

function inventory.get_item_by_pos(self, pos)
    return self.items[pos]
end

function inventory.get_item_by_id(self, item_id)
    if resource_id_to_name[item_id] ~= nil then
        return self:get_resource_by_id(item_id)
    end
    local item_list = {}
    for i = 1, self.max_unlock_cell do
        local v = self.items[i]
        if v ~= nil then
            if v:get_id() == item_id then
                table.insert(item_list, v)
            end
        end
    end
    return item_list
end

function inventory.clear_by_id(self, item_id)
    for i = 1, self.max_unlock_cell do
        local v = self.items[i]
        if v ~= nil then
            if v:get_id() == item_id then
                self.items[i] = nil
            end
        end
    end
end

function inventory.clear_by_pos(self, pos)
    local del_item = self.items[pos]
    self.items[pos] = nil
    return del_item
end

function inventory.get_resource(self, resource_name)
    if self.resource[resource_name] == nil then
        flog("error", "inventory.get_resource: no resource "..resource_name)
    end
    return self.resource[resource_name]
end

function inventory.add_resource(self, resource_name, count)
    if count < 0 then
        flog("warn", "inventory.add_resource: "..resource_name.." count can not < 0 --"..count)
        return const.error_count_can_not_negative
    end

    self.resource[resource_name] = self.resource[resource_name] + count
    return 0
end

function inventory.remove_resource(self, resource_name, count)
    if count < 0 then
        flog("error", "inventory.remove_resource: count can not < 0 --"..count)
        return const.error_count_can_not_negative
    end

    if self.resource[resource_name] < count then
        return const.error_item_not_enough
    end

    self.resource[resource_name] = self.resource[resource_name] - count
    return 0
end

local function sort_func(item_x, item_y)
    if item_x.attrib.SortIndex ~= item_y.attrib.SortIndex then
        return item_x.attrib.SortIndex < item_y.attrib.SortIndex
    else
        return item_x:get_id() < item_y:get_id()
    end
end

local function is_equipment(item_id)
    local attrib = item_attrib[item_id]
    if attrib == nil then
        flog("error", "is_equipment: no item "..item_id)
    end
    return math.floor(attrib.Type / 100) == const.EQUIPMENT_HEAD
end

function inventory.arrange(self)
    local old_items = self.items
    self.items = {}
    for _, v in pairs(old_items) do
        --flog("syzDebug", "id "..v:get_id().." count "..v:get_count())
        if is_equipment(v:get_id()) then
            local first_empty = self:get_first_empty()
            if first_empty == nil then
                flog("syzDebug", "inventory.arrange: no empty cell")
                break
            end

            self.items[first_empty] = v
        else
            self:add_item_by_id(v:get_id(), v:get_count())
        end
        --flog("syzDebug", "items number "..#items)
    end

    table.sort(self.items, sort_func)
    --flog("syzDebug", "items number "..#items)
    return 0
end

function inventory.add_item(self, pos, new_item)
    local item = self.items[pos]
    if item == nil then
        self.items[pos] = new_item
        return 0
    else
        return const.error_position_not_addable
    end
end


function inventory.unlock_cell(self, cell_pos)
    if cell_pos <= self.max_unlock_cell then
        return const.error_cell_unlock_already
    end
    if cell_pos > MAX_IVENTORY_CELL then
        return const.error_cell_can_not_unlock
    end

    local cost_list = {}
    for i = self.max_unlock_cell + 1, cell_pos do
        local unlock_pos = i - INIT_CELL_SIZE
        local cost = unlock_cost_list[unlock_pos]
        if cost == nil then
            flog("error", "inventory.unlock_cell : read cost error --"..unlock_pos)
            return const.error_server_error
        end

        local count = math.floor(#cost.Resoure/2)
        for j=1,count,1 do
            local res_id = cost.Resoure[2*j-1]
            local count = cost.Resoure[2*j]
            if cost_list[res_id] == nil then
                cost_list[res_id] = count
            else
                cost_list[res_id] = cost_list[res_id] + count
            end
        end
    end

    for i, v in pairs(cost_list) do
        if not self:is_enough_by_id(i, v) then
            return const.error_item_not_enough
        end
    end

    for i, v in pairs(cost_list) do
        self:remove_item_by_id(i, v)
    end

    self.max_unlock_cell = cell_pos
    self.current_unlock_cell = cell_pos - INIT_CELL_SIZE
    return 0
end

function inventory.is_resource_enough(self, resource_name, count)
    if self.resource[resource_name] == nil then
        flog("error", "inventory.is_resource_enough: no resource "..resource_name)
    end
    return self.resource[resource_name] >= count
end

function inventory.is_resource_enough_by_id(self, item_id, count)
    if resource_id_to_name[item_id] == nil then
        flog("error", "inventory.is_resource_enough_by_id : not a resource --"..item_id)
        return false
    end
    return self:get_resource_by_id(item_id) >= count
end

function inventory.is_enough_by_id(self, item_id, count)
    if resource_id_to_name[item_id] ~= nil then
        return self:is_resource_enough_by_id(item_id, count)
    end

    local total_num = 0
    for i = 1, self.max_unlock_cell do
        local v = self.items[i]
        if v ~= nil and v:get_id() == item_id then
            total_num = total_num + v:get_count()
        end
    end

    return total_num >= count
end

--添加奖励物品，包括了新装备的属性生成
function inventory.add_new_rewards(self, rewards, actor_id)
    local rst = 0
    local is_full = false
    local last_items = {}
    for i, v in pairs(rewards) do
        if is_full then
            if resource_id_to_name[i] ~= nil then
                return self:add_resource(resource_id_to_name[i], v)
            else
                last_items[i] = v
            end
        else
            local last_count = 0
            if is_equipment(i) then
                while v > 0 do
                    local first_empty = self:get_first_empty()
                    if first_empty == nil then
                        flog("syzDebug", "inventory.add_new_rewards: no empty cell")
                        rst = const.error_no_empty_cell
                        last_count = v
                        break
                    end

                    local new_item = create_item()
                    new_item:init_from_dict({id = i, count = 1})
                    new_item:create_attrib()
                    if new_item.uid ~= nil then
                        flog("salog", string_format("Equipment %d add uid %s", new_item.id, new_item.uid), actor_id)
                    end
                    self.items[first_empty] = new_item
                    v = v - 1
                end
            else
                rst, last_count = self:add_item_by_id(i, v)
            end

            if last_count ~= nil and last_count > 0 then
                last_items[i] = last_count
                is_full = true
            end
        end
    end

    return rst, last_items
end

function inventory.get_item_count_by_id(self,item_id)
    if resource_id_to_name[item_id] ~= nil then
        return self:get_resource_by_id(item_id)
    end
    local count = 0
    for i = 1, self.max_unlock_cell,1 do
        local v = self.items[i]
        if v ~= nil then
            if v:get_id() == item_id then
                count = count + v:get_count()
            end
        end
    end
    return count
end

function inventory.get_empty_slot_number(self)
    local count = 0
    for i = 1, self.max_unlock_cell,1 do
        if self.items[i] == nil then
            count = count + 1
        end
    end
    return count
end

function inventory.add_new_transport_banner(self,item_id,scene_id,posX,posY,posZ)
    local item_config = item_attrib[item_id]
    if item_config == nil or item_config.Type ~= const.TYPE_TRANSPORT_BANNER then
        return const.error_data
    end
    local first_empty = self:get_first_empty()
    if first_empty == nil then
        flog("tmlDebug", "inventory.add_new_transport_banner: no empty cell")
        return const.error_no_empty_cell
    end
    local new_item = create_item()
    new_item:init_from_dict({id = item_id, count = 1,location={scene_id=scene_id,x=posX,y=posY,z=posZ,count=tonumber(item_config.Para1)}})
    self.items[first_empty] = new_item
    return 0
end

function inventory.use_transport_banner(self,pos)
    local banner_item = self:get_item_by_pos(pos)
    if banner_item == nil then
        return const.error_no_item_in_pos
    end
    if banner_item.attrib.Type ~= const.TYPE_TRANSPORT_BANNER then
        flog("info","inventory.use_transport_banner banner_item.attrib.Type ~= const.TYPE_TRANSPORT_BANNER")
        return const.error_data
    end
    if banner_item.location == nil then
        flog("info","inventory.use_transport_banner banner_item.location == nil")
        return const.error_data
    end
    if banner_item.location.count == nil then
        flog("info","inventory.use_transport_banner banner_item.location.count == nil")
        return const.error_data
    end
    if banner_item.location.count > 1 then
        banner_item.location.count = banner_item.location.count - 1
    else
        self:remove_item_by_pos(pos,1)
    end
    return 0,banner_item.location.scene_id,banner_item.location.x,banner_item.location.y,banner_item.location.z
end

if false then
    flog("syzDebug", "test CreateInventory ................")
    local test_inventory = inventory()
    test_inventory:add_item_by_id(4001, 25)
    test_inventory:remove_item_by_id(4001, 2)
    test_inventory:add_item_by_id(2001, 10)
    local dict = {}
    test_inventory:write_to_dict(dict)
    flog("syzDebug", "test CreateInventory 1:"..table.serialize(dict))

    test_inventory:remove_item_by_id(2001, 5)
    dict = {}
    test_inventory:write_to_dict(dict)
    flog("syzDebug", "test CreateInventory 2:"..table.serialize(dict))

    local item_list = test_inventory:get_item_by_id(2001)
    flog("syzDebug", "test CreateInventory 3:"..table.serialize(item_list))

    test_inventory:add_item_by_id(1001, 1000000)
    test_inventory:add_resource("coin", 1000000)
    dict = {}
    test_inventory:write_to_dict(dict)
    flog("syzDebug", "test CreateInventory 4:"..table.serialize(dict))

    test_inventory:remove_item_by_id(1001, 1000000)
    test_inventory:remove_resource("coin", 999999)
    dict = {}
    test_inventory:write_to_dict(dict)
    flog("syzDebug", "test CreateInventory 5:"..table.serialize(dict))

end

return inventory