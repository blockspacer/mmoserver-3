--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/6 0006
-- Time: 15:04
-- To change this template use File | Settings | File Templates.
--

local common_item = require "data/common_item"
local flog = require "basic/log"
local common_char_chinese_config = require "configs/common_char_chinese_config"

local item_configs = {}
for _,v in pairs(common_item.Item) do
    if v.OverlayNum < 1 then
        flog("error","item config error!!! OverlayNum is "..v.OverlayNum..",id "..v.ID)
    end
    item_configs[v.ID] = v
end

local function get_item_config(id)
    return item_configs[id]
end

local function get_item_configs()
    return item_configs
end

local rand_package_configs = {}
for _,v in pairs(common_item.RandBag) do
    if rand_package_configs[v.RandID] == nil then
        rand_package_configs[v.RandID] = {}
    end
    table.insert(rand_package_configs[v.RandID],v)
end

local function get_rand_item_configs(rand_item_id)
    return rand_package_configs[rand_item_id]
end

local function get_item_name(id)
    if item_configs[id] == nil then
        return ""
    end
    if item_configs[id].Name > 0 then
        return common_char_chinese_config.get_table_text(item_configs[id].Name)
    end
    return item_configs[id].Name1
end

return {
    get_item_config = get_item_config,
    get_item_configs = get_item_configs,
    get_rand_item_configs = get_rand_item_configs,
    get_item_name = get_item_name,
}

