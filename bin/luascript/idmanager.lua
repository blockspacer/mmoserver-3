
local game_id = 0
local global_id = 1
local redis_callback_id = 1

local function get_valid_uid()
    return objectid()
end

local function get_callback_id()
	game_id = game_id + 2
	return game_id
end

local function get_global_callback_id()
	global_id = global_id + 2
	return global_id
end

local function get_redis_callback_id()
	redis_callback_id = redis_callback_id + 1
	return redis_callback_id
end

local ret
local function chose_server(server_name)
	if server_name == "global" then
		ret.get_callback_id = get_global_callback_id
	else
		ret.get_callback_id = get_callback_id
	end
end

ret = {
	get_valid_uid = get_valid_uid,
	get_callback_id = get_callback_id,
	chose_server = chose_server,
	get_redis_callback_id = get_redis_callback_id,
}

return ret