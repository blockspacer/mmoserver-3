--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/17 0017
-- Time: 16:43
-- To change this template use File | Settings | File Templates.
--

local online_user = {}

local function get_user_by_actorid( actor_id )
    return online_user[actor_id]
end

local function add_user( actor_id, user)
    online_user[actor_id] = user
end

local function del_user( actor_id)
    online_user[actor_id] = nil
end

local function get_all_user()
    return online_user
end

return {
    get_user = get_user_by_actorid,
    add_user = add_user,
    del_user = del_user,
    get_all_user = get_all_user,
}

