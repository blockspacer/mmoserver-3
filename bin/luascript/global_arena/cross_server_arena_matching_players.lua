--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/4/26 0026
-- Time: 16:32
-- To change this template use File | Settings | File Templates.
--

local matching_players = {}

local function get_user( actor_id )
    return matching_players[actor_id]
end

local function add_user( actor_id, user)
    matching_players[actor_id] = user
end

local function del_user( actor_id)
    matching_players[actor_id] = nil
end

local function get_all_user()
    return matching_players
end

return {
    get_user = get_user,
    add_user = add_user,
    del_user = del_user,
    get_all_user = get_all_user,
}



