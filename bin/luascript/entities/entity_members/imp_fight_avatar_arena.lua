--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/10 0010
-- Time: 13:27
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"
local math = require "math"
local qualifying_arena_fight_center = require "fight_server/qualifying_arena_fight_center"
local get_now_time_second = _get_now_time_second
local challenge_arena_config = require "configs/challenge_arena_config"
local dogfight_arena_fight_center = require "fight_server/dogfight_arena_fight_center"

local imp_fight_avatar_arena = {}
imp_fight_avatar_arena.__index = imp_fight_avatar_arena

setmetatable(imp_fight_avatar_arena, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {

}
imp_fight_avatar_arena.__params = params

function imp_fight_avatar_arena.__ctor(self)

end

function imp_fight_avatar_arena.imp_fight_avatar_arena_init_from_dict(self, dict)

end

function imp_fight_avatar_arena.on_connect_qualifying_arena_server(self)
    flog("tmlDebug","imp_fight_avatar_arena.on_connect_qualifying_arena_server")
    local reply_data = {}
    reply_data.result = 0
    local check = qualifying_arena_fight_center:check_player(self.actor_id,self.fight_id)
    if check == true then
        local aoi_scene_id = qualifying_arena_fight_center:get_aoi_scene_id(self.fight_id)
        if aoi_scene_id == nil then
            flog("tmlDebug","imp_fight_avatar_arena.on_connect_qualifying_arena_server aoi_scene_id == nil")
            reply_data.result = const.error_scene_not_exist
            self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,reply_data)
            return
        end
        local scene = arena_scene_manager.find_scene(aoi_scene_id)
        if scene == nil then
            flog("tmlDebug","imp_fight_avatar_main_dungeon.on_connect_qualifying_arena_server scene == nil")
            reply_data.result = const.error_scene_not_exist
            self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,reply_data)
            return
        end
        local pos = arena_scene_manager.get_qualifying_scene_born_pos(1)
        if pos == nil then
            flog("tmlDebug","imp_fight_avatar_main_dungeon.on_connect_qualifying_arena_server born_pos == nil")
            reply_data.result = const.error_can_not_find_scene_born_pos
            self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,reply_data)
            return
        end
        self.posX = pos[1]
        self.posY = pos[2]
        self.posZ = pos[3]
        self.rotation = pos[4]
        self.scene_id = scene:get_table_scene_id()
        reply_data.result = 0
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,reply_data)
        self:load_aoi_scene(aoi_scene_id,scene:get_table_scene_id(),scene:get_scene_id(),scene:get_scene_type(),scene:get_scene_resource_id())
    else
        reply_data.result = const.error_data
        self:send_message(const.SC_MESSAGE_LUA_ARENA_CHALLENGE,reply_data)
    end

    return
end

function imp_fight_avatar_arena.qualifying_arena_start(self)
    flog("tmlDebug","imp_fight_avatar_arena.qualifying_arena_start")
    local fight_start_time = get_now_time_second() + math.floor(challenge_arena_config.get_qualifying_arena_fight_ready_time())
    self.scene:get_entity_manager().SetEntityAttackStatus(self.entity_id,false)
    self:set_pet_attack_state(false)
    self.scene:set_start_fight_time(fight_start_time)
    self:send_message(const.SC_MESSAGE_LUA_ARENA_QUALIFYING_FIGHT,{result=0,fight_start_time=fight_start_time})
end

--顶号
function imp_fight_avatar_arena.qualifying_arena_replace(self)
    local fight_start_time = self.scene:get_start_fight_time()
    if get_now_time_second() < fight_start_time then
        self.scene:get_entity_manager().SetEntityAttackStatus(self.entity_id,false)
        self:set_pet_attack_state(false)
    end
    self:send_message(const.SC_MESSAGE_LUA_ARENA_QUALIFYING_FIGHT,{result=0,fight_start_time=fight_start_time})
end

local function leave_qualifying_arena(self)
    self:send_message(const.SC_MESSAGE_LUA_ARENA_QUALIFYING_GIFHT_OVER,{result=0})
    self:disconnet_fight_server()
    self:fight_send_to_game({func_name="on_fight_avatar_leave_qualifying_arena"})
end

--game端结束战斗
function imp_fight_avatar_arena.on_fight_avatar_leave_qualifying_arena(self)
    flog("tmlDebug","imp_fight_avatar_arena.on_fight_avatar_leave_qualifying_arena")
    leave_qualifying_arena(self)
end

--开始竞技场排位赛
function imp_fight_avatar_arena.start_qualifying_arena(self)
    flog("tmlDebug","imp_fight_avatar_arena.start_qualifying_arena")
    self:on_connect_qualifying_arena_server({fight_id=self.fight_id,actor_id=self.actor_id})
    self:fight_send_to_game({func_name="on_enter_qualifying_arena_success"})
end

function imp_fight_avatar_arena.set_qualifying_arena_done(self)
    qualifying_arena_fight_center:set_qualifying_arena_done(self.fight_id)
end

function imp_fight_avatar_arena.on_connect_dogfight_arena_server(self)
    flog("tmlDebug","imp_fight_avatar_arena.on_connect_dogfight_arena_server")
    local reply_data = {}
    reply_data.result = 0
    local check = dogfight_arena_fight_center:check_player(self.actor_id,self.fight_id)
    if check == true then
        local aoi_scene_id = dogfight_arena_fight_center:get_aoi_scene_id(self.fight_id)
        if aoi_scene_id == nil then
            flog("tmlDebug","imp_fight_avatar_arena.on_connect_dogfight_arena_server aoi_scene_id == nil")
            reply_data.result = const.error_scene_not_exist
            self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_CREATE_SCENE,reply_data)
            return
        end
        local scene = arena_scene_manager.find_scene(aoi_scene_id)
        if scene == nil then
            flog("tmlDebug","imp_fight_avatar_main_dungeon.on_connect_dogfight_arena_server scene == nil")
            reply_data.result = const.error_scene_not_exist
            self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_CREATE_SCENE,reply_data)
            return
        end
        local pos = dogfight_arena_fight_center:get_born_pos(self.fight_id)
        if pos == nil then
            flog("tmlDebug","imp_fight_avatar_main_dungeon.on_connect_dogfight_arena_server born_pos == nil")
            reply_data.result = const.error_can_not_find_scene_born_pos
            self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_CREATE_SCENE,reply_data)
            return
        end
        self.posX = pos[1]
        self.posY = pos[2]
        self.posZ = pos[3]
        self.rotation = pos[4]
        reply_data.countdown = dogfight_arena_fight_center:get_countdown(self.fight_id)
        self.scene_id = scene:get_table_scene_id()
        reply_data.result = 0
        self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_CREATE_SCENE,reply_data)
        self:load_aoi_scene(aoi_scene_id,scene:get_table_scene_id(),scene:get_scene_id(),scene:get_scene_type(),scene:get_scene_resource_id())
    else
        reply_data.result = const.error_data
        self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_CREATE_SCENE,reply_data)
    end
    return
end

--开始进入混战赛
function imp_fight_avatar_arena.start_dogfight_arena(self)
    flog("tmlDebug","imp_fight_avatar_arena.start_dogfight_arena")
    self:on_connect_dogfight_arena_server({fight_id=self.fight_id,actor_id=self.actor_id})
    self:fight_send_to_game({func_name="on_enter_dogfight_arena_success",room_id=dogfight_arena_fight_center:get_room_id()})
end

local function player_enter_dogfight_scene(self)
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{func_name="DogfightArenaStartRet",start_fight_time = dogfight_arena_fight_center:get_start_fight_time(self.fight_id),result=0})
    if get_now_time_second() < dogfight_arena_fight_center:get_start_fight_time(self.fight_id) then
        self.scene:get_entity_manager().SetEntityAttackStatus(self.entity_id,false)
        self:set_pet_attack_state(false)
    else
        self.scene:player_enter_scene_after_start(self)
    end
end

--进入混战赛场景
function imp_fight_avatar_arena.dogfight_arena_start(self)
    flog("tmlDebug","imp_fight_avatar_arena.dogfight_arena_start")
    player_enter_dogfight_scene(self)
    dogfight_arena_fight_center:player_enter_scene(self.fight_id,self.actor_id,self.arena_total_score,self.arena_address)
end

function imp_fight_avatar_arena.dogfight_arena_replace(self)
    player_enter_dogfight_scene(self)
end

local function leave_dogfight_arena(self)
    self:send_message(const.SC_MESSAGE_LUA_ARENA_DOGFIGHT_FIGHT_OVER,{result=0})
    self:disconnet_fight_server()
    self:fight_send_to_game({func_name="on_fight_avatar_leave_dogfight_arena"})
    self:leave_dogfight_arena(self.fight_id,self.actor_id)
end

--离开混战赛
function imp_fight_avatar_arena.on_fight_avatar_leave_dogfight_arena(self)
    flog("tmlDebug","imp_fight_avatar_arena.on_fight_avatar_leave_dogfight_arena")
    leave_dogfight_arena(self)
end

function imp_fight_avatar_arena.leave_dogfight_arena(self)
    flog("tmlDebug","imp_fight_avatar_arena.leave_dogfight_arena")
    dogfight_arena_fight_center:leave_dogfight_arena(self.fight_id,self.actor_id)
end

function imp_fight_avatar_arena.on_get_arena_dogfight_fight_score(self,input)
    flog("tmlDebug","imp_fight_avatar_arena.on_get_arena_dogfight_fight_score")
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{func_name="GetArenaDogfightFightScore",result=0,score_data=table.copy(dogfight_arena_fight_center:get_score_data(self.fight_id))})
end

function imp_fight_avatar_arena.on_notice_fight_server_quit_qualifying_arena(self,input)
    self:set_qualifying_arena_done()
end

function imp_fight_avatar_arena.check_qualifying_arena_over(self)
    return qualifying_arena_fight_center:check_fight_over(self.fight_id)
end

function imp_fight_avatar_arena.check_dogfight_arena_over(self)
    return dogfight_arena_fight_center:check_fight_over(self.fight_id)
end

return imp_fight_avatar_arena



