--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/22 0022
-- Time: 11:08
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local math = require "math"
local flog = require "basic/log"
local line = require "global_line/line"
local forward_message_to_game = require("basic/net").forward_message_to_game
local self_game_id = _get_serverid()
local db_hiredis = require "basic/db_hiredis"
local tonumber = tonumber
local tostring = tostring
local common_npc_config = require "configs/common_npc_config"
local common_scene_config = require "configs/common_scene_config"
local system_faction_config = require "configs/system_faction_config"

local params = {}
local imp_aoi = {}
imp_aoi.__index = imp_aoi

setmetatable(imp_aoi, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_aoi.__params = params

function imp_aoi.__ctor(self)
    self.scene = nil
end

local function on_enter_scene(self,input,syn_data)
    if input.scene_id == const.FACTION_SCENE_ID then
        if self:enter_faction_scene() then
            return
        else
            self:reset_player_position()
            input.scene_id = self.scene_id
        end
    end

    local result = self:can_enter_scene(input.scene_id)
    local scene_cfg = common_scene_config.get_scene_config(input.scene_id)
    if scene_cfg ~= nil then
        self:load_scene(result,input.scene_id)
    else
        self:send_message(const.SC_MESSAGE_LUA_ENTER_SCENE,{result = result,scene_id=input.scene_id})
    end
    --self:imp_player_write_to_sync_dict(syn_data)
end

local function on_scene_loaded(self,input,syn_data)
    local result = self:enter_aoi_scene(input.scene_id)
    flog("info", "self:enter_aoi_scene result "..result)
    self:send_message(const.SC_MESSAGE_LUA_LOADED_SCENE,{result = result,scene_id=input.scene_id,aoi_scene_id=self:get_aoi_scene_id()})
end

function imp_aoi.imp_aoi_init_from_dict(self,dict)
end

function imp_aoi.imp_aoi_init_from_other_game_dict(self,dict)
    self.is_changing_scene = dict.is_changing_scene
end

function imp_aoi.imp_aoi_write_to_dict(self,dict)
end

function imp_aoi.imp_aoi_write_to_other_game_dict(self,dict)
    dict.is_changing_scene = self.is_changing_scene
    local puppet = self:get_puppet()
    if puppet ~= nil then
        self.change_scene_buffs = puppet.skillManager:GetSceneRemainBuffInfo()
    end
end

function imp_aoi.imp_aoi_write_to_sync_dict(self,dict)
end

function imp_aoi.get_common_data(self)
    local data = {}
    data.actor_id = self.actor_id
    data.actor_name = self.actor_name
    data.level = self.level
    data.vocation = self.vocation
    data.country = self.country
    data.sex = self.sex
    data.entity_type = self.type
    data.entity_id = self.entity_id
    data.scene_id = self.scene_id

    for index, value in pairs(self.appearance) do
        local aoi_index = self.get_appearance_aoi_index(index)
        data['appearance_'..aoi_index] = value
    end

    return data
end

function imp_aoi.imp_aoi_set_pos(self)
    flog("tmlDebug","imp_aoi.imp_aoi_set_pos")
    local scene = self:get_scene()
    if scene == nil then
        return
    end
    --帮派领地？
--    if scene:get_table_scene_id() ~= self.scene_id then
--        return
--    end

    if self:get_puppet() == nil then
        flog("tmlDebug","imp_aoi.imp_aoi_set_pos puppet == nil")
        return
    end
    local x,y,z = self:get_pos()
    self:set_pos(x,y,z)
end

function imp_aoi.load_scene(self,result,scene_id)
    local scene_cfg = common_scene_config.get_scene_config(scene_id)
    if scene_cfg ~= nil then
        self:leave_aoi_scene()
        self:auto_select_scene_line()
    end
end

function imp_aoi.can_enter_scene(self,scene_id)
    flog("tmlDebug","imp_aoi.can_enter_scene,id "..scene_id)
    if self.scene ~= nil then
        if self.scene.scene_id == scene_id then
            return const.error_scene_in_same_scene
        end
    end

    local scene_cfg = common_scene_config.get_scene_config(scene_id)
    if scene_cfg == nil then
        _info("scene is not exist,scene_id:"..scene_id)
        return const.error_scene_not_exist
    end
    if self:get("level") < scene_cfg.EnterLevel then
        return const.error_level_not_enough
    end
    if scene_cfg.Party ~= 0 and scene_cfg.Party ~= self.country then
        return const.error_self_country_can_not_enter
    end

    return 0
end

function imp_aoi.enter_aoi_scene(self,scene_id)
    flog("info","imp_aoi.enter_aoi_scene,id "..scene_id)
    local err = self:can_enter_scene(scene_id)
    if err ~= 0 then
        return err
    end

    flog("syzDebug", "imp_aoi.enter_aoi_scene 1")
    if self.scene ~= nil then
        self:leave_aoi_scene()
    end
    local scene = scene_manager.find_scene(scene_id)
    if scene == nil then
        flog("debug","can not find scene,id "..scene_id)
        return const.error_scene_not_exist
    end

    local entity = scene:get_entity(self.actor_id)
    if entity ~= nil then
        flog("warn","entity is already in scene!actor_id "..self.actor_id..",scene id "..scene_id)
        self:pet_leave_scene_by_id(scene_id)
        scene:remove_player(self.entity_id)
    end
    --玩家遗留在场景里？
    local avatar_puppet = scene:get_entity_manager().GetPuppet(self.actor_id)
    if avatar_puppet ~= nil then
        flog("warn","entity is already in aoi scene!actor_id "..self.actor_id..",scene id "..scene_id)
        self:pet_leave_scene_by_id(scene_id)
        scene:remove_player(self.actor_id)
    end

    flog("syzDebug", "imp_aoi.enter_aoi_scene 2")
    self.scene_id = scene_id
    self:set_scene_id(scene_id)
    scene:add_player(self)
    self.scene = scene
    self:pet_enter_scene()
    self:check_player_dead()
    self.is_changing_scene = false
    flog("syzDebug", "imp_aoi.enter_aoi_scene 4")
    db_hiredis.zincrby("scene_"..scene_id,1,tostring(self_game_id))
    self:send_message_to_line_server({func_name="on_scene_player_count_change",scene_id=self.scene:get_table_scene_id(),addon=1})
    self:send_current_game_line_to_client()
    return 0
end

function imp_aoi.on_loaded_faction_scene(self)
    flog("info","imp_aoi.enter_faction_scene")
    local scene = faction_scene_manager.find_faction_scene(self.faction_id)
    if scene == nil then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_faction_scene_not_start,func_name="OnLoadedFactionSceneRet"})
        return
    end

    if self.scene ~= nil then
        self:leave_aoi_scene()
    end

    local entity = scene:get_entity(self.actor_id)
    if entity ~= nil then
        flog("warn","enter_faction_scene entity is already in scene!actor_id "..self.actor_id..",scene id "..const.FACTION_SCENE_ID)
        self:pet_leave_scene_by_id(scene:get_scene_id())
        scene:remove_player(self.entity_id)
    end
    --玩家遗留在场景里？
    local avatar_puppet = scene:get_entity_manager().GetPuppet(self.actor_id)
    if avatar_puppet ~= nil then
        flog("warn","enter_faction_scene entity is already in aoi scene!actor_id "..self.actor_id..",scene id "..const.FACTION_SCENE_ID)
        self:pet_leave_scene_by_id(scene:get_scene_id())
        scene:remove_player(self.actor_id)
    end

    scene:add_player(self)
    self.scene = scene
    self:pet_enter_scene()
    self:check_player_dead()
    self.is_changing_scene = false
    self:send_current_game_line_to_client()
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="OnLoadedFactionSceneRet",scene_id = self.scene_id,aoi_scene_id=scene:get_scene_id()})
end

function imp_aoi.leave_aoi_scene(self)
    self:pet_leave_scene()
    if self.scene ~= nil then
        local puppet = self:get_puppet()
        if puppet ~= nil then
            self.change_scene_buffs = puppet.skillManager:GetSceneRemainBuffInfo()
        end
        self.scene:remove_player(self.entity_id)
        db_hiredis.zincrby("scene_"..self.scene:get_table_scene_id(),-1,tostring(self_game_id))
        self:send_message_to_line_server({func_name="on_scene_player_count_change",scene_id=self.scene:get_table_scene_id(),addon=-1})
        self.scene = nil
    end

    return 0
end

function imp_aoi.get_info_to_scene(self)
    local data = self:get_common_data()
    data.posX = self.posX
    data.posY = self.posY
    data.posZ = self.posZ
    -- TODO 添加数据库保存的immortal数据
    table.update(data, self.immortal_data)
    self:imp_property_write_to_sync_dict(data)
    self:imp_skill_write_to_sync_dict(data)
    data.kill_by_player = self.kill_by_player
    self.kill_by_player = false
    data.server_object = self
    data.buffs = self.change_scene_buffs
    self.change_scene_buffs = nil
    return data
end

local function _get_scene_detail(scene_id)
    return common_scene_config.get_scene_detail_config(scene_id)
end


function imp_aoi.on_mini_map_switch_scene(self, input)
    flog("syzDebug", "imp_aoi.on_mini_map_switch_scene "..input.scene_id)
    if self.is_changing_scene then
        return
    end
    local result = self:is_operation_allowed("mini_map_teleportation")
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_ENTER_SCENE, {result = result, func_name = "MapTeleportationRet"})
    end

    local current_scene_id = self:get_aoi_scene_id()
    if current_scene_id == input.scene_id then
        return
    end

    local target_scene_id = input.scene_id
    local scene_cfg = common_scene_config.get_scene_config(target_scene_id)
    if scene_cfg == nil then
        return
    end
    local target_born_pos
    local target_item_id = scene_cfg["Location"..self.country]
    if target_item_id == 0 then
        self:send_message(const.SC_MESSAGE_LUA_ENTER_SCENE,{result = const.error_self_country_can_not_transport,scene_id = target_scene_id})
    end

    local target_scene_cfg = _get_scene_detail(target_scene_id)
    local target_item_cfg = target_scene_cfg[target_item_id]
    if target_item_cfg == nil then
        flog("error", "imp_aoi.on_mini_map_switch_scene not exisit scene "..target_scene_id.." item "..target_item_id)
        return
    end

    local result = self:can_enter_scene(target_scene_id)
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_ENTER_SCENE,{result = result,scene_id = target_scene_id})
    end

    self.posX = target_item_cfg.PosX
    self.posY = target_item_cfg.PosY
    self.posZ = target_item_cfg.PosZ
    self.scene_id = target_scene_id
    --self:leave_aoi_scene()
    self:load_scene(0,target_scene_id)
end


function imp_aoi.on_random_transport(self,distance)
    if self.is_changing_scene == true then
        flog("tmlDebug","imp_aoi.on_random_transport self.is_changing_scene == true")
        return false
    end
    if self:get_scene() == nil then
        flog("tmlDebug","imp_aoi.on_random_transport self:get_scene() == nil")
        return false
    end
    local cx,cy,cz = self:get_pos()
    local count = 0
    repeat
        local random_distance = math.random()*distance
        local random_sign = math.random()
        local gx = cx
        if random_sign < 0.5 then
            gx = gx + random_distance
        else
            gx = gx - random_distance
        end

        local gy = cy

        random_distance = math.random()*distance
        random_sign = math.random()
        local gz = cz
        if random_sign < 0.5 then
            gz = gz + random_distance
        else
            gz = gz - random_distance
        end
        local res,x,y,z = _get_nearest_poly_of_point(self:get_aoi_scene_id(), gx, gy, gz)
        if res == true then
            return res,x,y,z
        end
    until(count > 100)
    return false
end

function imp_aoi.is_in_normal_scene(self)
    return self.scene_id == self:get_aoi_scene_id()
end

function imp_aoi.on_back_to_born_point(self, input)
    local scene = scene_manager.find_scene(self:get_aoi_scene_id())
    if scene == nil then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name = "MoveToAppointPos", result = const.error_scene_not_exist})
    end

    local pos = scene:get_random_born_pos()
    if pos == nil then
        flog("error", "on_back_to_born_point get_random_born_pos fail")
    end
    local client_pos = {}
    for i, v in pairs(pos) do
        client_pos[i] = math.ceil(v * 100)
    end

    return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name = "MoveToAppointPos", result = 0, pos = client_pos})
end

function imp_aoi.fight_avatar_notice_leave_aoi_scene(self)
    self:imp_aoi_set_pos()
    self:leave_aoi_scene()
end

function imp_aoi.go_to_other_game(self,target_game_id,operation)
    --去其他分线
    local user_manage = require "login_server/user_manage"
    local login_user_data = user_manage.get_login_user_data(self.session_id)
    if login_user_data == nil then
        flog("warn","go_to_other_game login_user_data is nil!")
        if operation == const.LINE_OPERATION.auto then
            self:on_enter_scene_ret()
        elseif operation == const.LINE_OPERATION.faction then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=const.error_data,func_name="OnNpcTransportRet"})
        end
        return false
    end
    local actor_data = self:write_to_other_game_dict()
    forward_message_to_game(target_game_id,const.OG_MESSAGE_LUA_GAME_RPC,{func_name="on_player_change_game_line",login_user_data=login_user_data,actor_data=actor_data,operation=operation})
    user_manage.start_change_game_line(self.session_id)
    self:clear_player_data_when_change_game_line()
    return true
end

function imp_aoi.auto_select_scene_line(self)
    flog("tmlDebug","imp_aoi.auto_select_scene_line")
    local target_game_id = self_game_id
    if self:is_follow() then
        local captain_id = self:get_team_captain_id()
        if captain_id ~= nil then
            local result = db_hiredis.hget("role_state", captain_id)
            if result ~= nil then
                target_game_id = result.game_id
            end
        end
    end
    local game_id = line.auto_select_line(self.scene_id,target_game_id,self:is_follow())
    if game_id == nil then
         flog("warn","can not find valid game line!!!scene_id "..self.scene_id)
        return
    end
    --本线
    if game_id == self_game_id then
        self:on_enter_scene_ret()
        return
    end
    self:go_to_other_game(game_id,const.LINE_OPERATION.auto)
end

function imp_aoi.on_enter_scene_ret(self)
    local scene_cfg = common_scene_config.get_scene_config(self.scene_id)
    if scene_cfg ~= nil then
        self:send_message(const.SC_MESSAGE_LUA_ENTER_SCENE,{result = 0,scene_id=self.scene_id,scene_resource_id = scene_cfg.SceneID,scene_type = scene_cfg.SceneType,posX=math.floor(self.posX*100),posY=math.floor(self.posY*100),posZ=math.floor(self.posZ*100),aoi_scene_id=self.scene_id})
    end
end

function imp_aoi.on_enter_faction_scene_ret(self)
    local scene_cfg = system_faction_config.get_faction_scene_config(const.FACTION_SCENE_ID)
    if scene_cfg == nil then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result = const.error_data,func_name="OnEnterFactionSceneRet"})
        return
    end
    local scene = faction_scene_manager.find_faction_scene(self.faction_id)
    if scene == nil then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result = const.error_faction_scene_not_start,func_name="OnEnterFactionSceneRet"})
        if self.scene_id == const.FACTION_SCENE_ID then
            self:reset_player_position()
            self:send_message(const.SC_MESSAGE_LUA_ENTER_SCENE,{result = 0,scene_id=self.scene_id,scene_resource_id = scene_cfg.SceneID,scene_type = scene_cfg.SceneType,posX=math.floor(self.posX*100),posY=math.floor(self.posY*100),posZ=math.floor(self.posZ*100)})
        end
        return
    end
    if self.scene_id ~= const.FACTION_SCENE_ID then
        self.scene_id = const.FACTION_SCENE_ID
        local pos = scene:get_random_born_pos()
        self.posX = pos[1]
        self.posY = pos[2]
        self.posZ = pos[3]
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result = 0,func_name="OnEnterFactionSceneRet",scene_id=const.FACTION_SCENE_ID,scene_resource_id = scene_cfg.SceneID,scene_type = scene_cfg.SceneType,posX=math.floor(self.posX*100),posY=math.floor(self.posY*100),posZ=math.floor(self.posZ*100),aoi_scene_id=scene:get_scene_id()})
end

function imp_aoi.on_query_scene_lines(self,input)
    flog("tmlDebug","imp_aoi.on_query_scene_line")
     local scene = self:get_scene()
    if scene ~= nil and scene:get_table_scene_id() == const.FACTION_SCENE_ID then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnQuerySceneLinesRet",result=0,lines={[1]={key=1,value=1}}})
        return
    end
    local lines = db_hiredis.zrangebyscore("scene_"..self.scene_id,-10000,10000,true)
    for i=#lines,1,-1 do
        local line_id = line.get_line_by_game_id(tonumber(lines[i].key))
        if line_id == nil then
            flog("debug","can not find line by game id "..lines[i].key)
            table.remove(lines,i)
        else
            lines[i].key = line_id
        end
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnQuerySceneLinesRet",result=0,lines=lines})
end

local function manual_select_scene_line_callback(self,error,target_game_id)
    if error ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnChangeGameLineRet",result=error})
        return
    end
    if self.immortal_data.hp ~= nil and self.immortal_data.hp <= 0 then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnChangeGameLineRet",result = const.error_is_player_die})
        return
    end
    self:imp_aoi_set_pos()
    --self:leave_aoi_scene()
    self:go_to_other_game(target_game_id,const.LINE_OPERATION.manual)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnChangeGameLineRet",result = 0})
end

function imp_aoi.on_change_game_line(self,input)
    flog("tmlDebug","on_change_game_line")
    if self.in_fight_server then
        flog("tmlDebug","in_fight_server is true")
        return
    end

    if (input.follow ==nil or input.follow == false) and self.player_fight_state then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnChangeGameLineRet",result = const.error_select_game_line_fight})
        return
    end

    if input.game_id == nil then
        flog("tmlDebug","input.game_id == nil")
        return
    end

    local game_id = line.get_game_id_by_line(input.game_id)
    if game_id == nil then
        flog("tmlDebug","can not find game_id by line "..input.game_id)
        return
    end

    if game_id == self_game_id then
        flog("tmlDebug","input.game_id == self_game_id")
        return
    end

    local follow = false
    if self:is_follow() then
        if input.follow then
            follow = true
        else
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnChangeGameLineRet",result = const.error_select_game_line_follow})
            return
        end
    end

    line.manual_select_game_line(self,manual_select_scene_line_callback,self.scene_id,game_id,follow)
end

function imp_aoi.send_current_game_line_to_client(self)
    --帮派领地特殊处理
    local scene = self:get_scene()
    if scene ~= nil and scene:get_table_scene_id() == const.FACTION_SCENE_ID then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="OnUpdateGameLineRet",game_id=1})
    end
    local line = line.get_line_by_game_id(self_game_id)
    if line == nil then
        flog("tmlDebug","send_current_game_line_to_client line == nil self_game_id "..self_game_id)
        return
    end
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="OnUpdateGameLineRet",game_id=line})
end

function imp_aoi.on_fight_avatar_enter_aoi_scene(self)
    self:check_player_dead()
end

local function _transport_cost(self,transport_id)
    local transport_config = common_npc_config.get_transport_npc_config(transport_id)
    if transport_config == nil then
        flog("tmlDebug","imp_aoi.on_npc_transport transport_config == nil ")
        return
    end
    if #transport_config.Cost == 2 then
        self:remove_item_by_id(transport_config.Cost[1],transport_config.Cost[2])
        local data = {}
        data.result = 0
        self:imp_assets_write_to_sync_dict(data)
        self:send_message(const.SC_MESSAGE_LUA_UPDATE,data)
    end
end

local function _go_to_faction_scene(self,transport_id)
    if self.faction_scene_gameid == self_game_id then
        self:on_enter_faction_scene_ret()
        _transport_cost(self,transport_id)
        return
    end

    if self:go_to_other_game(self.faction_scene_gameid,const.LINE_OPERATION.faction) then
        _transport_cost(self,transport_id)
    end
end

function imp_aoi.on_query_faction_scene_gameid_ret(self,input)
    if input.result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = input.result, func_name = "OnNpcTransportRet"})
    end
    self.faction_scene_gameid = input.faction_scene_gameid
    _go_to_faction_scene(self,input.transport_id)
end

function imp_aoi.enter_faction_scene(self)
    if self.in_fight_server then
        return false
    end

    if not self:is_have_faction() then
        return false
    end

    if self.faction_scene_gameid > 0 then
        _go_to_faction_scene(self,nil)
    else
        self:send_message_to_faction_server({func_name="on_query_faction_scene_gameid",transport_id=nil,faction_id=self.faction_id})
    end
    return true
end

function imp_aoi.on_npc_transport(self,input,sync_data)
    if self.is_changing_scene then
        return
    end
    local result = self:is_operation_allowed("map_teleportation")
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "OnNpcTransportRet"})
    end

    if self.in_fight_server then
        flog("tmlDebug","on_npc_transport in fight server!")
        return
    end

    local id = input.id
    local transport_config = common_npc_config.get_transport_npc_config(id)
    if transport_config == nil then
        flog("tmlDebug","imp_aoi.on_npc_transport transport_config == nil "..transport_config)
        return
    end

    local scene = self:get_scene()
    if scene ~= nil and scene:get_table_scene_id() == transport_config.Scene then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnNpcTransportRet",result=const.error_scene_in_same_scene})
        return
    end
    --消耗
    if #transport_config.Cost == 2 then
        if not self:is_enough_by_id(transport_config.Cost[1],transport_config.Cost[2]) then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnNpcTransportRet",result=const.error_item_not_enough})
            return
        end
    end
    --帮派地图
    if transport_config.Scene == const.FACTION_SCENE_ID then
        local element_config = system_faction_config.get_scene_element_config(transport_config.Scene,transport_config.EleID)
        if element_config == nil then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnNpcTransportRet",result=const.error_transport_target_not_exist})
            flog("tmlDebug","can not find tansport target scene "..transport_config.Scene..",element "..transport_config.EleID)
            return
        end

        if not self:is_have_faction() then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnNpcTransportRet",result=const.error_have_not_faction})
            return
        end

        if self.faction_scene_gameid > 0 then
            _go_to_faction_scene(self,id)
        else
            self:send_message_to_faction_server({func_name="on_query_faction_scene_gameid",transport_id=id,faction_id=self.faction_id})
        end
    else
        if transport_config.Camp ~= 0 and transport_config.Camp ~= self.country then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnNpcTransportRet",result=const.error_transport_other_country})
            return
        end
        local element_config = common_scene_config.get_scene_element_config(transport_config.Scene,transport_config.EleID)
        if element_config == nil then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnNpcTransportRet",result=const.error_transport_target_not_exist})
            flog("tmlDebug","can not find tansport target scene "..transport_config.Scene..",element "..transport_config.EleID)
            return
        end

        local result = self:can_enter_scene(transport_config.Scene)
        if result ~= 0 then
            self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="OnNpcTransportRet",result=result})
            flog("tmlDebug","can not enter target scene "..transport_config.Scene)
            return
        end
        if #transport_config.Cost == 2 then
            self:remove_item_by_id(transport_config.Cost[1],transport_config.Cost[2])
            self:imp_assets_write_to_sync_dict(sync_data)
        end
        self.posX = element_config.PosX
        self.posY = element_config.PosY
        self.posZ = element_config.PosZ
        self.scene_id = transport_config.Scene
        self:load_scene(result,transport_config.Scene)
    end
end

--在出现异常时，重置玩家位置
function imp_aoi.reset_player_position(self)
    self.scene_id = const.CITY_SCENE_ID[self.country]
    local pos = common_scene_config.get_random_born_pos(self.scene_id)
    if pos ~= nil then
        self.posX = pos[1]
        self.posY = pos[2]
        self.posZ = pos[3]
    end
end

--召集
function imp_aoi.on_response_convene(self,scene_id,game_id,x,y,z)
    if game_id == self_game_id then
        flog("debug","on same line!!!")
        return
    end

    if self.immortal_data.hp ~= nil and self.immortal_data.hp <= 0 then
        return const.error_is_player_die
    end

    local result = line.response_convene(scene_id,game_id)
    if result ~= 0 then
        return result
    end

    local operation = const.LINE_OPERATION.convene_same_scene
    self.posX=x
    self.posY=y
    self.posZ=z
    if self.scene_id ~= scene_id then
        self.scene_id = scene_id
        operation = const.LINE_OPERATION.convene_diffrent_scene
    end

    if not self:go_to_other_game(game_id,operation) then
        return const.error_data
    end
    return 0
end

register_message_handler(const.CS_MESSAGE_LUA_ENTER_SCENE,on_enter_scene)
register_message_handler(const.CS_MESSAGE_LUA_LOADED_SCENE,on_scene_loaded)

imp_aoi.__message_handler = {}
imp_aoi.__message_handler.on_enter_scene = on_enter_scene
imp_aoi.__message_handler.on_scene_loaded = on_scene_loaded

return imp_aoi

