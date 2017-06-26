--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/3 0003
-- Time: 17:40
-- To change this template use File | Settings | File Templates.
--
local const = require "Common/constant"
local flog = require "basic/log"
local SyncManager = require "Common/SyncManager"
local Totalparameter = require("data/common_scene").Totalparameter
local entity_common = require "entities/entity_common"
local get_now_time_second = _get_now_time_second
local system_task_config = require "configs/system_task_config"
local math = require "math"
local online_user = require "fight_server/fight_server_online_user"
local dogfight_arena_fight_center = nil
local timer = require "basic/timer"
local common_fight_base_config = require "configs/common_fight_base_config"
local create_system_message_by_id = require("basic/scheme").create_system_message_by_id
local fight_avatar_connect_state = require "fight_server/fight_avatar_connect_state"
local table =table

local PROPERTY_NAME_TO_INDEX = const.PROPERTY_NAME_TO_INDEX
local REBIRTH_TYPE = const.REBIRTH_TYPE

local scene_type_configs = {}
for _,v in pairs(Totalparameter) do
    scene_type_configs[v.SceneType] = v
end

local imp_fight_avatar = {}
imp_fight_avatar.__index = imp_fight_avatar

setmetatable(imp_fight_avatar, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {

}
imp_fight_avatar.__params = params

function imp_fight_avatar.__ctor(self)
    self.actor_id = 0
    self.actor_name = ""
    self.level = 1
    self.vocation = 1
    self.country = 1
    self.sex = 1
    self.scene_id = 0
    self.posX = 0
    self.posY = 0
    self.posZ = 0
    self.current_hp = 100
    self.dungeon_rebirth_time = 1
    self.rebirth_type = "B"
    self.model_scale = 100
    self.rebirth_timer = nil
end

function imp_fight_avatar.get_actor_id(self)
    return self.actor_id
end

function imp_fight_avatar.get_sex(self)
    return self.sex
end

function imp_fight_avatar.get_actor_name(self)
    return self.actor_name
end

function imp_fight_avatar.get_level(self)
    return self.level
end

function imp_fight_avatar.get_vocation(self)
    return self.vocation
end

function imp_fight_avatar.get_country(self)
    return self.country
end

function imp_fight_avatar.get_move_speed(self)
    return 450
end

function imp_fight_avatar.get_model_scale(self)
    return self.model_scale
end

function imp_fight_avatar.get_is_disguise(self)
    return self.is_disguise
end

function imp_fight_avatar.get_disguise_model_id(self)
    return self.disguise_model_id
end

function imp_fight_avatar.get_is_stealthy(self)
    return self.is_stealthy
end

local function destroy_rebirth_timer(self)
    if self.rebirth_timer ~= nil then
        timer.destroy_timer(self.rebirth_timer)
        self.rebirth_timer = nil
    end
end

function imp_fight_avatar.imp_fight_avatar_init_from_dict(self,dict)
    self.actor_id = dict.actor_id
    self.actor_name = dict.actor_name
    self.level = dict.level
    self.vocation = dict.vocation
    self.country = dict.country
    self.sex = dict.sex
    self.model_scale = dict.model_scale
    self.is_disguise = dict.is_disguise
    self.disguise_model_id = dict.disguise_model_id
    self.is_stealthy = dict.is_stealthy
    self.current_hp = dict.property[PROPERTY_NAME_TO_INDEX.hp_max]
    --战斗服新开进程，可以和game服务器一样？
    self.entity_id = dict.actor_id
end


function imp_fight_avatar.on_connect_fight_server(self,input)

end

function imp_fight_avatar.initialize_fight_avater(self,input)
end

function imp_fight_avatar.on_attack_player(self, enemy)

end

function imp_fight_avatar.get_max_hp(self)
    return self.combat_info.property[PROPERTY_NAME_TO_INDEX.hp_max]
end

function imp_fight_avatar.get_current_hp(self)
    return self.current_hp
end

local function on_game_server_rpc(self,input)
    local func_name = input.func_name
    if func_name == nil or self[func_name] == nil then
        return
    end

    self[func_name](self, input)
end

local function on_client_server_rpc(self,input)
    local func_name = input.func_name
    if func_name == nil or self[func_name] == nil then
        return
    end

    self[func_name](self, input)
end

function imp_fight_avatar.on_update_fight_avatar_property(self,input)
    flog("tmlDebug","imp_fight_avatar.on_update_fight_avatar_property input:"..table.serialize(input))
    self:imp_property_init_from_dict(input.data)

    local hp_change_percent = input.hp_change_percent
    local mp_change_percent = input.mp_change_percent
    self:update_property_to_puppet(hp_change_percent, mp_change_percent)
end

function imp_fight_avatar.on_update_fight_avatar_skill_info(self,input)
    flog("tmlDebug","imp_fight_avatar.on_update_fight_avatar_skill_info input:"..table.serialize(input))
    self:imp_fight_avatar_skill_init_from_dict(input.data)
    local EntityManager = self:get_entity_manager()
    if not EntityManager then
        flog("info", ' find no entitymanager with entity_id = ' .. self:get_entity_id())
        return
    end
    local unit = EntityManager.GetPuppet(self:get_entity_id())
    if unit then
        self:imp_fight_avatar_skill_write_to_sync_dict(unit.data)
        unit:RefreshSkills()
    end
end

function imp_fight_avatar.on_player_die(self,killer_id)
    flog("tmlDebug","imp_player.on_player_die")
    local rebirth_type = "B"
    local scene = self:get_scene()
    if scene == nil then
        return
    end
    local scene_type_config = scene_type_configs[scene:get_scene_type()]
    if scene_type_config ~= nil then
        rebirth_type = scene_type_config.revive
    end

    if rebirth_type == "C" then
        if self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
            return
        end

        destroy_rebirth_timer(self)
        local time_need = 60
        local rebirth_config = common_fight_base_config.get_rebirth_config(rebirth_type,1)
        if rebirth_config == nil then
            flog("info","can not find revive config,rebirth_type:"..rebirth_type..",rebirth_times:1")
        else
            time_need = rebirth_config.Time4
        end
        local function rebirth_handle()
            self:on_fight_player_rebirth({rebirth_type = REBIRTH_TYPE.rebirth_place_passive})
            destroy_rebirth_timer(self)
        end
        self.rebirth_timer = timer.create_timer(rebirth_handle,time_need*1000,0,1)
        self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{func_name="ArenaDogfightRebirth",rebirth_time=get_now_time_second()+time_need})
    else
        self:fight_send_to_game({func_name="on_fight_avatar_die",rebirth_type = rebirth_type,dead_time = get_now_time_second()})
    end
end

function imp_fight_avatar.on_fight_player_rebirth(self,input)
    flog("tmlDebug","imp_fight_avatar.on_fight_player_rebirth rebirth_type:"..input.rebirth_type)
    local scene = self:get_scene()
    if scene == nil then
        return
    end

    local puppet = self:get_puppet()
    if puppet == nil then
        return
    end

    if input.rebirth_type == REBIRTH_TYPE.rebirth_place_active or input.rebirth_type == REBIRTH_TYPE.rebirth_place_passive then
        local scene = self:get_scene()
        if scene ~= nil then
            local rebirth_pos = scene:get_nearest_rebirth_pos({self.posX,self.posY,self.posZ}, self.country)
            if rebirth_pos ~= nil then
                if not self:is_in_arena_scene() then
                    self.posX = rebirth_pos[1]
                    self.posY = rebirth_pos[2]
                    self.posZ = rebirth_pos[3]
                end
            end
        end
    else
        local posX,posY,posZ = self:get_pos()
        if posX ~= nil and posY ~= nil and posZ ~= nil then
            self.posX = posX
            self.posY = posY
            self.posZ = posZ
        end
    end

    self:pet_leave_scene()
    self.change_scene_buffs = puppet.skillManager:GetSceneRemainBuffInfo()
    scene:remove_player(self.entity_id)
    self.combat_info.immortal_data.hp = nil
    self.combat_info.immortal_data.mp = nil
    scene:add_player(self)
    self:pet_enter_scene()
    return
end

function imp_fight_avatar.on_attack_entity(self, enemy_id, damage)
    local parent_on_attack_entity = entity_common.get_parent_func(self, "on_attack_entity")
    parent_on_attack_entity(self, enemy_id, damage)
    if self.team_member_fight_data_statistics ~= nil then
        self:team_member_fight_data_statistics("damage", damage)
    end
end

local function player_die_in_arena(self,killer_id)
    if arena_scene_manager == nil then
        return
    end

    local arena_scene = arena_scene_manager.find_scene(self:get_aoi_scene_id())
    if arena_scene == nil then
        return
    end

    if self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
        self:set_qualifying_arena_done()
        self:fight_send_to_game({func_name="on_qualifying_arena_fight_result",success=false})
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
        local killer = arena_scene:get_entity(killer_id)
        if killer ~= nil then
            if killer.type == const.ENTITY_TYPE_PET then
                killer = arena_scene:get_entity(killer.owner_id)
            end
        end
        if killer == nil then
            flog("tmlDebug","entity_die:can not find killer!killer_id:"..killer_id)
            return
        end
        if dogfight_arena_fight_center == nil then
            dogfight_arena_fight_center = require "fight_server/dogfight_arena_fight_center"
        end
        dogfight_arena_fight_center:kill_entity(self.fight_id,killer.actor_id,const.ENTITY_TYPE_PLAYER,self.actor_id)
    end
end

function imp_fight_avatar.entity_die(self, killer_id)
    player_die_in_arena(self,killer_id)
    self:on_player_die(killer_id)
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="PlayerDieRet",result=0})
    self:team_member_fight_data_statistics("die", 1)
    --玩家死亡宠物离开场景
    self:pet_leave_scene()
end

function imp_fight_avatar.on_item_add_buff(self,input)
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
    skill_manager:AddBuff(input.buff_id)
    return 0
end

function imp_fight_avatar.on_change_model_scale(self,input)
    self.model_scale = input.model_scale
    local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:SetDisguiseModelScale(self.model_scale)
    end
end

function imp_fight_avatar.on_disguise_model(self,input)
    flog("tmlDebug","imp_fight_avatar.on_disguise_model")
    self.is_disguise = input.is_disguise
    self.disguise_model_id = input.disguise_model_id
    local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:SetDisguiseModelId(self.disguise_model_id)
    end
end

function imp_fight_avatar.on_player_stealthy(self,input)
    flog("tmlDebug","imp_fight_avatar.on_player_stealthy")
    self.is_stealthy = input.is_stealthy
    local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:SetStealthy(self.is_stealthy)
    end
end

function imp_fight_avatar.on_player_change_name(self,input)
    flog("tmlDebug","imp_fight_avatar.on_player_change_name")
    self.actor_name = input.new_name
    local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:SetName(self.actor_name)
    end
end

function imp_fight_avatar.on_play_item_effect(self,input)
    local scene = self:get_scene()
    if scene ~= nil then
        self:broadcast_to_aoi(const.SC_MESSAGE_LUA_GAME_RPC,{func_name="UseBagItemReply",result=0,play_effect=true,effect_path=input.effect_path,duration=input.duration,posX=input.posX,posY=input.posY,posZ=input.posZ})
    end
end

function imp_fight_avatar.on_check_receive_task_distance(self,input)
    local task_config = system_task_config.get_task_config(input.task_id)
    local check_distance = self:check_distance_with_scene_unit(task_config.ReceiveTaskNPCParameter1[1],task_config.ReceiveTaskNPCParameter1[2],task_config.ReceiveTaskNPCParameter2[1])
    self:fight_send_to_game({func_name="on_check_receive_task_distance_reply",task_id=input.task_id,check_distance=check_distance})
end

function imp_fight_avatar.on_check_submit_task_distance(self,input)
    local task_config = system_task_config.get_task_config(input.task_id)
    local check_distance = false
    check_distance = self:check_distance_with_scene_unit(task_config.CompleteTaskNPCParameter1[1],task_config.CompleteTaskNPCParameter1[2],task_config.CompleteTaskNPCParameter2[1])
    self:fight_send_to_game({func_name="on_check_submit_task_distance_reply",task_id=input.task_id,check_distance=check_distance})
end

function imp_fight_avatar.on_check_task_use_item_distance(self,input)
    local task_config = system_task_config.get_task_config(input.task_id)
    local check_distance = self:check_distance_with_scene_position(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2],task_config.CompleteTaskParameter2)
    self:fight_send_to_game({func_name="on_check_task_use_item_distance_reply",task_id=input.task_id,check_distance=check_distance})
end

function imp_fight_avatar.on_check_task_use_item_distance(self,input)
    local task_config = system_task_config.get_task_config(input.task_id)
    local check_distance = self:check_distance_with_scene_unit(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2],math.floor(tonumber(task_config.CompleteTaskParameter2)))
    self:fight_send_to_game({func_name="on_check_task_trigger_mechanism_distance_reply",task_id=input.task_id,check_distance=check_distance})
end

function imp_fight_avatar.get_exp_from_monster(self, monster_level, monster_type, monster_id)
    local puppet = self:get_puppet()
    local exp_percent = 100
    if puppet ~= nil then
        exp_percent = SkillAPI.ChangeBattleExp(puppet, 100)
    else
        flog("error", "imp_fight_avatar.get_exp_from_monster find puppet fail!")
    end
    exp_percent = math.floor(exp_percent)
    self:fight_send_to_game({func_name="on_remote_get_exp_from_monster",monster_level=monster_level, monster_type = monster_type, exp_percent = exp_percent, monster_id = monster_id})
end

function imp_fight_avatar.on_check_task_gather_distance(self,input)
    local task_config = system_task_config.get_task_config(input.task_id)
    local check_distance = self:check_distance_with_scene_unit(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2],task_config.CompleteTaskParameter2)
    self:fight_send_to_game({func_name="on_check_task_gather_distance_reply",task_id=input.task_id,check_distance=check_distance})
end

function imp_fight_avatar.on_check_task_on_task_talk_distance(self,input)
    local task_config = system_task_config.get_task_config(input.task_id)
    local check_distance = self:check_distance_with_scene_unit(task_config.CompleteTaskParameter1[1],task_config.CompleteTaskParameter1[2],math.floor(tonumber(task_config.CompleteTaskParameter2)))
    self:fight_send_to_game({func_name="on_check_task_talk_distance_reply",task_id=input.task_id,check_distance=check_distance})
end


function imp_fight_avatar.get_drop_manager(self)
    return self.drop_manager
end

function imp_fight_avatar.on_get_monster_drop(self, input)
    self:fight_send_to_game(input)
    local drop_data = input.drop_data
    self:broadcast_to_aoi_include_self(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "PickDropRet", result = 0, drop_entity_id = drop_data.id, actor_id = self.actor_id, position = drop_data.position})
end

function imp_fight_avatar.enable_get_reward(self, dungeon_id)
    return self.is_reward_enable
end

function imp_fight_avatar.get_online_user(self, actor_id)
    return online_user.get_user(actor_id)
end

function imp_fight_avatar.on_fight_avatar_use_recovery_drug(self,input)
    if input.type == nil or input.recovery_value == nil or input.pos == nil then
        return
    end

    local result = self:use_recovery_drug(input.type,input.recovery_value)
    self:fight_send_to_game({func_name="on_fight_avatar_use_recovery_drug_reply",result=result,pos=input.pos,type=input.type})
end

function imp_fight_avatar.on_fight_avatar_change_appearance(self,input)
    flog("tmlDebug","imp_fight_avatar.on_fight_avatar_change_appearance")
    if input.part_id == nil or input.appearance == nil then
        return
    end
    self.combat_info.appearance = table.copy(input.appearance)
    self:change_appearance(input.part_id,self.combat_info.appearance)
end

function imp_fight_avatar.send_system_message(self,message_id,attach,...)
    local message_data, message = create_system_message_by_id(message_id, attach, ...)
    self:send_message(const.SC_MESSAGE_LUA_SYSTEM_MESSAGE,message_data)
end

function imp_fight_avatar.is_attackable(self, enemy_id)
    local scene = self:get_scene()
    if scene == nil then
        return
    end
    local enemy = scene:get_entity(enemy_id)
    if enemy.on_get_owner ~= nil then
        enemy = enemy:on_get_owner()
    end

    if enemy.type == const.ENTITY_TYPE_FIGHT_AVATAR and self.type == const.ENTITY_TYPE_FIGHT_AVATAR then
        if self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
            return true
        end
        return false
    else
        return true
    end
end

function imp_fight_avatar.on_fight_server_nearby_chat(self,input)
    self:broadcast_nearby(input.send_to_client_data)
end

function imp_fight_avatar.on_fight_avatar_prepare_capture(self, input)
    self:on_prepare_capture_wild_pet(input)
end

function imp_fight_avatar.on_fight_avatar_start_capture(self, input)
    self:on_start_capture_wild_pet(input)
end

function imp_fight_avatar.on_fight_avatar_capture(self, input)
    self:on_capture_wild_pet(input)
end

function imp_fight_avatar.on_fight_avatar_cancel_capture(self, input)
    self:on_cancel_capture_wild_pet(input)
end

function imp_fight_avatar.capture_pet_success(self, input)
    input.func_name = "capture_pet_success"
    self:fight_send_to_game(input)
end

--通知客户端可以设置断开战斗服标记
function imp_fight_avatar.disconnet_fight_server(self)
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="DisconnetFightServer"})
    if self.connect_state == fight_avatar_connect_state.offline then
        self:fight_send_to_game({func_name="on_fight_avatar_leave_scene"})
        self.connect_state = fight_avatar_connect_state.done
    else
        self.connect_state = fight_avatar_connect_state.over
    end
end

function imp_fight_avatar.reconnect(self,enter)
    if self:get_scene() == nil then
        return
    end

    if self:get_puppet() ~= nil then
        self.posX,self.posY,self.posZ = self:get_pos()
    end
    self:leave_aoi_scene()
    self.combat_info.immortal_data = table.copy(self.immortal_data)
    if enter then
        self:enter_aoi_scene()
    end
end

function imp_fight_avatar.on_player_replace(self,input)
    self.replace = true
end

function imp_fight_avatar.check_can_leave(self)
    if self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
        return self:check_dogfight_arena_over()
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA then
        return self:check_qualifying_arena_over()
    end
    return false
end

function imp_fight_avatar.set_immortal_data(self, immortal_data)
    self.immortal_data = immortal_data
end

register_fight_avatar_message_handler(const.CD_MESSAGE_LUA_GAME_RPC, SyncManager.on_server_rpc)
register_fight_avatar_message_handler(const.GD_MESSAGE_LUA_GAME_RPC, on_game_server_rpc)
register_fight_avatar_message_handler(const.CD_MESSAGE_LUA_GAME_RPC, on_client_server_rpc)

return imp_fight_avatar