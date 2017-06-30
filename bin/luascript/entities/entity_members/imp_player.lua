----------------------------------------------------------------------
-- 文件名:	imp_player.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/11
-- 描  述:	玩家模块，玩家特有的一些属性
--------------------------------------------------------------------
local fix_string = require "basic/fix_string"
local const = require "Common/constant"
local flog = require "basic/log"
local REBIRTH_TIME_RESET_MIN = require("data/common_fight_base").Parameter[12].Value
local rebirth_param = require("data/common_fight_base").Revive
local online_user = require "onlinerole"
local Totalparameter = require("data/common_scene").Totalparameter
local SyncManager = require "Common/SyncManager"
local timer = require "basic/timer"
local getmetatable = getmetatable
local entity_common = require "entities/entity_common"
local common_item_config = require "configs/common_item_config"
local data_base = require "basic/db_mongo"
local string_utf8len = require("basic/scheme").string_utf8len
local SkillAPI = require "Common/combat/Skill/SkillAPI"
local get_now_time_second = _get_now_time_second
local common_parameter_formula_config = require "configs/common_parameter_formula_config"
require "UnityEngine.Vector3"
local tonumber = tonumber
local set_open_day = require("basic/scheme").set_open_day
local net_work = require "basic/net"
local system_faction_config = require "configs/system_faction_config"
local common_scene_config = require "configs/common_scene_config"

local rebirth_index = {}
for i, v in ipairs(rebirth_param) do
    rebirth_index[v.Rebirthtype] = rebirth_index[v.Rebirthtype] or {}
    table.insert(rebirth_index[v.Rebirthtype], {index = i, lv = v.LowerLimit})
end
local function get_index_from_rebirth_times(type, times)
    local type_index = rebirth_index[type]
    if type_index == nil then
        flog("error", "get_index_from_rebirth_times: error type "..type)
        return
    end
    local idx
    local lv = 0
    for _, v in ipairs(type_index) do
        if times >= v.lv and v.lv > lv then
            idx = v.index
            lv = v.lv
        end
    end
    if idx == nil then
        idx = type_index[#type_index].index
    end
    return idx
end
local math = require "math"

local scene_type_configs = {}
for _,v in pairs(Totalparameter) do
    scene_type_configs[v.SceneType] = v
end

local REBIRTH_TYPE = const.REBIRTH_TYPE
local SCENE_TYPE = const.SCENE_TYPE
local kill_by_player_rebirth_buff = require("data/common_fight_base").Parameter[10].Value

local params = {
    country = {db = true, sync = true, default = 1},                       --所在国家
    actor_id = {db = true,sync = true},                 --角色id
    scene_id = {db = true,sync = true},                 --场景id
    session_id = {},                                    --通信会话id
    posX = {db = true,sync = true, broadcast = true},  --位置x
    posY = {db = true,sync = true, broadcast = true},  --位置Y
    posZ = {db = true,sync = true, broadcast = true},  --位置Z
    level = {db = true,sync = true, broadcast = true, default = 1},         --等级
    actor_name = {db = true,sync = true, broadcast = true, default = ""},   --玩家名
    vocation = {db = true, sync = true, broadcast = true},                  --职业
    sex = {db = true,sync = true,broadcast = true,default = 1},             --性别
    offlinetime = {db = true,default = 0 },                                 --离线时间
    rebirth_type = {db=true,default="A"},                                   --复活类型
    dead_time = {db = true, sync = true, default = -1},         --死亡时间,未死亡则为-1
    rebirth_times = {db = true, sync = true, default = 1},      --连续重生次数
    dungeon_rebirth_time = {db = true,sync= true,default = 1},  --副本复活次数
    last_dead_time = {db = true, sync = true, default = 1},     --上一次死亡时间，第一次死亡则为-1
    current_hp = {db = true, sync = true},          --血量
    die_buff_times = {db=true,sync=false,default = 0}, --被玩家击杀buff次数
    kill_by_player = {db = true,sync=false,default=false}, --是否被玩家击杀
    change_model_scale_time = {db=true,sync=false,default=0},       --变形药剂使用时间
    disguise_model_time = {db=true,sync=false,default=0},       --易容结束时间
    stealthy_time = {db=true,sync=false,default=0},             --隐身到达时间
    next_change_name_time = {db=true,sync=true,default=0},      --下一次可以修改名字时间
    --immortal_data = {db=true,sync=false,default = {}},          --玩家相关战斗数据
    fight_power = {db=true, sync=true},      --战斗力
    total_power = {},                         --综合实力

}

local imp_player = {}
imp_player.__index = imp_player

setmetatable(imp_player, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})
imp_player.__params = params

local function on_player_login(self, input, syn_data)
    flog("syzDebug", "CreateImpPlayer.on_player_login")
    self:recalc()
    self.current_hp = self.hp_max
    local login_data = {}
    self:imp_player_write_to_sync_dict(login_data)
    self:imp_property_write_to_sync_dict(login_data)
    self:imp_seal_write_to_sync_dict(login_data, true)
    self:imp_dungeon_write_to_sync_dict(login_data)
    self:imp_assets_write_to_sync_dict(login_data)
    self:imp_store_write_to_sync_dict(login_data)
    self:imp_skill_write_to_sync_dict(login_data)
    self:imp_equipment_write_to_sync_dict(login_data)
    self:imp_pk_write_to_sync_dict(login_data)
    self:imp_teamup_write_to_sync_dict(login_data)
    self:imp_country_write_to_sync_dict(login_data)
    self:imp_faction_write_to_sync_dict(login_data)
    self:imp_appearance_write_to_sync_dict(login_data)
    login_data.server_time = _get_now_time_second()
    login_data.entity_id = self.entity_id
    if self.in_fight_server then
        self:write_fight_server_info_to_dict(login_data)
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_player_replace"})
    end
    self:send_message(const.SC_MESSAGE_LUA_LOGIN, {result = 0, login_data = login_data})

    local info = {}
    self:imp_seal_write_to_sync_dict(info)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
    if self.replace_flag then
        self:set_task_update_flag(true)
        self:send_arena_info()
        self.replace_flag = false
    end
    self:set_task_update_flag(true);
    local session_id_str = string.format("%16.0f",self.session_id)
    --通知global玩家登录
    self:send_message_to_friend_server({func_name="on_add_friend_player",actor_id = self:get("actor_id")})
    --通知邮件服务器
    self:send_message_to_mail_server({func_name="on_mail_player_init",actor_id=self.actor_id,server_id=net_work.get_serverid(),session_id=session_id_str})
    --通知阵营服务器
    self:send_message_to_country_server({func_name="on_country_player_init",actor_id=self.actor_id,session_id=session_id_str})
    --通知帮派服务器
    self:send_message_to_faction_server({func_name="on_faction_player_init",actor_id=self.actor_id,session_id=session_id_str,faction_id=self.faction_id})
    --通知排名服务器
    self:send_message_to_ranking_server({func_name="on_ranking_player_init",actor_id=self.actor_id,session_id=session_id_str})
    --通知商店服务器
    self:send_message_to_shop_server({func_name="on_shop_player_init",actor_id=self.actor_id,session_id=session_id_str})
    --通知组队服务器
    self:send_message_to_team_server({func_name="on_team_player_init",actor_id=self.actor_id,session_id=session_id_str,actor_game_id=self.game_id})
    --通知竞技场服务器
    self:send_message_to_arena_server({func_name="on_arena_player_init",actor_id = self.actor_id,actor_name = self.actor_name,vocation=self.vocation,level=self.level,union_name=self.faction_name,fight_power=self.fight_power,spritual=self.spritual,sex=self.sex})

end

local function on_gm_command(self, input, syn_data)
    local gm_command

    pcall(function () gm_command = require "gm/gm_command" end)
    if gm_command ~= nil then
        local result = gm_command(self, input.command, syn_data)
        self:send_message(const.SC_MESSAGE_LUA_GM, {result = result, command = input.command})
    end
end

function imp_player.on_global_init_complete(self,input,syn_data)
    self:send_message_to_friend_server({func_name="on_update_player_info",actor_id = self:get("actor_id"),level=self:get("level"),actor_name=self:get("actor_name"),vocation=self:get("vocation"),country=self:get("country"),sex=self:get("sex")})
    self:set_friend_init_complete(true)
end

local function get_rebirth_config(self)
    local rebirth_config = nil
    local idx = nil
    if self.rebirth_type == "A" then
        idx = get_index_from_rebirth_times(self.rebirth_type, self.rebirth_times)
    elseif self.rebirth_type == "B" then
        idx = get_index_from_rebirth_times(self.rebirth_type, self.dungeon_rebirth_time)
    elseif self.rebirth_type == "C" then
        idx = get_index_from_rebirth_times(self.rebirth_type, 1)
    else
        flog("error","rebirth type is not match!,rebirth type:"..self.rebirth_type)
    end
    if idx ~= nil then
        rebirth_config = rebirth_param[idx]
    end
    return rebirth_config
end

local function destroy_rebirth_timer(self)
    if self.rebirth_timer ~= nil then
        timer.destroy_timer(self.rebirth_timer)
        self.rebirth_timer = nil
    end
end

local function clear_die_state(self)
    if self.rebirth_type == "A" then
        self.last_dead_time = self.dead_time
        self.dead_time = -1
        --self.rebirth_times = self.rebirth_times + 1
    elseif self.rebirth_type == "B" then
        self.dead_time = -1
        --self.dungeon_rebirth_time = self.dungeon_rebirth_time + 1
    else
        self.dead_time = -1
    end
    destroy_rebirth_timer(self)
end

local function _rebirth(self)
    if self.dead_time == -1 then
        return
    end

    local rebirth_config = get_rebirth_config(self)
    if rebirth_config ~= nil and rebirth_config["Time"..REBIRTH_TYPE.rebirth_place_passive] ~= -1 then
        self:player_rebirth(REBIRTH_TYPE.rebirth_place_passive)
    else
        self:player_rebirth(REBIRTH_TYPE.city_passive)
    end
    self:reply_player_rebirth()
end

function imp_player.reply_player_rebirth(self)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="onPlayerRebirth",result=0})
end

local function notice_client_rebirth_info(self,rpc_code)
    if self.rebirth_type == "C" then
        return
    end

    local rebirth_config = get_rebirth_config(self)
    if rebirth_config == nil then
        flog("error","notice_client_rebirth_info rebirth_config == nil")
        return
    end
    local rebirth_infos = {}
    local current_time = get_now_time_second()
    for _,rebirth_type in pairs(REBIRTH_TYPE) do
        if rebirth_config["Time"..rebirth_type] > -1 then
            rebirth_infos[rebirth_type] = rebirth_config["Time"..rebirth_type] + self.dead_time - current_time
            if rebirth_infos[rebirth_type] < 0 then
                rebirth_infos[rebirth_type] = 0
            end
        end
    end

    if rebirth_config.Rebirthcost[1] ~= nil and rebirth_config.Rebirthcost[2] ~= nil then
        rebirth_infos.item_id = rebirth_config.Rebirthcost[1]
        rebirth_infos.item_count = rebirth_config.Rebirthcost[2]
    end
    self:send_message(rpc_code,{func_name="onReciveRebirthInfo",rebirth_infos=rebirth_infos})
end

local function _die(self,revive_type)
    if self.dead_time == -1 then
        flog("error", "_die : dead_time is -1")
        return
    end
    if self.last_dead_time == -1 then
        flog("syzDebug", "_die : first dead")
        return
    end
    if revive_type == "A" then
        if self.dead_time - self.last_dead_time > REBIRTH_TIME_RESET_MIN * 60 then
            self.rebirth_times = 1
        end
    end
end

local function destroy_change_model_timer(self)
    if self.change_model_scale_timer ~= nil then
        timer.destroy_timer(self.change_model_scale_timer)
        self.change_model_scale_timer = nil
    end
end

local function recovery_change_model_scale(self)
    self.model_scale = 100
    self.change_model_scale_time = 0
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_change_model_scale",model_scale=self.model_scale})
        return
    else
        local puppet = self:get_puppet()
        if puppet ~= nil then
            puppet:SetDisguiseModelScale(self.model_scale)
        end
    end
    --通知本人
    local info = {}
    self:imp_player_write_to_sync_dict(info)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
    return 0
end

local function destroy_disguise_model_timer(self)
    if self.disguise_model_timer ~= nil then
        timer.destroy_timer(self.disguise_model_timer)
        self.disguise_model_timer = nil
    end
end

local function recovery_disguise_model(self)
    self.is_disguise = false
    self.disguise_model_id = 0
    self.disguise_model_time = 0
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_disguise_model",is_disguise = self.is_disguise,model_scale=self.disguise_model_id})
        return
    else
        local puppet = self:get_puppet()
        if puppet ~= nil then
            puppet:SetDisguiseModelId(self.disguise_model_id)
        end
    end
    --通知本人
    local info = {}
    self:imp_player_write_to_sync_dict(info)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
end

local function destroy_stealthy_timer(self)
    if self.stealthy_timer ~= nil then
        timer.destroy_timer(self.stealthy_timer)
        self.stealthy_timer = nil
    end
end

local function recovery_from_stealthy(self)
    self.is_stealthy = false
    self.stealthy_time = 0
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_player_stealthy",is_stealthy = self.is_stealthy})
        return
    else
        local puppet = self:get_puppet()
        if puppet ~= nil then
            puppet:SetStealthy(self.is_stealthy)
        end
    end
    --通知本人
    local info = {}
    self:imp_player_write_to_sync_dict(info)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE, info )
end

local function on_player_logout(self)
    destroy_rebirth_timer(self)
    destroy_change_model_timer(self)
    destroy_disguise_model_timer(self)
    destroy_stealthy_timer(self)
    if self.in_fight_server then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_player_logout"})
    end
end

local function player_die_internal(self,rebirth_type,dead_time)
    self.dead_time = dead_time
    self.rebirth_type = rebirth_type
    _die(self,rebirth_type)

    local time_need = 360
    local rebirth_config = get_rebirth_config(self)
    if rebirth_config == nil then
        flog("info","can not find revive config,rebirth_type:"..self.rebirth_type..",rebirth_times:"..self.rebirth_times..",dungeon_rebirth_time:"..self.dungeon_rebirth_time)
        self:player_rebirth(REBIRTH_TYPE.city_passive)
        return
    end
     if rebirth_config.Time5 ~= -1 then
        time_need = rebirth_config.Time5
    elseif rebirth_config.Time4 ~= -1 then
        time_need = rebirth_config.Time4
    end

    destroy_rebirth_timer(self)
    local function rebirth_handler()
        _rebirth(self)
    end
    self.rebirth_timer = timer.create_timer(rebirth_handler,time_need*1000,0,1)
    notice_client_rebirth_info(self,const.SC_MESSAGE_LUA_GAME_RPC)
end

function imp_player.on_player_die(self,killer_id)
    flog("tmlDebug","imp_player.on_player_die")
    --战斗服中不处理野外死亡
    if self.in_fight_server or self:is_connecting_fight_server() then
        flog("debug","player in fight server!do not care wild die!")
        self.immortal_data.hp = nil
        self.immortal_data.mp = nil
        return
    end

    local scene = self:get_scene()
    if scene == nil then
        return
    end
    local rebirth_type = "A"
    local scene_type_config = scene_type_configs[scene:get_scene_type()]
    if scene_type_config ~= nil then
        rebirth_type = scene_type_config.revive
    end
    if scene:get_scene_type() == SCENE_TYPE.WILD then
        local killer = scene:get_entity(killer_id)
        if killer ~=nil and killer.type == const.ENTITY_TYPE_PLAYER then
            self.die_buff_times = self.die_buff_times + 1
            self.kill_by_player = true
        end
    end
    player_die_internal(self,rebirth_type,get_now_time_second())
end

function imp_player.on_fight_avatar_die(self,input,sync_data)
    player_die_internal(self,input.rebirth_type,input.dead_time)
end

function imp_player.on_player_rebirth(self,input,syn_data)
    flog("tmlDebug","on_player_rebirth!!!!")
    local result = 0
    local rebirth_choose = input.choose
    if self.dead_time == -1 then
        flog("tmlDebug","error_player_is_alive!!!!")
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_player_is_alive,func_name="onPlayerRebirth"})
        return
    end

    local rebirth_config = get_rebirth_config(self)
    if rebirth_config == nil then
        self:player_rebirth(REBIRTH_TYPE.city_passive)
        self:reply_player_rebirth()
        return
    end

    if rebirth_config["Time"..rebirth_choose] == nil or rebirth_config["Time"..rebirth_choose] == -1 then
        result = const.error_rebirth_type_invalid
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result,func_name="onPlayerRebirth"})
        return
    end

    local time_now = get_now_time_second()
    if time_now - self.dead_time < rebirth_config["Time"..rebirth_choose] then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_rebirth_time_not_arrival,func_name="onPlayerRebirth"})
        return
    end

    if rebirth_choose == REBIRTH_TYPE.original_place then  --使用道具立即复活
        local cost = rebirth_config.Rebirthcost
        if cost[1] ~= nil and cost[2] ~= nil then --cost[1]为nil表示不消耗物品
            if not self:is_enough_by_id(cost[1], cost[2]) then  
                self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_item_not_enough,func_name="onPlayerRebirth",item_id = cost[1]})
                return
            end
            self:remove_item_by_id(cost[1], cost[2])
            self:imp_assets_write_to_sync_dict(syn_data)
            if self.rebirth_type == "A" then
                self.rebirth_times = self.rebirth_times + 1
            elseif self.rebirth_type == "B" then
                self.dungeon_rebirth_time = self.dungeon_rebirth_time + 1
            end
        end
    end
    self:player_rebirth(input.choose)
    self:reply_player_rebirth()
end

local function on_get_player_info(self,input,sync_data)
    if input.actor_id == nil then
        flog("tmlDebug","imp_player|on_get_player_info input.actor_id == nil")
        return
    end
    local other_player = online_user.get_user(input.actor_id)
    if other_player ~= nil then
        local player_info = {}
        other_player:write_player_info_to_other(player_info)
        self:send_message(const.SC_MESSAGE_LUA_QUERY_PLAYER, {result = 0,player_info=player_info})
        return
    end
    self:send_message_to_friend_server({func_name="on_query_player_info",query_actor_id=input.actor_id})
end

function imp_player.on_reply_query_player_info(self,input,sync_data)
    self:send_message(const.SC_MESSAGE_LUA_QUERY_PLAYER, {result = input.result,player_info=input.player_info})
end

function imp_player.on_global_query_player_info(self,input,sync_data)
    local result = 0
    local player_info = {}
    self:write_player_info_to_other(player_info)
    self:send_message_to_friend_server({func_name="on_global_query_player_info",result = result,player_info=player_info,queryer_actor_id=input.queryer_actor_id})
end

--其他服务器远程调用
--可以注册多个消息
local function on_game_rpc(self, input, syn_data)
    local func_name = input.func_name
    if func_name == nil or self[func_name] == nil then
        --func_name = func_name or "nil"
        --flog("error", "on_game_rpc: no func_name  "..func_name)
        return
    end

    self[func_name](self, input, syn_data)
end

function imp_player.__ctor(self)
    self.immortal_data = {}
    self.rebirth_timer = nil
    self.player_fight_state = false
    self.in_fight_server = false
    self.change_model_scale_timer = nil
    self.disguise_model_timer = nil
    self.stealthy_timer = nil
    self.replace_flag = false
end

function imp_player.imp_player_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    if dict.immortal_data ~= nil then
        self.immortal_data = table.copy(dict.immortal_data)
    end

    self.entity_id = self.actor_id
    if self.dead_time ~= -1 then
        clear_die_state(self)
        if self.immortal_data.hp and self.immortal_data.hp <= 0 then
            self.immortal_data.hp= nil
        end
    elseif self.immortal_data.hp == nil or self.immortal_data.hp <= 0 then
        self.immortal_data.hp = self.max_hp
    end
    --取出时除以100
    if self.posX ~= nil then
        self.posX = self.posX / 100;
    end
    if self.posY ~= nil then
        self.posY = self.posY / 100;
    end
    if self.posZ ~= nil then
        self.posZ = self.posZ / 100;
    end

    if self.scene_id == const.FACTION_SCENE_ID then
        --登陆时检查是否超出场景范围
        local faction_scene_config = system_faction_config.get_faction_scene_config(self.scene_id)
        if faction_scene_config ~= nil then
            local scene_resource_config = common_scene_config.get_scene_resource_config(faction_scene_config.SceneID)
            if scene_resource_config ~= nil and (self.posX <= scene_resource_config.MinX or self.posX >= scene_resource_config.MaxX or self.posZ <= scene_resource_config.MinZ or self.posZ >= scene_resource_config.MaxZ) then
                local pos = system_faction_config.get_random_born_pos(self.scene_id)
                if pos ~= nil then
                    self.posX = pos[1]
                    self.posY = pos[2]
                    self.posZ = pos[3]
                end
            end
        end
    else
        --登陆时检查是否超出场景范围
        local scene_config = common_scene_config.get_scene_config(self.scene_id)
        if scene_config ~= nil then
            if scene_config.Party > 0 and scene_config.Party ~= self.country then
                self.scene_id = const.CITY_SCENE_ID[self.country]
                local pos = common_scene_config.get_random_born_pos(self.scene_id)
                if pos ~= nil then
                    self.posX = pos[1]
                    self.posY = pos[2]
                    self.posZ = pos[3]
                end
            end
            local scene_resource_config = common_scene_config.get_scene_resource_config(scene_config.SceneID)
            if scene_resource_config ~= nil and (self.posX <= scene_resource_config.MinX or self.posX >= scene_resource_config.MaxX or self.posZ <= scene_resource_config.MinZ or self.posZ >= scene_resource_config.MaxZ) then
                local pos = common_scene_config.get_random_born_pos(self.scene_id)
                if pos ~= nil then
                    self.posX = pos[1]
                    self.posY = pos[2]
                    self.posZ = pos[3]
                end
            end
        end
    end


    self.client_config = table.copy(dict.client_config) or {}

    local current_time = _get_now_time_second()
    --模型比例
    local change_model_scale_duration = self.change_model_scale_time - current_time
    if change_model_scale_duration > 0 then
        destroy_change_model_timer(self)
        self.change_model_scale_timer = timer.create_timer(function()
            recovery_change_model_scale(self)
            destroy_change_model_timer(self)
        end,change_model_scale_duration*1000,0,1)
    else
        self.immortal_data.disguise_model_scale = 100
    end
    --易容
    if self.immortal_data.is_disguise ~= nil and self.immortal_data.is_disguise == true then
        local disguise_duration = self.disguise_model_time - current_time
        if disguise_duration > 0 then
            destroy_disguise_model_timer(self)
            self.disguise_model_timer = timer.create_timer(function()
                recovery_disguise_model(self)
                destroy_disguise_model_timer(self)
            end,disguise_duration*1000,0,1)
        else
            self.immortal_data.is_disguise = false
        end
    end
    --隐身
    if self.immortal_data.is_stealthy ~= nil and self.immortal_data.is_stealthy == true then
        local stealthy_duration = self.stealthy_time - current_time
        if stealthy_duration > 0 then
            destroy_stealthy_timer(self)
            self.stealthy_timer = timer.create_timer(function()
                recovery_from_stealthy(self)
                destroy_stealthy_timer(self)
            end,stealthy_duration*1000,0,1)
        else
            self.immortal_data.is_stealthy = false
        end
    end
    self.change_scene_buffs = table.copy(dict.change_scene_buffs)
end

function imp_player.imp_player_init_from_other_game_dict(self,dict)
    self:imp_player_init_from_dict(dict)
end

function imp_player.imp_player_write_to_dict(self, dict, to_other_game)
    self.offlinetime = _get_now_time_second()

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
    dict.posX, dict.posY, dict.posZ = self.pos_to_client(self.posX, self.posY, self.posZ)

    self:write_client_config(dict)
    if self.immortal_data ~= nil then
        dict.immortal_data = table.copy(self.immortal_data)
    end
    dict.change_scene_buffs = table.copy(self.change_scene_buffs)
end

function imp_player.imp_player_write_to_other_game_dict(self,dict)
    self:imp_player_write_to_dict(dict, true)
end

function imp_player.imp_player_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            if i == "posX" or i == "posY" or i == "posZ" then
                local pos = math.ceil(self[i]*100)
                dict[i] = pos
            else
                dict[i] = self[i]
            end
        end
    end
    if self.immortal_data ~= nil then
        dict.immortal_data = table.copy(self.immortal_data)
    end
end

function imp_player.set_username(self, new_name)
    if new_name == nil then
        flog("error", "Error in set_username, user name could not be nil")
        return false
    end

    self:_set("username", new_name)
end

function imp_player.set_vocation(self, new_vocation)
    if const.VOCATION_ID_TO_NAME[new_vocation] == nil then
        flog("error", "Error in set_vocation, invailed vocation -- "..new_vocation)
        return false
    end

    self:_set("vocation", new_vocation)
end

function imp_player.set_pos(self, x, y, z)
    self.posX= x
    self.posY= y
    self.posZ= z
end

function imp_player.is_player_die(self)
    if self.dead_time ~= -1 then
        if self.dead_time == -1 then
            return false
        end
        return true, self.dead_time
    else
        return false
    end
end

function imp_player.set_scene_id(self,scene_id)
    self.scene_id = scene_id
end

function imp_player.write_player_info_to_other(self,dict)
    dict.actor_id = self.actor_id
    dict.level = self.level
    dict.actor_name = self.actor_name
    dict.sex = self.sex
    dict.vocation = self.vocation
    dict.team_id = self.team_id
    dict.team_members_number = self:get_team_members_number()
    self:write_equipment_info_to_other(dict)
end

function imp_player.reset_dungeon_rebirth_time(self)
    self.dungeon_rebirth_time = 1
end

function imp_player.add_dungeon_rebirth_time(self)
    self.dungeon_rebirth_time = self.dungeon_rebirth_time + 1
end

function imp_player.player_rebirth(self,rebirth_type)
    flog("tmlDebug","imp_player.player_rebirth rebirth_type:"..rebirth_type)
    clear_die_state(self)
    if self.in_fight_server == false then
        local scene = self:get_scene()
        if scene == nil then
            return
        end
        local entity_manager = scene:get_entity_manager()
        if entity_manager == nil then
            return
        end
        local puppet = entity_manager.GetPuppet(self.entity_id)
        if puppet == nil then
            return
        end
        local is_city = false
        local data = {}

        local no_rebirth_pos = true
        if rebirth_type == REBIRTH_TYPE.rebirth_place_active or rebirth_type == REBIRTH_TYPE.rebirth_place_passive then
            local scene = self:get_scene()
            if scene ~= nil then
                local rebirth_pos = scene:get_nearest_rebirth_pos({self.posX,self.posY,self.posZ}, self.country)
                if rebirth_pos ~= nil then
                    if not self:is_in_arena_scene() then
                        self.posX = rebirth_pos[1]
                        self.posY = rebirth_pos[2]
                        self.posZ = rebirth_pos[3]
                    end
                    no_rebirth_pos = false
                end
            end
        else
            no_rebirth_pos = false
        end

        if no_rebirth_pos or rebirth_type == REBIRTH_TYPE.city_active or rebirth_type == REBIRTH_TYPE.city_passive then
            local city_id = const.CITY_SCENE_ID[self.country]
            local scene = scene_manager.find_scene(city_id)
            if scene ~= nil then
                local rebirth_pos = scene:get_nearest_rebirth_pos({self.posX,self.posY,self.posZ}, self.country)
                if rebirth_pos ~= nil then
                    self.scene_id = city_id
                    self.posX = rebirth_pos[1]
                    self.posY = rebirth_pos[2]
                    self.posZ = rebirth_pos[3]
                    local scene_resource_id = 0
                    local scene_type = 1
                    local scene_cfg = common_scene_config.get_scene_config(city_id)
                    if scene_cfg ~= nil then
                        scene_resource_id = scene_cfg.SceneID
                        scene_type = scene_cfg.SceneType
                    end
                    is_city = true
                    data = {current_hp=self.current_hp,scene_id=city_id,scene_resource_id = scene_resource_id,scene_type=scene_type }
                end
            end
        elseif rebirth_type == REBIRTH_TYPE.original_place then
            local posX,posY,posZ = self:get_pos()
            if not self:is_in_arena_scene() and posX ~= nil and posY ~= nil and posZ ~= nil then
                self.posX = posX
                self.posY = posY
                self.posZ = posZ
            end
        end

        if is_city then
            self.immortal_data.hp = nil
            self.immortal_data.mp = nil
            self:load_scene(0,data.scene_id)
        else
            self:pet_leave_scene()
            self.change_scene_buffs = puppet.skillManager:GetSceneRemainBuffInfo()
            scene:remove_player(self.entity_id)
            self.immortal_data.hp = nil
            self.immortal_data.mp = nil
            scene:add_player(self)
            self:pet_enter_scene()
        end
    else
        if rebirth_type == REBIRTH_TYPE.city_active or rebirth_type == REBIRTH_TYPE.city_passive then
            local city_id = const.CITY_SCENE_ID[self.country]
            local scene = scene_manager.find_scene(city_id)
            if scene ~= nil then
                local rebirth_pos = scene:get_nearest_rebirth_pos({self.posX,self.posY,self.posZ}, self.country)
                if rebirth_pos ~= nil then
                    self.scene_id = city_id
                    self.posX = rebirth_pos[1]
                    self.posY = rebirth_pos[2]
                    self.posZ = rebirth_pos[3]
                end
            end
            if self.fight_type == const.FIGHT_SERVER_TYPE.MAIN_DUNGEON then
                self:quit_dungeon(0)
            elseif self.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
                self:on_quit_team_dungeon({})
            elseif self.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
                self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_quit_task_dungeon"})
            elseif self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA or self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
                flog("error","arena can not city rebirth!!!")
            end
        else
            self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_player_rebirth",rebirth_type=rebirth_type})
        end
    end
    return
end

function imp_player.on_save_client_config(self, input)
    local key = input.key
    local value = input.value
    self.client_config[key] = value

    local output = {func_name = "GetClientConfigRet" }
    self:write_client_config(output)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_player.write_client_config(self, dict)
    dict.client_config = table.copy(self.client_config)
end

function imp_player.on_get_client_config(self, input)
    local output = {func_name = "GetClientConfigRet" }
    self:write_client_config(output)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_player.on_fight_avatar_initialize_complete(self,input,sync)
    flog("tmlDebug","imp_player.on_fight_avatar_initialize_complete")
    self:connet_fight_server()
    self:client_start_connect_server()
end

function imp_player.on_fight_avatar_leave_scene(self,input,sync)
    if self.in_fight_server == false then
        flog("debug","imp_player.on_fight_avatar_leave_scene in_fight_server == false")
        return
    end
    self.in_fight_server = false
    --如果在进入战斗服之后由于buff等导致野外死亡，直接复活
    if self.immortal_data.hp == 0 then
        self.immortal_data.hp = nil
        self.immortal_data.mp = nil
    end
    clear_die_state(self)
    if not self.is_offline then
        flog("debug","imp_player.on_fight_avatar_leave_scene player offline!")
        self:player_enter_common_scene()
    end
end

function imp_player.player_enter_common_scene(self)
    local scene_config = common_scene_config.get_scene_config(self.scene_id)
    if scene_config == nil then
        local scene_id = const.CITY_SCENE_ID[self.country]
        local scene = scene_manager.find_scene(scene_id)
        if scene ~= nil then
            local rebirth_pos = scene:get_nearest_rebirth_pos({self.posX,self.posY,self.posZ}, self.country)
            if rebirth_pos ~= nil then
                self.scene_id = scene_id
                self.posX = rebirth_pos[1]
                self.posY = rebirth_pos[2]
                self.posZ = rebirth_pos[3]
                scene_config = common_scene_config.get_scene_config(scene_id)
            end
        end
    end
    if scene_config == nil then
        return
    end
    self:load_scene(0,self.scene_id)
end

function imp_player.on_fight_state_changed(self,input,sync_data)
    self:fight_state_changed(input.fight_state)
end

function imp_player.fight_state_changed(self,fight_state)
    flog("tmlDebug","imp_player.fight_state_changed fight_state:"..tostring(fight_state))
    self.player_fight_state = fight_state
end


function imp_player.is_attackable(self, enemy_id)
    local scene = self:get_scene()
    if scene == nil then
        return
    end
    local enemy = scene:get_entity(enemy_id)
    if enemy == nil then
        flog("error", "get_entity by enemy_id failed "..enemy_id)
        return false
    end

    if enemy.on_get_owner ~= nil then
        enemy = enemy:on_get_owner()
    end

    if enemy.type == const.ENTITY_TYPE_PLAYER and self.type == const.ENTITY_TYPE_PLAYER then
        return self:is_player_attackable(enemy)
    else
        return false
    end
end

function imp_player.on_attack_entity(self, enemy_id, damage)
    local parent_on_attack_entity = entity_common.get_parent_func(self, "on_attack_entity")
    parent_on_attack_entity(self, enemy_id, damage)

    if self.type ~= const.ENTITY_TYPE_PLAYER then
        return
    end
    self:team_member_fight_data_statistics("damage", damage)
    local enemy = online_user.get_user(enemy_id)
    if enemy == nil or enemy.type ~= const.ENTITY_TYPE_PLAYER then
        return
    end
    self:on_attack_player(enemy)
end

function imp_player.entity_die(self, killer_id)
    local parent_entity_die = entity_common.get_parent_func(self, "entity_die")
    parent_entity_die(self, killer_id)

    self:on_player_die(killer_id)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="PlayerDieRet",result=0})
    self.die_buff_times = 0

    self:team_member_fight_data_statistics("die", 1)
    --玩家死亡宠物离开场景
    self:pet_leave_scene()
    local scene = self:get_scene()
    if scene == nil then
        return
    end

    local enemy = scene:get_entity(killer_id)
    if enemy == nil then
        return
    end
    if enemy.type == const.ENTITY_TYPE_PET then
        enemy = online_user.get_user(enemy.owner_id)
    end

    if enemy.type ~= const.ENTITY_TYPE_PLAYER then
        return
    end

    enemy:imp_country_on_kill_player(self)
    enemy:imp_pk_on_kill_player(self)
    enemy:imp_country_war_on_kill_player(self)

    enemy:team_member_fight_data_statistics("kill_player", 1)
    --玩家杀人任务,只有野外和主城
    if scene:get_scene_type() == const.SCENE_TYPE.WILD or scene:get_scene_type() == const.SCENE_TYPE.CITY then
        enemy:update_task_kill_player()
    end
    self:send_message_to_friend_server({func_name="on_killer_player_update_friend_value",killer_id=enemy.actor_id})
end

function imp_player.item_add_buff(self,buff_id)
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_item_add_buff",buff_id=buff_id})
        return 0
    end
    local entity_manager = self:get_entity_manager()
    if entity_manager == nil then
        return const.error_not_in_scene
    end
    local puppet = entity_manager.GetPuppet(self.entity_id)
    if puppet == nil then
        return const.error_not_in_scene
    end
    if puppet:IsDied() then
        return const.error_is_player_die
    end
    local skill_manager = puppet.skillManager
    if skill_manager == nil then
        return const.error_not_in_scene
    end
    skill_manager:AddBuff(buff_id)
    return 0
end

function imp_player.change_model_scale(self,scale,duration)
    self.model_scale = scale
    self.change_model_scale_time = _get_now_time_second() + duration
    destroy_change_model_timer(self)
    self.change_model_scale_timer = timer.create_timer(function()
        recovery_change_model_scale(self)
        destroy_change_model_timer(self)
    end,duration*1000,0,1)
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_change_model_scale",model_scale=scale})
        return
    else
        local puppet = self:get_puppet()
        if puppet ~= nil then
            puppet:SetDisguiseModelScale(scale)
        end
    end
end

function imp_player.on_disguise_model(self,model_id,duration)
    self.is_disguise = true
    self.disguise_model_id = model_id
    self.disguise_model_time = _get_now_time_second() + duration
    destroy_disguise_model_timer(self)
    self.disguise_model_timer = timer.create_timer(function()
        recovery_disguise_model(self)
        destroy_disguise_model_timer(self)
    end,duration*1000,0,1)
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_disguise_model",disguise_model_id=self.disguise_model_id,is_disguise=self.is_disguise})
    else
        local puppet = self:get_puppet()
        if puppet ~= nil then
            puppet:SetDisguiseModelId(self.disguise_model_id)
        end
    end
end

function imp_player.player_stealthy(self,duration)
    self.is_stealthy = true
    self.stealthy_time = _get_now_time_second() + duration
    destroy_stealthy_timer(self)
    self.stealthy_timer = timer.create_timer(function()
        recovery_from_stealthy(self)
        destroy_stealthy_timer(self)
    end,duration*1000,0,1)
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_player_stealthy",is_stealthy=self.is_stealthy})
    else
        local puppet = self:get_puppet()
        if puppet ~= nil then
            puppet:SetStealthy(self.is_stealthy)
        end
    end
end

local function player_change_name(self,new_name)
    self.actor_name = new_name
    self:update_player_info_to_arena("actor_name",new_name)
    self:send_message_to_friend_server({func_name="player_change_name",new_name=new_name})
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_player_change_name",new_name=new_name})
    else
        local puppet = self:get_puppet()
        if puppet ~= nil then
            puppet:SetName(self.actor_name)
        end
    end
end

function imp_player.on_change_name(self,input,sync_data)
    if input.item_pos == nil or input.item_id == nil or input.name == nil then
        return
    end
    if string_utf8len(input.name) <= const.PLAYER_NAME_MIN_LENTH or string_utf8len(input.name) >= const.PLAYER_NAME_MAX_LENTH then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name="UseBagItemReply",result = const.error_actor_name_length})
        return
    end
    --检查违禁字


    local item = self:get_item_by_pos(input.item_pos)
    if item == nil or item.cnt < 1 then
        self:send_message(const.ChangeNameReply, {result = const.error_item_not_enough})
        return
    end
    if item.id ~= input.item_id then
        return
    end
    local item_config = common_item_config.get_item_config(item.id)
    if item_config == nil then
        return
    end
    if item_config.Type ~= const.TYPE_CHANGE_NAME then
        return
    end

    local current_time = get_now_time_second()
    if self.next_change_name_time > current_time then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name="UseBagItemReply",result = const.error_change_name_interval_time,time=self.next_change_name_time - current_time})
        return
    end

    --是否重复
    data_base.db_insert_doc(self, function(self,status)
    if status == 0 then
        flog("info", "player change name, actor name overlap "..input.name)
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name="UseBagItemReply",result = const.error_actor_name_overlaps})
        return
    end
    player_change_name(self,input.name)
    self.next_change_name_time = current_time + tonumber(item_config.Para1)*86400
    self:remove_item_by_pos(input.item_pos,1)
    local info = {}
    self:imp_player_write_to_sync_dict(info)
    self:imp_assets_write_to_sync_dict(info)
    self:send_message(const.SC_MESSAGE_LUA_UPDATE,info)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name="UseBagItemReply",result = 0,change_player_name=true,new_name=input.name})
    end, "name_info", {actor_name = input.name})
end

function imp_player.play_item_effect(self,effect_path,duration,posX,posY,posZ)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="UseBagItemReply",result=0,play_effect=true,effect_path=effect_path,duration=duration,posX=posX,posY=posY,posZ=posZ})
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_play_item_effect",result=0,play_effect=true,effect_path=effect_path,duration=duration,posX=posX,posY=posY,posZ=posZ})
    else
        local scene = self:get_scene()
        if scene ~= nil then
            self:broadcast_to_aoi(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="UseBagItemReply",result=0,play_effect=true,effect_path=effect_path,duration=duration,posX=posX,posY=posY,posZ=posZ})
        end
    end
end

function imp_player.set_immortal_data(self, immortal_data)
    self.immortal_data = immortal_data
end

local function use_recovery_drug_result(self,result,pos,type,sync)
    if result == 0 then
        self:remove_item_by_pos(pos,1)
        self.drug_cds[type] = get_now_time_second() + common_parameter_formula_config.get_recovery_drug_cd(type)
        self:imp_assets_write_to_sync_dict(sync)
        self:imp_player_write_to_sync_dict(sync)
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=result,func_name="UseBagItemReply"})
end

function imp_player.on_use_recovery_drug(self,input,sync)
    if input.item_pos == nil then
        return
    end
    local pos = input.item_pos
    local count = 1
    local item = self:get_item_by_pos(pos)
    if item == nil or item.cnt < 1 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_item_not_enough,func_name="UseBagItemReply"})
        return
    end
    local item_config = common_item_config.get_item_config(item.id)
    if item_config == nil or item_config.Type ~= const.TYPE_RECOVERY_DRUG then
        flog("info","item is not recovery drug!")
        return
    end

    if self.level < item_config.LevelLimit then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="UseBagItemReply",result=const.error_level_not_enough})
        return
    end

    local type = math.floor(tonumber(item_config.Para1))
    local recovery_value = math.floor(tonumber(item_config.Para2))

    local current_time = get_now_time_second()
    if self.drug_cds[type] ~= nil and self.drug_cds[type] > current_time then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_recovery_drug_cd,func_name="UseBagItemReply"})
        return
    end

    if self.in_fight_server then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_fight_avatar_use_recovery_drug",type=type,recovery_value=recovery_value,pos=pos})
    else
        local result = self:use_recovery_drug(type,recovery_value)
        use_recovery_drug_result(self,result,pos,type,sync)
    end
end

function imp_player.on_fight_avatar_use_recovery_drug_reply(self,input,sync)
    if input.result == nil or input.pos == nil or input.type == nil then
        return
    end
    use_recovery_drug_result(self,input.result,input.pos,input.type,sync)
end

function imp_player.gm_set_puppet_value(self, key, value)
    local entity_manager = self:get_entity_manager()
    if entity_manager == nil then
        flog("error", "imp_player.gm_set_puppet_value: entity_manager is nil")
        return
    end
    local puppet = entity_manager.GetPuppet(self.actor_id)
    if puppet == nil then
        flog("error", "imp_player.gm_set_puppet_value: puppet is nil")
        return
    end
    if key == "hp" then
        puppet:SetHp(value)
    elseif key == "mp" then
        puppet:SetMp(value)
    end
end

function imp_player.gm_set_avatar_value(self, key, value)
    self:_set(key, value)
end

function imp_player.on_gm_set_avatar_value(self, input)
    local key = input.key

    self:_set(key, value)
end

function imp_player.get_online_user(self, actor_id)
    return online_user.get_user(actor_id)
end

function imp_player.is_in_fight_server(self)
    return self.in_fight_server
end

function imp_player.on_hp_changed(self, hp)
    self.current_hp = hp
    self:imp_teamup_update_current_hp(self)
end

function imp_player.send_to_self_game(self, data)
    local func_name = data.func_name
    self[func_name](self, data)
end

function imp_player.gm_set_open_day(self, date_str)
    local new_open_time = set_open_day(date_str)
    local tip_string
    if new_open_time == nil then
        tip_string = fix_string.param_format_error
    else
        tip_string = string.format(fix_string.show_current_open_day, new_open_time.year, new_open_time.month, new_open_time.day)
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "ServerTipsMessage", message = tip_string})
end

function imp_player.on_fight_server_disconnet(self,input,sync_data)
    if self.in_fight_server == false then
        return
    end
    self:on_fight_avatar_leave_scene(input,sync_data)
    local fight_type = input.fight_type
    if fight_type == nil then
        return
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="FightServerDisconnetRet"})
    if self.fight_type == const.FIGHT_SERVER_TYPE.MAIN_DUNGEON then
        self:on_fight_avatar_leave_main_dungeon()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.TEAM_DUNGEON then
        self:on_fight_avatar_leave_team_dungeon()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.TASK_DUNGEON then
        self:on_fight_avatar_leave_task_dungeon()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
        self:arena_qualifying_fight_over(false)
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
        self:fight_server_disconnect_dogfight_arena()
    end
end

function imp_player.init_new_player_data(self)
    self.client_config["AutoHealthSupple"] = true
    self.client_config["AutoMagicSupple"] = true
    self.client_config["HealthSuppleThreshold"] = 70
    self.client_config["MagicSuppleThreshold"] = 70

    self:init_new_player_fashion()
end

function imp_player.check_player_dead(self)
    if self.dead_time ~= -1 and (self.rebirth_type == "A" or self.rebirth_type == "B") then
        notice_client_rebirth_info(self,const.SC_MESSAGE_LUA_GAME_RPC)
    end
end

function imp_player.clear_player_timers(self)
    destroy_rebirth_timer(self)
    destroy_change_model_timer(self)
    destroy_disguise_model_timer(self)
    destroy_stealthy_timer(self)
end

function imp_player.reenter_aoi_scene(self)
    --如果玩家在战斗服务器，不需要处理场景
    if self.in_fight_server then
        return
    end
    --如果掉线过程中战斗服务器完成战斗，这里需要直接进入场景
    if self:get_scene() == nil then
        self:player_enter_common_scene()
    else
        --进出场景以同步状态
        self:imp_aoi_set_pos()
        self:leave_aoi_scene()
        self:enter_aoi_scene(self.scene_id)
    end
end

function imp_player.set_replace_flag(self,value)
    self.replace_flag = value
end

function imp_player.on_attack_monster(self,monster)
    self.country_war_attack_monster(self,monster:GetSceneID(),monster.data.ElementID)
    local obj_type = monster.data.sceneType
    if obj_type == const.ENTITY_TYPE_TRANSPORT_FLEET then
        self.country_war_attack_transport_fleet(self,monster.uid)
    end
end

function imp_player.change_value_on_rank_list(self, key, value)
    self:_set(key, value)
    self:update_player_value_to_rank_list(key)
end

register_message_handler(const.CS_MESSAGE_LUA_LOGIN, on_player_login)
register_message_handler(const.CS_MESSAGE_LUA_GM, on_gm_command)
register_message_handler(const.OG_MESSAGE_LUA_GAME_RPC,on_game_rpc)
register_message_handler(const.CS_MESSAGE_LUA_GAME_RPC,on_game_rpc)
register_message_handler(const.CS_MESSAGE_LUA_GAME_RPC,SyncManager.on_server_rpc)       --注册技能RPC消息
register_message_handler(const.CS_MESSAGE_LUA_QUERY_PLAYER,on_get_player_info)
register_message_handler(const.SS_MESSAGE_LUA_USER_LOGOUT,on_player_logout)

imp_player.__message_handler = {}
imp_player.__message_handler.on_player_login = on_player_login
imp_player.__message_handler.on_gm_command = on_gm_command
imp_player.__message_handler.on_game_rpc = on_game_rpc
imp_player.__message_handler.on_get_player_info = on_get_player_info
imp_player.__message_handler.on_player_logout = on_player_logout

return imp_player