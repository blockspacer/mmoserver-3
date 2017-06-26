--------------------------------------------------------------------
-- 文件名:	pet_rank.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/8 0008
-- 描  述:	宠物排行榜
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local data_base = require "basic/db_mongo"
local base_name_to_index = const.BASE_NAME_TO_INDEX
local quality_name_to_index = const.QUALITY_NAME_TO_INDEX
local timer = require "basic/timer"
local create_rank_list = require("global_ranking/basic_rank_list").create_rank_list
local update_rank_list = require("global_ranking/basic_rank_list").update_rank_list
local get_rank_info = require("global_ranking/basic_rank_list").get_rank_info
local remove_rank_info = require("global_ranking/basic_rank_list").remove_rank_info
local write_to_syn_data = require("global_ranking/basic_rank_list").write_to_syn_data
local MAX_RECORD_NUM_IN_PET_LIST = const.MAX_RECORD_NUM_IN_PET_LIST
local pet_attrib = require("data/growing_pet").Attribute
local pairs = pairs
local math_huge = math.huge

local DATABASE_TABLE_NAME = "rank_info_2"

local pet_rank_list = {}
local pet_rank_timer
local is_prepare_close = false
local close_hash = {}

local base_property_name = {
    "base_physic_attack",                --基础物理攻击
    "base_magic_attack",                 --基础魔法攻击
    "base_physic_defence",               --基础物理防御
    "base_magic_defence",                --基础魔法防御
    "base_hp_max",                       --基础最大生命
}

local quality_property_name =
{
    "physic_attack_quality",             --物理攻击资质
    "magic_attack_quality",              --魔法攻击资质
    "physic_defence_quality",            --物理防御资质
    "magic_defence_quality",             --魔法防御资质
    "hp_max_quality",                    --最大生命资质
}

local function _db_callback_update_pet_rank(pet_id, status,callback_id)
    flog("info", string.format("_db_callback_update_pet_rank pet_id %d, prepare close: %s", pet_id, tostring(is_prepare_close)))
    if status == 0 then
        flog("error", "_db_callback_update_pet_rank: set data fail!")
        return
    end

    if is_prepare_close then
        close_hash[pet_id] = nil
        flog("info", "pet_rank close_hash "..table.serialize(close_hash))
        if table.isEmptyOrNil(close_hash) then
            RankingUserManageReadyClose("pet_rank")
        end
    end
end

local function _write_to_database()
    flog("info", "pet rank _write_to_database")
    for pet_id, rank_list in pairs(pet_rank_list) do
        local rank_name = 'pet_rank'..pet_id
        rank_list.rank_name = rank_name
        data_base.db_update_doc(pet_id, _db_callback_update_pet_rank, DATABASE_TABLE_NAME, {rank_name = 'pet_rank'..pet_id}, rank_list, 1, 0)
    end
end


local function _db_callback_get_pet_rank(id, status, doc)
    if status == 0 then
        flog("error", "_db_callback_get_pet_rank: get data fail!")
        return
    end
    pet_rank_list = pet_rank_list or {}
    pet_rank_list[id] = table.copy(doc) or {}
end

local function _get_data_from_database()
    for id, _ in pairs(pet_attrib) do
        data_base.db_find_one(id, _db_callback_get_pet_rank, DATABASE_TABLE_NAME, {rank_name = 'pet_rank'..id}, {})
    end
end

local function on_server_start()
    _get_data_from_database()
    if pet_rank_timer == nil then
        pet_rank_timer = timer.create_timer(_write_to_database, 290000, const.INFINITY_CALL)
    end
end

local function on_server_stop()
    is_prepare_close = true
    for pet_id, rank_list in pairs(pet_rank_list) do
        close_hash[pet_id] = true
    end

    _write_to_database()
end


local function update_to_pet_rank_list(base, quality, pet_score, pet_id, owner_name, owner_id, entity_id, pet_name)
    pet_rank_list[pet_id] = pet_rank_list[pet_id] or {}
    local current_rank_list = pet_rank_list[pet_id]

    local property_table = {
        {base_property_name, base, base_name_to_index},
        {quality_property_name, quality,quality_name_to_index}
    }

    local highest_property_rank = math_huge
    for _, list in pairs(property_table) do
        local property_name = list[1]
        local property_data = list[2]
        local name_to_index = list[3]
        for _, rank_name in pairs(property_name) do
            if current_rank_list[rank_name] == nil then
                current_rank_list[rank_name] = create_rank_list(rank_name, "value", MAX_RECORD_NUM_IN_PET_LIST, "id")
            end

            local value = property_data[name_to_index[rank_name]]
            local new_record = {}
            new_record.value = value
            new_record.owner_name = owner_name
            new_record.owner_id = owner_id
            new_record.id = entity_id
            new_record.pet_name = pet_name
            local index = update_rank_list(current_rank_list[rank_name], new_record)
            index = index or math_huge
            if index < highest_property_rank then
                highest_property_rank = index
            end
        end
    end
    if highest_property_rank == math_huge then
        highest_property_rank = -1
    end

    if current_rank_list.pet_score == nil then
        current_rank_list.pet_score = create_rank_list("pet_score", "value", MAX_RECORD_NUM_IN_PET_LIST, "id")
    end
    local value = pet_score
    local new_record = {}
    new_record.value = value
    new_record.owner_name = owner_name
    new_record.owner_id = owner_id
    new_record.id = entity_id
    new_record.pet_name = pet_name
    local pet_score_rank = update_rank_list(current_rank_list.pet_score, new_record)
    pet_score_rank = pet_score_rank or -1

    if pet_score_rank ~= -1 or highest_property_rank ~= -1 then
        --_write_to_database()
    end
    return highest_property_rank, pet_score_rank
end

local function get_pet_rank_list(pet_id, rank_name)
    local current_rank_list = pet_rank_list[pet_id] or {}
    local single_list = current_rank_list[rank_name] or {}
    local rank_data = {}
    write_to_syn_data(single_list, rank_data)
    return rank_data
end

local function get_pet_rank_info(pet_id, entity_id)
    pet_rank_list[pet_id] = pet_rank_list[pet_id] or {}
    local current_rank_list = pet_rank_list[pet_id]

    local property_table = {
        base_property_name,
        quality_property_name,
    }

    local highest_property_rank = math_huge
    for _, property_name in pairs(property_table) do
        for _, rank_name in pairs(property_name) do
            if current_rank_list[rank_name] ~= nil then
                local index = get_rank_info(current_rank_list[rank_name], entity_id)
                index = index or math_huge
                if index < highest_property_rank then
                    highest_property_rank = index
                end
            end
        end
    end
    if highest_property_rank == math_huge then
        highest_property_rank = -1
    end

    local pet_score_rank
    if current_rank_list.pet_score ~= nil then
        pet_score_rank = get_rank_info(current_rank_list.pet_score, entity_id)
    end
    pet_score_rank = pet_score_rank or -1
    return highest_property_rank, pet_score_rank
end

local function get_pet_rank_with_rank_name(pet_id, entity_id, rank_name)
    pet_rank_list[pet_id] = pet_rank_list[pet_id] or {}
    local current_rank_list = pet_rank_list[pet_id]
    local rank = -1
    if current_rank_list[rank_name] ~= nil then
        rank = get_rank_info(current_rank_list[rank_name], entity_id)
    end
    return rank
end

local function remove_pet_info_from_list(pet_id, entity_id)
    pet_rank_list[pet_id] = pet_rank_list[pet_id] or {}
    local current_rank_list = pet_rank_list[pet_id]

        local property_table = {
        base_property_name,
        quality_property_name,
    }

    for _, property_name in pairs(property_table) do
        for _, rank_name in pairs(property_name) do
            if current_rank_list[rank_name] ~= nil then
                remove_rank_info(current_rank_list[rank_name], entity_id)
            end
        end
    end

    if current_rank_list.pet_score ~= nil then
        remove_rank_info(current_rank_list.pet_score, entity_id)
    end

    _write_to_database()
end


return {
    on_server_start = on_server_start,
    on_server_stop = on_server_stop,
    update_to_pet_rank_list = update_to_pet_rank_list,
    get_pet_rank_list = get_pet_rank_list,
    get_pet_rank_info = get_pet_rank_info,
    get_pet_rank_with_rank_name = get_pet_rank_with_rank_name,
    remove_pet_info_from_list = remove_pet_info_from_list,
}