--------------------------------------------------------------------
-- 文件名:	common_sa_config_config.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/4/12 0012
-- 描  述:	common_sa_config配置文件
--------------------------------------------------------------------
local common_sa_config_original = require "data/common_sa_config".server
local recreate_scheme_table_with_key = require("basic/scheme").recreate_scheme_table_with_key
local common_sa_config = recreate_scheme_table_with_key(common_sa_config_original, "ServerID")

local function get_server_config(server_id)
    return common_sa_config[server_id]
end


return {
    get_server_config = get_server_config,
}