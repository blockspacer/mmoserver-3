--------------------------------------------------------------------
-- 文件名:	imp_player_stall_market.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/6/29 0029
-- 描  述:	玩家商店（包括摆摊和商铺）
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/flog"
local system_player_shop_config = require "configs/system_player_shop_config"
local center_server_manager = require "center_server_manager"

local params = {
    max_stall_cell = {db = true,sync = true, default = 0},  --最大摊位栏位数
    stall_state_time = {db = false,sync = false, default = -1},  --开始摆摊时间
    stall_puppet_id = {db = false,sync = false, default = ""},  --
}

local imp_player_stall_market = {}
imp_player_stall_market.__index = imp_player_stall_market

setmetatable(imp_player_stall_market, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_player_stall_market.__params = params

function imp_player_stall_market.__ctor(self)
    self.stall_cell = {}
end

--根据dict初始化
function imp_player_stall_market.imp_player_stall_market_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.stall_cell = dict.stall_cell
end

function imp_player_stall_market.imp_player_stall_market_init_from_other_game_dict(self,dict)
    self:imp_player_stall_market_init_from_dict(dict)
end

function imp_player_stall_market.imp_player_stall_market_write_to_dict(self, dict, to_other_game)
    if to_other_game then
        for i, _ in pairs(params) do
            dict[i] = self[i]
        end
    else
        for i, v in pairs(params) do
            if v.db then
                dict[i] = self[i]
            end
        end
    end
    dict.stall_cell = self.stall_cell
end

function imp_player_stall_market.imp_player_stall_market_write_to_other_game_dict(self,dict)
    self:imp_player_stall_market_write_to_dict(dict, true)
end

function imp_player_stall_market.imp_player_stall_market_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
    dict.stall_cell = self.stall_cell
end

function imp_player_stall_market.on_start_stall(self, input)
    local current_time = _get_now_time_second()
    local output = {func_name = "StartStallRet", result = 0}
    if self.stall_state_time ~= -1 then
        output.result = const.error_stall_is_already_start
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end
    local stall_cost = system_player_shop_config.stall_cost
    if not self:is_enough_by_id(stall_cost.item_id, stall_cost.count) then
        output.result = const.error_item_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
    --todo: create aoi entity
    --local x,y,z = captain:get_pos()

    self:remove_item_by_id(stall_cost.item_id, stall_cost.count)
    self.stall_state_time = current_time

    self:send_message_to_shop_server(output)
end

function imp_player_stall_market.on_stall_shelves_goods(self, input)
    local item_id = input.item_id
    local count = input.count
    local item_pos = input.item_pos
    local price_type = input.price_type
    local single_price = input.single_price
    local output = {func_name = "StallShelvesGoods", result = 0 }
    local inventory_cell = self:get_item_by_pos(item_pos)
    if price_type ~= const.RESOURCE_NAME_TO_ID.coin or price_type ~= const.RESOURCE_NAME_TO_ID.ingot then
        output.result = const.error_stall_price_type_error
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    if inventory_cell.id ~= item_id then
        output.result = const.error_item_id_not_match
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    if self.stall_state_time == -1 then
        output.result = const.error_stall_is_not_start_yet
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
    end

    if not inventory_cell:has_enough(count) then
        output.result = const.error_item_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    local empty_index
    for i = 1, self.max_stall_cell do
        if self.stall_cell[i] == nil then
            empty_index = i
            break
        end
    end
    if empty_index == nil then
        output.result = const.error_no_empty_stall_cell
    end

    local goods_data = inventory_cell:pack_part_item(count)
    self:remove_item_by_pos(item_id, count)
    self.stall_cell[empty_index] = {goods_data = goods_data, price_type = price_type, single_price = single_price}
    return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
end

function imp_player_stall_market.on_get_player_stall_goods(self, input)
    local stall_owner_id = input.stall_owner_id
    local rpc_data = {func_name = "show_my_stall_goods" }
    rpc_data.actor_id = stall_owner_id
    rpc_data.buyer_id = self.actor_id
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_GAME_RPC_TRANSPORT,rpc_data)
end

function imp_player_stall_market.show_my_stall_goods(self, input)
    local buyer_id = input.buyer_id
    local rpc_data = {func_name = "get_player_stall_goods" }
    rpc_data.actor_id = buyer_id
    rpc_data.stall_cell = self.stall_cell
    rpc_data.max_stall_cell = self.max_stall_cell
    center_server_manager.send_message_to_center_server(const.SERVICE_TYPE.friend_service, const.SG_MESSAGE_CLIENT_RPC_TRANSPORT, rpc_data)
end

local function _close_stall(self)
    self.stall_state_time = -1

    --remove puppet
end

function imp_player_stall_market.on_close_stall(self, input)
    _close_stall(self)
end

function imp_player_stall_market.on_stall_off_shelf(self, input)
    local index = input.index

end

return imp_player_stall_market