
local server_config = nil
local json = require "basic/json"

local function init(path)
    local file = io.open(path,"r")
    if file == nil then
        _error("can not find server.config!!! "..path)
        assert(false)
    end
    local file_string = file:read("*a")
    file:close()
    server_config = json.decode(file_string)
    return server_config
end

local function get_server_config()
    return server_config
end

return {
    init = init,
    get_server_config = get_server_config,
}