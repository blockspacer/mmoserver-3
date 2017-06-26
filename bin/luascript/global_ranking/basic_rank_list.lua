--------------------------------------------------------------------
-- 文件名:	basic_rank_list.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/8 0008
-- 描  述:	基础排行榜
--------------------------------------------------------------------
local flog = require "basic/log"

local function create_rank_list(rank_name, sort_key, max_list_num, id_key)
    local rank_list = {}
    rank_list.rank_name = rank_name
    rank_list.sort_key = sort_key
    rank_list.max_list_num = max_list_num
    rank_list.id_key = id_key
    rank_list.rank_data = {}
    rank_list.index_data = {}
    return rank_list
end

local function update_rank_list(rank_list, new_record)
    local rank_name = rank_list.rank_name
    local sort_key = rank_list.sort_key
    local max_list_num = rank_list.max_list_num
    local rank_data = rank_list.rank_data
    local id_key = rank_list.id_key
    local index_data = rank_list.index_data
    if new_record[sort_key] == nil then
        flog("error", "update_rank_list: sort_key is nil, rank_name "..rank_name)
    end

    local obsolete_record
    local index
    local list_length = #rank_data
    local new_id = new_record[id_key]
    if new_id == nil then
        flog("error", "update_rank_list: id_key is nil, rank_name "..rank_name)
    end

    if index_data[new_id] ~= nil then
        index = index_data[new_id]
    elseif list_length < max_list_num then
        index = list_length + 1
        rank_data[index] = new_record
    elseif new_record[sort_key] > rank_data[max_list_num][sort_key] then
        obsolete_record = rank_data[max_list_num]
        index_data[obsolete_record[id_key]] = nil

        index = max_list_num
        rank_data[max_list_num] = new_record
    end

    if index ~= nil then
        for i = index - 1, 1 , -1 do
            if new_record[sort_key] > rank_data[i][sort_key] then
                local temp = rank_data[i]
                rank_data[i] = new_record
                rank_data[i + 1] = temp
                index = i
                index_data[temp[id_key]] = i + 1
            else
                break
            end
        end
    end
    index_data[new_id] = index

    return index, obsolete_record
end

local function get_rank_info(rank_list, id)
    local index_data = rank_list.index_data
    return index_data[id]
end

local function remove_rank_info(rank_list, id)
    local index_data = rank_list.index_data
    local rank_data = rank_list.rank_data
    local id_key = rank_list.id_key
    if index_data[id] ~= nil then
        local index = index_data[id]
        index_data[id] = nil
        local length = #rank_data

        for i = index, length - 1 do
            rank_data[i] = rank_data[i + 1]
            local r_id = rank_data[i + 1][id_key]
            index_data[r_id] = i
        end
        table.remove(rank_data, length)
    end
end

local function write_to_syn_data(rank_list, dict)
    dict.rank_data = rank_list.rank_data
    dict.rank_name = rank_list.rank_name
end

return {
    create_rank_list = create_rank_list,
    update_rank_list = update_rank_list,
    get_rank_info = get_rank_info,
    write_to_syn_data = write_to_syn_data,
    remove_rank_info = remove_rank_info,
}