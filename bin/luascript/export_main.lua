--------------------------------------------------------------------
-- 文件名:	
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/4/25 0025
-- 描  述:	
--------------------------------------------------------------------
package.path = package.path .. ";./luascript/?.lua;"
local db_hiredis = require "basic/db_hiredis"
local data_base = require "basic/db_mongo"

local resource_id_to_name = {
    [1] = "coin",    --银币
    [2] = "ingot",   --元宝
    [3] = "tili",    --体力
    [4] = "exp",     --经验值
    [5] = "pvp_score", --竞技币
    [6] = "silver",      --银元宝
    [7] = "dungeon_score", --副本积分
    [8] = "arena_score", --竞技场积分
    [9] = "talent_coin", --天赋铜钱
    [10] = "talent_exp",  --天赋经验
    [11] = "faction_score",--帮贡
    [12] = "bind_coin",   --绑定铜钱
    [13] = "feats",       --功勋
    [14] = "live_energy", --生活技能精力
    [15] = "faction_fund",--帮会资金
}

local file = io.open("export.csv", "w")
assert(file)

local title = {"id","昵称","等级","创建时间","职业","阵营","主线任务","1001","1002","1003","1004","1005","1006","1007",
    "1008","1009","1010","1011","1012","1013","1014","1015","主线副本","战斗力","灵力","宠物数量","最高宠物星级","最高星级宠物id",
    "战阶","爵位","离线时间","最大解锁格子","pk值","送花数","收花数","性别","账号","礼包101","礼包102","礼包103","礼包104","礼包105","礼包106",
    "礼包201", "礼包202","礼包203","礼包204","礼包205"}
local str = table.concat(title, ",")

file:write(str)
file:write("\n")

local player_last_logout_time = {}
local player_ids = {}
local actor_to_login = {}

local function _get_avatar_info(player_id, status, playerdata,callback_id)
    local actor_id = playerdata.actor_id
    if actor_id == nil then
        return
    end
    _info(playerdata.actor_name)
    local timestr = string.sub(actor_id, 1, 8)
    timestr = "0X"..timestr
    local time_table = os.date("*t", string.format("%d", timestr))
    local date_str = string.format("%d-%d-%d %d:%d:%d", time_table.year,time_table.month, time_table.day, time_table.hour, time_table.min, time_table.sec)
    local info = {}
    table.insert(info, playerdata.actor_id)
    table.insert(info, playerdata.actor_name)
    table.insert(info, playerdata.level)
    table.insert(info, date_str)
    table.insert(info, playerdata.vocation)
    table.insert(info, playerdata.country)
    local task = playerdata.task or {}
    local main_task_id = task.main_task_id or -1
    table.insert(info, main_task_id)

    local count_list = {}
    for i, v in pairs(resource_id_to_name) do
        count_list[i + 1000] = playerdata[v] or 0
    end

    for i = 1, 15 do
        table.insert(info, count_list[i + 1000])
    end

    table.insert(info, playerdata.dungeon_unlock)
    table.insert(info, playerdata.fight_power)

    local property = playerdata.property or {}
    local spritual = property[32] or 0
    table.insert(info, spritual)

    local pet_list = playerdata.pet_list or {}
    local pet_num = #pet_list
    local max_pet_star = -1
    local max_star_pet_id = -1
    for _, pet in pairs(pet_list) do
        if pet.pet_star > max_pet_star then
            max_pet_star = pet.pet_star
            max_star_pet_id = pet.pet_id
        end
    end
    table.insert(info, pet_num)
    table.insert(info, max_pet_star)
    table.insert(info, max_star_pet_id)

    table.insert(info, playerdata.war_rank)
    table.insert(info, playerdata.noble_rank)

    local logout_time = player_last_logout_time[actor_id] or -1
    if logout_time ~= -1 then
        local logout_table = os.date("*t", logout_time)
        local logout_date_str = string.format("%d-%d-%d %d:%d:%d", logout_table.year,logout_table.month, logout_table.day, logout_table.hour, logout_table.min, logout_table.sec)
        table.insert(info, logout_date_str)
    else
        table.insert(info, "online")
    end

    table.insert(info, playerdata.max_unlock_cell)
    table.insert(info, playerdata.pk_value)
    table.insert(info, playerdata.present_friend_flower_count)
    table.insert(info, playerdata.receive_friend_flower_count)
    table.insert(info, playerdata.sex)
    local user_name = actor_to_login[actor_id] or "nil"
    table.insert(info, user_name)

    local used_gift_code = playerdata.used_gift_code
    for i = 1, 6 do
        local key = 100 + i
        used_gift_code[key] = used_gift_code[key] or 0
        table.insert(info, used_gift_code[key])
    end
    for i = 1, 5 do
        local key = 200 + i
        used_gift_code[key] = used_gift_code[key] or 0
        table.insert(info, used_gift_code[key])
    end

    local str = table.concat(info, ",")

    file:write(str)
    file:write("\n")
end

local function sleep(n)
   if n > 0 then os.execute("ping -n " .. tonumber(n + 1) .. " localhost > NUL") end
end

local function _db_callback_get_actor_user_name(actor_id, status, doc)
    actor_to_login[actor_id] = doc.user_name

    local is_all_get = true
    for _, player_id in pairs(player_ids) do
        if actor_to_login[player_id] == -1 then
            is_all_get = false
            break
        end
    end

    if is_all_get then
        for _, player_id in pairs(player_ids) do
            data_base.db_find_one(player_id, _get_avatar_info, "actor_info", {actor_id = player_id}, {})
        end
    end
end


local function _db_callback_get_player_last_logout_time(_, status, doc)
    if status == 0 then
        flog("error", "_db_callback_get_player_last_logout_time: get data fail!")
        return
    end

    player_last_logout_time = doc or {}

    player_ids = db_hiredis.hkeys("actor_all")
    for _, player_id in pairs(player_ids) do
        actor_to_login[player_id] = -1
    end
    for _, player_id in pairs(player_ids) do
        data_base.db_find_one(player_id, _db_callback_get_actor_user_name, "login_info", {actor_list = {["$elemMatch"]={actor_id = player_id}}}, {})
    end
end

function OnServerStart(server_name,path)
    _info("OnServerStart")

    local conn = db_hiredis.on_connect("10.0.253.13", 9988, "syztlby")
    if conn == nil then
        _error("connect redis error!")
        assert(false)
        return
    end

    data_base.db_find_one(0, _db_callback_get_player_last_logout_time, "global_info", {info_name = "player_last_logout_time"}, {})
end

