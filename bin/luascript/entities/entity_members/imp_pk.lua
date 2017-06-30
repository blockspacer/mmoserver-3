--------------------------------------------------------------------
-- 文件名:	imp_pk.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/27 0027
-- 描  述:	pk相关
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local common_fight_base = require "data/common_fight_base"
local online = require "onlinerole"
local TURN_YELLOW_COLOR = common_fight_base.Parameter[38].Value   --名字变黄
local TURN_RED_COLOR = common_fight_base.Parameter[39].Value      --名字变红
local SELF_DEFENCE_TIME = common_fight_base.Parameter[14].Value   --自卫时间
local PK_VALUE_DECREMENT_PER_HALF_HOUR = {
    common_fight_base.Parameter[40].Value,
    common_fight_base.Parameter[37].Value,
}
local SCOND_PK_REFRESH = 60                --pk_value刷新秒数
local red_name_scheme = common_fight_base.RedNameSystem
local red_name_table = {}
for i, v in pairs(red_name_scheme) do
    local value_name = const.PK_TYPE_TO_VALUE_NAME[v.Type]
    if value_name == nil then
        flog("error", "imp_pk.lua: value_name is nil")
    end
    red_name_table[value_name] = red_name_table[value_name] or {}
    local color_name = const.PK_COLOR_INDEX_TO_NAME[v.Status]
    if color_name == nil then
        flog("error", "imp_pk.lua: color_name is nil")
    end
    red_name_table[value_name][color_name] = v
end

local recreate_scheme_table_with_key = require("basic/scheme").recreate_scheme_table_with_key
local scene_total_scheme = require("data/common_scene").Totalparameter
local scene_type_configs = recreate_scheme_table_with_key(scene_total_scheme, "SceneType")

local params = {
    pk_value = {db = true, sync = true},                             --pk值
    karma_value = {db = true, sync = true},                          --善恶值
    pk_mode = {db = true, sync = true, default = "country"},       --pk模式(country：阵营，karma：善恶，faction：阵营，slaughter：杀戮)
    force_mode = {db = true, sync = true, default = "manual"},       --强制pk模式，非manual时，pk模式强制为force_mode
    pk_color = {db = false, sync = true},                            --pk颜色，green, yellow, red
    pk_value_last_refresh_time = {db = true, sync = false},          --pk值最后刷新时间
    kill_monster_exp_rate = {default = 1},                           --杀怪经验倍率
}

local imp_pk = {}
imp_pk.__index = imp_pk

setmetatable(imp_pk, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_pk.__params = params

function imp_pk.__ctor(self)
    self.evil_attacker = {}
    self.dark_green_timer = nil
end

--pk_value显示的时候以及计算pk_color除以100
local function _get_truly_pk_value(pk_value)
    return math.floor(pk_value / 100)
end

local function _calc_color(pk_value)
    local color
    if pk_value > TURN_RED_COLOR then
        color = "red"
    elseif pk_value > TURN_YELLOW_COLOR then
        color = "yellow"
    else
        color = "green"
    end

    return color
end

local function _calc_pk_value(self, scene_id, is_refresh)
    if scene_id == nil then
        scene_id = self.scene_id
    end
    local current_time = _get_now_time_second()

    --PK值计算
    local scene = self:get_scene()
    if scene == nil then
        return
    end
    local scene_type = scene:get_scene_type()
    local scene_pk_decrement = PK_VALUE_DECREMENT_PER_HALF_HOUR[scene_type]
    if scene_pk_decrement == nil or scene_pk_decrement == 0 then
        return
    end

    local delta_time = current_time - self.pk_value_last_refresh_time
    local delta_number = math.floor(delta_time / SCOND_PK_REFRESH)
    local pk_value_decrement = delta_number * scene_pk_decrement
    local truly_decrement = pk_value_decrement
    if self.pk_value < truly_decrement then
        truly_decrement = self.pk_value
    end
    self.pk_value = self.pk_value - truly_decrement
    self.pk_value_last_refresh_time = self.pk_value_last_refresh_time + delta_number * SCOND_PK_REFRESH
    if is_refresh then
        self.pk_value_last_refresh_time = current_time
    end

    local t_pk_value = _get_truly_pk_value(self.pk_value)
    local new_pk_color = _calc_color(t_pk_value)
    if new_pk_color ~= self.pk_color then
        self:_set("pk_color", new_pk_color)
    end
end

--根据dict初始化
function imp_pk.imp_pk_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    _calc_pk_value(self)
end

function imp_pk.imp_pk_init_from_other_game_dict(self,dict)
    self:imp_pk_init_from_dict(dict)
end

function imp_pk.imp_pk_write_to_dict(self, dict, to_other_game)
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

function imp_pk.imp_pk_write_to_other_game_dict(self,dict)
    self:imp_pk_write_to_dict(dict, true)
end

function imp_pk.imp_pk_write_to_sync_dict(self, dict)
    _calc_pk_value(self)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
    dict.pk_value = _get_truly_pk_value(self.pk_value)
    dict.evil_attacker = table.copy(self.evil_attacker)
end


function imp_pk.on_attack_player(self, enemy)
    local enemy_id = enemy.actor_id

    if self.evil_attacker[enemy_id] == true then
        return
    end

    if self.country == enemy.country then
        enemy.evil_attacker[self.actor_id] = true
        if self.dark_green_timer ~= nil then
            Timer.Remove(self.dark_green_timer)
            self.dark_green_timer = nil
        end

        self.dark_green_timer = Timer.Delay(SELF_DEFENCE_TIME, function()
                    if enemy~=nil then
                        enemy.evil_attacker[self.actor_id] = nil
                        self.dark_green_timer = nil
                        enemy:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "DarkGreenRelieve", attacker = self.actor_id, attacker_pk_color = enemy.pk_color, evil_attacker = enemy.evil_attacker})
                    end
                end)
    end
    enemy:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = 0, func_name = "BeingAttacked", attacker = self.actor_id, evil_attacker = enemy.evil_attacker})
end


function imp_pk.imp_pk_on_kill_player(self, enemy)
    local scheme_name
    if self.country ~= enemy.country then       --敌对阵营
        scheme_name = "RivalCamps"
    elseif self.evil_attacker[enemy.actor_id] then  --墨绿玩家
        scheme_name = "ActiveAttack"
    else
        scheme_name = const.PK_COLOR_NAME_SCHEME[enemy.pk_color]
        if self.level - enemy.level >= 20 then
            scheme_name = scheme_name.."20"
        end
    end
    local pk_value_add = red_name_table["pk_value"][self.pk_color][scheme_name]
    self.pk_value = self.pk_value + pk_value_add * 100          --存储pk_value按百分制，显示按正常显示
    local karma_value_add = red_name_table["karma_value"][self.pk_color][scheme_name]
    self:change_value_on_rank_list("karma_value", self.karma_value - karma_value_add)

    local output = {result = 0, func_name = "PkStateChange" , actor_id = self.actor_id}
    self:imp_pk_write_to_sync_dict(output)
    self:broadcast_to_aoi_include_self(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_pk.is_player_attackable(self, enemy)
    local enemy_id = enemy.actor_id
    if enemy_id == self.actor_id then
        return false
    end

    local mode
    if self.force_mode == "manual" then
        mode = self.pk_mode
    else
        mode = self.force_mode
    end
    if mode == nil then
        flog("error", "imp_pk.is_attackable pk_mode is nil")
    end

    if self.evil_attacker[enemy_id] == true then
        return true
    end

    if self.team_members[enemy_id] then
        return false
    end

    if self.level < 30 or enemy.level < 30 then        --30级新手保护
        local output = {result = const.error_cannot_attack_same_country_new_player, func_name = "AttackFeedback" }
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
        return false
    end

    if mode == "peace" then
        return false
    elseif mode == "country" then
        if self.country == enemy.country then
            return false
        else
            return true
        end
    elseif mode == "slaughter" then
        return true
    elseif mode == "karma" then
        if self.country ~= enemy.country then
            return true
        else
            if enemy.pk_color == "red" then
                return true
            else
                return false
            end
        end
    elseif mode == "faction" then
        if self.faction_id == 0 then
            return true
        end
        return self.faction_id ~= enemy.faction_id
    end

    return false
end

local function on_scene_loaded(self, input, syn_data)
    local scene_id = input.scene_id
    _calc_pk_value(self, scene_id, true)

    local scene = self:get_scene()
    if scene ~= nil then
        local scene_type_config = scene_type_configs[scene:get_scene_type()]
        if scene_type_config == nil then
            flog("error", "imp_pk on_scene_loaded scene_type_config is nil ")
        end
        local scene_mode = scene_type_config.Pkmode
        if scene_mode == 0 then
            self.force_mode = "manual"
        else
            self.force_mode = const.PK_MODE_INDEX[scene_mode]
        end
        self.kill_monster_exp_rate = scene_type_config.Exp / 100
    end

end

function imp_pk.on_get_pk_info(self, input, syn_data)
    local player = self
    if input.actor_id ~= nil then
        player = online.get_user(input.actor_id)
        if player == nil then
            return const.error_player_is_not_online
        end
    end

    local output = {result = 0, func_name = "GetPkInfoRet" }
    player:imp_pk_write_to_sync_dict(output)
    output.actor_id = player.actor_id
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_pk.on_change_pk_mode(self, input, syn_data)
    local pk_mode = input.pk_mode
    if const.PK_MODE_SET[pk_mode] ~= 1 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "ChangePkModeRet", result = const.error_impossible_param})
        return
    end

    self.pk_mode = pk_mode
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "ChangePkModeRet", result = 0, pk_mode = self.pk_mode})
end

function imp_pk.gm_set_pk_value(self, value)
    self:_set("pk_value", value * 100)
end

function imp_pk.reduce_pk_value(self,addon)
    local old_value = math.floor(self.pk_value / 100)
    if self.pk_value < addon*100 then
        self.pk_value = 0
        addon = old_value
    else
        self.pk_value = self.pk_value - addon*100
    end

    return addon
end

function imp_pk.get_pk_value(self)
    return _get_truly_pk_value(self.pk_value)
end

register_message_handler(const.CS_MESSAGE_LUA_LOADED_SCENE, on_scene_loaded)

imp_pk.__message_handler = {}
imp_pk.__message_handler.on_scene_loaded = on_scene_loaded

return imp_pk