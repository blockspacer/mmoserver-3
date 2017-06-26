--------------------------------------------------------------------
-- 文件名:	faction_global_data.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/23 0023
-- 描  述:	帮会的全局数据
--------------------------------------------------------------------
local data_base = require "basic/db_mongo"
local GLOBAL_DATABASE_TABLE_NAME = "global_info"
local const = require "Common/constant"
local flog = require "basic/log"

local player_faction_index = {}
local player_last_logout_time = {}
local faction_ranking = {{}, {} }

local is_prepare_close = false
local close_hash = {
    player_faction_index = true,
    player_last_logout_time = true,
    faction_ranking = true,
}
local function is_ready_close(info_name)
    if is_prepare_close then
        if info_name ~= nil then
            close_hash[info_name] = nil
        end

        if table.isEmptyOrNil(close_hash) then
            FactionUserManageReadyClose()
        end
    end
end


local GLOBAL_INIT_TABLE = {
    player_faction_index = false,
    player_last_logout_time = false,
    faction_ranking = false,
}

local function _db_callback_update_data(info_name, status)
    if status == 0 then
        flog("error", "faction_global_data.lua _db_callback_update_data: set data fail!")
        return
    end
    is_ready_close(info_name)
end

local function save_global_data()
    player_faction_index.info_name = "player_faction_index"
    data_base.db_update_doc(player_faction_index.info_name, _db_callback_update_data, GLOBAL_DATABASE_TABLE_NAME, {info_name = "player_faction_index"}, player_faction_index, 1, 0)
    player_last_logout_time.info_name = "player_last_logout_time"
    data_base.db_update_doc(player_last_logout_time.info_name, _db_callback_update_data, GLOBAL_DATABASE_TABLE_NAME, {info_name = "player_last_logout_time"}, player_last_logout_time, 1, 0)
    faction_ranking.info_name = "faction_ranking"
    data_base.db_update_doc(faction_ranking.info_name, _db_callback_update_data, GLOBAL_DATABASE_TABLE_NAME, {info_name = "faction_ranking"}, faction_ranking, 1, 0)
end


local function _is_data_finish_initalize()
    for i, v in pairs(GLOBAL_INIT_TABLE) do
        if v == false then
            return false
        end
    end
    return true
end

local function _db_callback_get_player_faction_index(callback, status, doc)
    if status == 0 then
        flog("error", "_db_callback_get_player_faction_index: get data fail!")
        return
    end

    player_faction_index = doc or {}
    GLOBAL_INIT_TABLE.player_faction_index = true

    if _is_data_finish_initalize() then
        callback()
    end
end

local function _db_callback_get_player_last_logout_time(callback, status, doc)
    if status == 0 then
        flog("error", "_db_callback_get_player_last_logout_time: get data fail!")
        return
    end

    player_last_logout_time = doc or {}
    GLOBAL_INIT_TABLE.player_last_logout_time = true

    if _is_data_finish_initalize() then
        callback()
    end
end

local function _db_callback_get_faction_ranking(callback, status, doc)
    if status == 0 then
        flog("error", "_db_callback_get_player_last_logout_time: get data fail!")
        return
    end

    faction_ranking = doc
    if table.isEmptyOrNil(faction_ranking) then
        faction_ranking = {{}, {}}
    end

    GLOBAL_INIT_TABLE.faction_ranking = true

    if _is_data_finish_initalize() then
        callback()
    end
end


local function on_server_start(finish_all_callback)
    data_base.db_find_one(finish_all_callback, _db_callback_get_player_faction_index, GLOBAL_DATABASE_TABLE_NAME, {info_name = "player_faction_index"}, {})
    data_base.db_find_one(finish_all_callback, _db_callback_get_player_last_logout_time, GLOBAL_DATABASE_TABLE_NAME, {info_name = "player_last_logout_time"}, {})
    data_base.db_find_one(finish_all_callback, _db_callback_get_faction_ranking, GLOBAL_DATABASE_TABLE_NAME, {info_name = "faction_ranking"}, {})
end

local function on_server_stop()
    is_prepare_close = true
    save_global_data()
end

local function get_player_faction_index()
    return player_faction_index
end

local function get_player_last_logout_time()
    return player_last_logout_time
end

local function get_faction_ranking()
    return faction_ranking
end

return {
    get_player_faction_index = get_player_faction_index,
    get_player_last_logout_time = get_player_last_logout_time,
    get_faction_ranking = get_faction_ranking,
    save_global_data = save_global_data,
    on_server_start = on_server_start,
    on_server_stop = on_server_stop,
}