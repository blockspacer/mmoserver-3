--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/15 0015
-- Time: 13:58
-- To change this template use File | Settings | File Templates.
--
local table = table
local string = string
local flog = require "basic/log"
local string2utf8 = require("basic/scheme").string2utf8

local online_user = {}
local char_actorids_table = {}

local function get_user_by_actorid( actor_id )
    return online_user[actor_id]
end

local function decode_user_name(actor_name,actor_id)
    local chars = string2utf8(actor_name)
    for i=1,#chars,1 do
        if char_actorids_table[chars[i]] == nil then
            char_actorids_table[chars[i]] = {}
        end

        local already_include = false
        for j=1,#char_actorids_table[chars[i]],1 do
            if char_actorids_table[chars[i]][j] == actor_id then
                already_include = true
                break
            end
        end
        if not already_include then
            table.insert(char_actorids_table[chars[i]],actor_id)
        end
    end
end

local function remove_user_name_for_search(actor_name,actor_id)
    local chars = string2utf8(actor_name)
    for i=1,#chars,1 do
        if char_actorids_table[chars[i]] ~= nil then
            for j=#char_actorids_table[chars[i]],1,-1 do
                if char_actorids_table[chars[i]][j] == actor_id then
                    table.remove(char_actorids_table[chars[i]],j)
                end
            end
        end
    end
end

local function add_user( actor_id, user)
    online_user[actor_id] = user
    --解析玩家名字以备搜索
    decode_user_name(user.actor_name,actor_id)
end

local function del_user( actor_id)
    --一般玩家搜索的频率比玩家上下线的频率底,这里没有移除只在开服初期有小影响
    --if online_user[actor_id] ~= nil then
    --remove_user_name_for_search(online_user[actor_id].actor_name,actor_id)
    --end
    online_user[actor_id] = nil
end

local function get_all_user()
    return online_user
end

local function search_user_by_name(search_string)
    local search_result = {}
    local utf8table = string2utf8(search_string)
    for i=1,#utf8table,1 do
        if char_actorids_table[utf8table[i]] ~= nil then
            for j = 1,#char_actorids_table[utf8table[i]],1 do
                search_result[char_actorids_table[utf8table[i]][j]] = true
            end
        end
    end
    return search_result
end

local function update_player_offlinetime(actor_id,offlinetime)
    for _,actor in pairs(online_user) do
        actor:imp_global_friend_update_offlinetime(actor_id,offlinetime)
    end
end

local function player_change_name(actor_name,actor_id,old_name)
    remove_user_name_for_search(old_name,actor_id)
    --解析玩家名字以备搜索
    decode_user_name(actor_name,actor_id)
end

return {
    get_user = get_user_by_actorid,
    add_user = add_user,
    del_user = del_user,
    get_all_user = get_all_user,
    search_user_by_name = search_user_by_name,
    update_player_offlinetime = update_player_offlinetime,
    player_change_name = player_change_name,
}

