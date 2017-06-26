--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/26 0026
-- Time: 15:15
-- To change this template use File | Settings | File Templates.
--

local common_system_list = require "data/common_system_list"

local common_system_list_configs = {}
for _,v in pairs(common_system_list.system) do
    common_system_list_configs[v.ID] = v
end

local function reload()
    common_system_list_configs = {}
    for _,v in pairs(common_system_list.system) do
        common_system_list_configs[v.ID] = v
    end
end

local function check_unlock(system_id,level)
    if common_system_list_configs[system_id] ~= nil then
        return common_system_list_configs[system_id].level <= level
    end
    return false
end

return {
    reload = reload,
    check_unlock = check_unlock,
}