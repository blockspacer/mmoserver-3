--------------------------------------------------------------------
-- 文件名:	entity_common.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/1/20 0020
-- 描  述:	entity公用的一些函数
--------------------------------------------------------------------
local flog = require "basic/log"
local string_sub = string.sub
local getmetatable = getmetatable

-- 初始化entity模块
local function create_entity_module(self, func_table, entity_part_list, parent_func_table, parent_part_list)
    parent_part_list = parent_part_list or {}
    for _, name in ipairs(parent_part_list) do
        local module_name = "entities/parent_members/"..name
        local module = require(module_name)()

        if not module then
            flog("error", "parent part "..name.." create fail")
        end

        for i, v in pairs(module) do
            self[i] = v
        end
        local moudule_metatable = getmetatable(module)
        for i, v in pairs(moudule_metatable) do
            if string_sub(i,1,2) ~= "__" then
                parent_func_table[i] = v
            end
        end
    end

    for _, name in ipairs(entity_part_list) do
        local module_name = "entities/entity_members/"..name
        local module = require(module_name)()

        if not module then
            flog("error", "entity_part "..name.." create fail")
        end

        for i, v in pairs(module) do
            self[i] = v
        end
        local moudule_metatable = getmetatable(module)
        for i, v in pairs(moudule_metatable) do
            if string_sub(i,1,2) ~= "__" then
                func_table[i] = v
            end
        end
    end
end

local function init_all_module_from_dict(self, dict, func_table, entity_part_list)
    --初始化模块数据
    for _, v in ipairs(entity_part_list) do
        if func_table[v.."_init_from_dict"] ~= nil then
            func_table[v.."_init_from_dict"](self, dict)
        end
    end
end

local function get_parent_func(self, func_name)
    return getmetatable(getmetatable(self)).__index[func_name]
end

return {
    create_entity_module = create_entity_module,
    init_all_module_from_dict = init_all_module_from_dict,
    get_parent_func = get_parent_func,
}
