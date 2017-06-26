--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/24 0024
-- Time: 15:51
-- To change this template use File | Settings | File Templates.
--
local common_level = require "data/common_levels"

local levels = {}
for _,level in pairs(common_level.Level) do
    levels[level.Level] = level
end

local function get_level_config(level)
    return levels[level]
end

return{
    get_level_config = get_level_config,
}

