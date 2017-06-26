
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

local function search_user_by_name(search_string)
    local search_result = {}
    local len = string.len(search_string)
    for i,v in pairs(online_user) do
        local res = true
        local name = v:get("actor_name")
        for j = 1,len,1 do
            if string.find(name,string.sub(search_string,j,j)) == nil then
                res = false
                break
            end
        end
        if res then
            table.insert(search_result,i)
        end
    end
    return search_result
end

return {
    get_user = get_user_by_actorid,
    add_user = add_user,
    del_user = del_user,
    get_all_user = get_all_user,
    search_user_by_name = search_user_by_name,
}