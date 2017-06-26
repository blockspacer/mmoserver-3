--------------------------------------------------------------------
-- 文件名:	imp_gift_code.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/3/21 0021
-- 描  述:	礼包码
--------------------------------------------------------------------
local db_hiredis = require "basic/db_hiredis"
local gift_pack_scheme = require("data/activity_gift_pack").activity
local const = require "Common/constant"

for i, v in pairs(gift_pack_scheme) do
    local start_time = v.StartTime
    local start_time_in_sec = os.time({year=start_time[1], month=start_time[2], day=start_time[3], hour=start_time[4], minute=start_time[5], second=0})
    v.start_time_in_sec = start_time_in_sec

    local end_time = v.EndTime
    local end_time_in_sec = os.time({year=end_time[1], month=end_time[2], day=end_time[3], hour=end_time[4], minute=end_time[5], second=0})
    v.end_time_in_sec = end_time_in_sec
end

local params = {}


local imp_gift_code = {}
imp_gift_code.__index = imp_gift_code

setmetatable(imp_gift_code, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_gift_code.__params = params

function imp_gift_code.__ctor(self)
    self.used_gift_code = {}
end

function imp_gift_code.imp_gift_code_init_from_dict(self, dict)
    self.used_gift_code = table.get(dict, "used_gift_code", {})
end

function imp_gift_code.imp_gift_code_init_from_other_game_dict(self,dict)
    self:imp_gift_code_init_from_dict(dict)
end

function imp_gift_code.imp_gift_code_write_to_dict(self, dict)
    dict.used_gift_code = self.used_gift_code
end

function imp_gift_code.imp_gift_code_write_to_other_game_dict(self,dict)
    self:imp_gift_code_write_to_dict(dict)
end

function imp_gift_code.imp_gift_code_write_to_sync_dict(self, dict)
    dict.used_gift_code = self.used_gift_code
end

function imp_gift_code.on_use_gift_code(self, input, syn_data)
    local gift_pack_code = input.gift_pack_code
    local gift_pack_id = db_hiredis.hget("gift_pack", gift_pack_code, true)
    local output = {func_name = "UseGiftCodeRet", }
    if gift_pack_id == nil then
        output.result = const.error_gift_code_not_evalid
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
    if gift_pack_id == -1 then
        output.result = const.error_gift_code_is_used
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
    local config = gift_pack_scheme[gift_pack_id]
    if config == nil then
        output.result = const.error_gift_code_not_evalid
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    if self.level < config.Level then
        output.result = const.error_level_not_enough
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end
    self.used_gift_code[gift_pack_id] = self.used_gift_code[gift_pack_id] or 0
    if self.used_gift_code[gift_pack_id] >= config.ReceiveTimes then
        output.result = const.error_gift_receive_times_full
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    local current_time = _get_now_time_second()
    if current_time < config.start_time_in_sec or current_time > config.end_time_in_sec then
        output.result = const.error_gift_code_not_in_date
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC , output)
    end

    self.used_gift_code[gift_pack_id] = self.used_gift_code[gift_pack_id] + 1
    if config.UsageTimes ~= -1 then
        db_hiredis.hset("gift_pack", gift_pack_code, -1, true)
    end
    local rewards = {}
    for i = 1, 6 do
        local rwd = config["Reward"..i]
        if rwd ~= nil and rwd[1] ~= 0 and rwd[1] ~= nil then
            rewards[rwd[1]] = rwd[2]
        end
    end
    self:add_new_rewards(rewards)
    self:imp_assets_write_to_sync_dict(syn_data)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="GetRewardsNotice",rewards=rewards})
end

local RANDOM_CODE_SET = {2,3,4,5,6,7,8,9,"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "m", "n", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",}

local function _generate_code_list(count, gift_pack_id, code_length)
    code_length = code_length - 1
    gift_pack_id = gift_pack_id or "t"
    local code_list = {}
    local gen_count = 0
    local set_length = #RANDOM_CODE_SET
    repeat
        local code_table = {gift_pack_id}
        for i = 1, code_length do
            local c = RANDOM_CODE_SET[math.random(set_length)]
            table.insert(code_table, c)
        end
        local code_string = table.concat(code_table)
        if code_list[code_string] == nil then
            code_list[code_string] = true
            gen_count = gen_count + 1
        end
    until(gen_count == count)
    return code_list
end

local function _init_code_list_to_database()
    local gift_pack_id = 206
    local key_head

    if gift_pack_id == nil then
        key_head = "regist:"
        local code_list = _generate_code_list(1500, gift_pack_id, 9)
        for v, _ in pairs(code_list) do
            db_hiredis.set(key_head..v, 1, true)
            _info(key_head..v)
        end
    else
        key_head = "gift_pack"
        repeat
            local code_list = _generate_code_list(1000, gift_pack_id, 9)
            for v, _ in pairs(code_list) do
                db_hiredis.hset(key_head, v, gift_pack_id, true)
                _info(key_head..v)
            end

            gift_pack_id = gift_pack_id + 1
        until(gift_pack_id >= 206)
    end



    --[[db_hiredis.hset("gift_pack", "30cjlb", 101, true)
    db_hiredis.hset("gift_pack", "40cjlb", 102, true)
    db_hiredis.hset("gift_pack", "45cjlb", 103, true)
    db_hiredis.hset("gift_pack", "50cjlb", 104, true)
    db_hiredis.hset("gift_pack", "55cjlb", 105, true)
    db_hiredis.hset("gift_pack", "60cjlb", 106, true)]]

    assert(false)
end

local function export()
    local keys = db_hiredis.hkeys("gift_pack", true)
    local str = table.concat(keys, "\n")

    local file = io.open("gift_code.txt", "w")
    assert(file)
    file:write(str)
    file:close()
    asset(false)
end

--register_function_on_start(export)

return imp_gift_code