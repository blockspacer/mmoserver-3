--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/7 0007
-- Time: 18:55
-- To change this template use File | Settings | File Templates.
--

local growing_skill = require "data/growing_skill"

local buff_configs = {}

for _,v in pairs(growing_skill.Buff) do
    buff_configs[v.ID] = v
end

local function get_buff_config(buff_id)
    return buff_configs[buff_id]
end

return {
    get_buff_config = get_buff_config,
}