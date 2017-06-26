--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/6/6 0006
-- Time: 9:44
-- To change this template use File | Settings | File Templates.
--

local common_npc = require "data/common_npc"

local transport_npc_configs = {}

local function reload()
    transport_npc_configs = {}
    for _,v in pairs(common_npc.TransportNPC) do
        transport_npc_configs[v.ID] = v
    end
end

local function get_transport_npc_config(id)
    return transport_npc_configs[id]
end

reload()

return  {
    reload = reload,
    get_transport_npc_config = get_transport_npc_config,
}