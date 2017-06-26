--------------------------------------------------------------------
-- 文件名:	shop_player.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/2/6
-- 描  述:	国家成员
--------------------------------------------------------------------
local net_work = require "basic/net"
local send_to_game = net_work.forward_message_to_game
local send_to_client = net_work.send_to_client
local const = require "Common/constant"
local flog = require "basic/log"
local send_to_global = net_work.forward_message_to_global
local shop_all_server = require "global_shop/shop_all_server"
local wander_shop = require "global_shop/wander_shop"
local onlineuser = require "global_shop/shop_online_user"

local shop_player = {}
shop_player.__index = shop_player

setmetatable(shop_player, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function shop_player.__ctor(self)
end


function shop_player.on_shop_player_init(self, input)
    self.session_id = tonumber(input.session_id)
    self.actor_id = input.actor_id
    return true
end

function shop_player.on_shop_player_logout(self,input)
    onlineuser.del_user(input.actor_id)
end

function shop_player.on_message(self, key_action, input)
    if key_action == const.GS_MESSAGE_LUA_GAME_RPC then
        local func_name = input.func_name
        if func_name == nil or self[func_name] == nil then
            func_name = func_name or "nil"
            flog("error", "shop_player.on_message GS_MESSAGE_LUA_GAME_RPC: no func_name  "..func_name)
            return
        end
        flog("info", "GS_MESSAGE_LUA_GAME_RPC func_name "..func_name)
        self[func_name](self, input)
    end
end

function shop_player.ingot_shop_buy(self, input)
    local actor_id = input.actor_id
    local shop_item_id = input.shop_item_id
    local count = input.count
    local on_activity = input.on_activity
    local price = input.price
    local result = shop_all_server.ingot_shop_buy(actor_id, shop_item_id, count, on_activity)
    if result ~= 0 then
        return send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "IngotShopBuyRet", result = result})
    end

    send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {func_name = "on_ingot_shop_buy_end", result = 0, shop_item_id=shop_item_id, count=count, price=price,actor_id=self.actor_id})
end

function shop_player.get_ingot_shop_info(self, input)
    input.func_name = "GetIngotShopInfoRet"
    local item_buy_num, group_buy_num = shop_all_server.get_ingot_shop_info()
    input.total_item_buy_num = item_buy_num
    input.group_buy_num = group_buy_num
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_GAME_RPC, input)
end

function shop_player.wander_shop_buy(self, input)
    local cell = input.cell
    local count = input.count
    local index = input.index
    local price = input.price

    local result, wander_list = wander_shop.wander_buy(cell, count, index)
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_WANDER_BUY , {result = result, wander_list = wander_list})
    if result == 0 then
        send_to_game(input.game_id, const.OG_MESSAGE_LUA_GAME_RPC, {func_name = "wander_buy_end", result = 0, index=index, count=count, price=price,actor_id=self.actor_id})
    end
end

function shop_player.wander_hold(self, input)
    local expire_time = input.expire_time
    local wander_list = wander_shop.get_wander_list()
    send_to_client(self.session_id, const.SC_MESSAGE_LUA_WANDER_HOLD , {result = 0, wander_list = wander_list, expire_time = expire_time})
end

function shop_player.gm_wander_appear(self, input)
    local debug = input.debug
    wander_shop.gm_wander_appear(debug)
end

shop_player.on_player_session_changed = require("helper/global_common").on_player_session_changed

return shop_player