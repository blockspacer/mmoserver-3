--------------------------------------------------------------------
-- 文件名:	fight_data_statistics.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/1/19 0019
-- 描  述:	战斗数据统计
--------------------------------------------------------------------
local pairs = pairs
local _get_now_time_second = _get_now_time_second
local flog = require "basic/log"

local start_time_dict = {}
local personal_data = {}

local function init_fight_data_statistics(init_data, time)
    for member_id, data in pairs(init_data) do
        personal_data[member_id] = data
        start_time_dict[member_id] = time
    end
end

local function _reset_member_data(member_id, time)
    local old_data = personal_data[member_id]
    personal_data[member_id] = {actor_name = old_data.actor_name, vocation = old_data.vocation }
    local current_time = time or _get_now_time_second()
    start_time_dict[member_id] = current_time
end

local function reset_fight_data_statistics(member_id_list)
    local current_time = _get_now_time_second()
    local rst_data = {}
    for member_id, _ in pairs(member_id_list) do
        _reset_member_data(member_id, current_time)
        rst_data[member_id] = personal_data[member_id]
    end

    return rst_data, current_time
end

local function update_fight_data_statistics(member_id, data_type, value)
    local fight_data = personal_data[member_id]
    if fight_data == nil then
        return
    end
    fight_data = personal_data[member_id]
    local total_value = fight_data[data_type] or 0
    fight_data[data_type] = total_value + value
end

local function get_fight_data_statistics(member_id_list, captain_id)
    local rst_data = {}
    for member_id, _ in pairs(member_id_list) do
        if personal_data[member_id] == nil then
            member_id = member_id or nil
            flog("error", "get_fight_data_statistics get data fail "..member_id)
            return
        end
        rst_data[member_id] = personal_data[member_id]
    end

    return rst_data, start_time_dict[captain_id]
end

local function remove_player_data(member_id)
    personal_data[member_id] = nil
end

local function add_player_data(member_id, actor_name, vocation)
    personal_data[member_id] = {actor_name = actor_name, vocation = vocation }
    _reset_member_data(member_id)
end


return {
    init_fight_data_statistics = init_fight_data_statistics,
    reset_fight_data_statistics = reset_fight_data_statistics,
    update_fight_data_statistics = update_fight_data_statistics,
    get_fight_data_statistics = get_fight_data_statistics,
    remove_player_data = remove_player_data,
    add_player_data = add_player_data,
}