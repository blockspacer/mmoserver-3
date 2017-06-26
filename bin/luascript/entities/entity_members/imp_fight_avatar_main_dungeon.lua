--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/23 0023
-- Time: 17:39
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local math = require "math"
local drop_manager = require("helper/drop_manager")
local main_dungeon_drop_manager = drop_manager("main_dungeon")
local fight_data_statistics = require "helper/fight_data_statistics"
local main_dungeon_center = main_dungeon_center

local imp_fight_avatar_main_dungeon = {}
imp_fight_avatar_main_dungeon.__index = imp_fight_avatar_main_dungeon

setmetatable(imp_fight_avatar_main_dungeon, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {

}
imp_fight_avatar_main_dungeon.__params = params

function imp_fight_avatar_main_dungeon.__ctor(self)

end

function imp_fight_avatar_main_dungeon.imp_fight_avatar_main_dungeon_init_from_dict(self, dict)

end

function imp_fight_avatar_main_dungeon.on_connect_main_dungeon_server(self)
    flog("tmlDebug","imp_fight_avatar_main_dungeon.on_connect_main_dungeon_server")
    local reply_data = {}
    reply_data.func_name = "ConnectMainDungeonServerReply"
    reply_data.result = 0
    local check = main_dungeon_center:check_player(self.actor_id,self.fight_id)
    if check == true then
        local aoi_scene_id = main_dungeon_center:get_main_dungeon_aoi_scene_id(self.fight_id)
        if aoi_scene_id == nil then
            flog("tmlDebug","imp_fight_avatar_main_dungeon.on_connect_main_dungeon_server aoi_scene_id == nil")
            reply_data.result = const.error_main_dungeon_can_not_find_scene
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end
        local scene = main_dungeon_scene_manager.find_scene(aoi_scene_id)
        if scene == nil then
            flog("tmlDebug","imp_fight_avatar_main_dungeon.on_connect_main_dungeon_server scene == nil")
            reply_data.result = const.error_main_dungeon_can_not_find_scene
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end
        local born_pos = scene:get_random_born_pos()
        if born_pos == nil then
            flog("tmlDebug","imp_fight_avatar_main_dungeon.on_connect_team_dungeon_server born_pos == nil")
            reply_data.result = const.error_can_not_find_scene_born_pos
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end
        reply_data.scene_id = scene:get_table_scene_id()
        reply_data.aoi_scene_id = scene:get_scene_id()
        reply_data.scene_type = scene:get_scene_type()
        reply_data.scene_resource_id = scene:get_scene_resource_id()
        reply_data.posX = math.floor(born_pos[1]*100)
        reply_data.posY = math.floor(born_pos[2]*100)
        reply_data.posZ = math.floor(born_pos[3]*100)
        self.posX = born_pos[1]
        self.posY = born_pos[2]
        self.posZ = born_pos[3]
        self.rotation = born_pos[4]
        self.scene_id = scene:get_table_scene_id()
        reply_data.result = 0
        self:send_message(const.SC_MESSAGE_LUA_START_DUNGEON,reply_data)
        self:load_aoi_scene(aoi_scene_id,scene:get_table_scene_id(),scene:get_scene_id(),scene:get_scene_type(),scene:get_scene_resource_id())
    else
        reply_data.result = const.error_data
        self:send_message(const.SC_MESSAGE_LUA_START_DUNGEON,reply_data)
    end
    return
end

local function leave_main_dungeon(self)
    self.dungeon_in_playing = const.DUNGEON_NOT_EXIST
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="PlayerLeaveMainDungeonScene"})
    self:disconnet_fight_server()
    self:fight_send_to_game({func_name="on_fight_avatar_leave_main_dungeon"})
end

function imp_fight_avatar_main_dungeon.on_leave_main_dungeon(self)
    leave_main_dungeon(self)
end

function imp_fight_avatar_main_dungeon.on_fight_avatar_leave_main_dungeon(self,input)
    flog("tmlDebug","imp_fight_avatar_main_dungeon.on_fight_avatar_leave_main_dungeon")
    leave_main_dungeon(self)
    if input.quit ~= nil then
        main_dungeon_center:leave_main_dungeon(self.fight_id)
    end
end

function imp_fight_avatar_main_dungeon.start_main_dungeon(self)
    flog("tmlDebug","imp_fight_avatar_main_dungeon.start_main_dungeon")
    if self.dungeon_id ~= nil then
        self:on_connect_main_dungeon_server()
        local dungeon_id = main_dungeon_center:get_player_dungeon_id(self.combat_info.actor_id,self.fight_id)
        if dungeon_id ~= nil then
            self:fight_send_to_game({func_name="on_enter_main_dungeon_success",dungeon_id=dungeon_id})
        end
        self.dungeon_in_playing = dungeon_id
        self.drop_manager = main_dungeon_drop_manager
    end
    fight_data_statistics.add_player_data(self.actor_id, self.actor_name, self.vocation)
end

return imp_fight_avatar_main_dungeon

