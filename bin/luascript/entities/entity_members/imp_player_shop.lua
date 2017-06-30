--------------------------------------------------------------------
-- 文件名:	imp_player_shop.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/6/29 0029
-- 描  述:	玩家商店（包括摆摊和商铺）
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/flog"
local system_player_shop = require "configs/system_player_shop"

local params = {
    max_stall_cell = {db = true,sync = true, default = 0},  --最大摊位栏位数
    stall_state_time = {db = false,sync = false, default = -1},  --开始摆摊时间
}

local imp_player_shop = {}
imp_player_shop.__index = imp_player_shop

setmetatable(imp_player_shop, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_player_shop.__params = params

function imp_player_shop.__ctor(self)
    self.stall_cell = {}
end

--根据dict初始化
function imp_player_shop.imp_player_shop_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
end

function imp_player_shop.imp_player_shop_init_from_other_game_dict(self,dict)
    self:imp_player_shop_init_from_dict(dict)
    self.stall_state_time = dict.stall_state_time
end

function imp_player_shop.imp_player_shop_write_to_dict(self, dict, to_other_game)
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
end

function imp_player_shop.imp_player_shop_write_to_other_game_dict(self,dict)
    self:imp_player_shop_write_to_dict(dict, true)
end

function imp_player_shop.imp_player_shop_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
end

function imp_player_shop.on_start_stall(self, input)
    local current_time = _get_now_time_second()
    if self.stall_state_time ~= -1 then
    end
end


return imp_player_shop