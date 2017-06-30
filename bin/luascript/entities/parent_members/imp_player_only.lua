--------------------------------------------------------------------
-- 文件名:	imp_player_only
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/3 0003
-- 描  述:	接口组件，存放一般接口
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local string_split = require("basic/scheme").string_split
local tonumber = tonumber
local center_server_manager = require "center_server_manager"
local dogfight_arena_fight_center
local ipairs = ipairs
local _get_now_time_second = _get_now_time_second
local common_parameter_formula_config = require "configs/common_parameter_formula_config"
local SkillAPI = SkillAPI
local get_random_n = require("basic/scheme").get_random_n
local db_hiredis = require "basic/db_hiredis"
local send_to_game = require("basic/net").forward_message_to_game
local send_to_client = require("basic/net").send_to_client
local timer = require "basic/timer"
local system_friends_chat_config = require "configs/system_friends_chat_config"
local DISAPPEAR_TIME = require("data/common_parameter_formula").Parameter[31].Parameter   --物品消失时间
local string = string
local line = require "global_line/line"
local system_faction_config = require "configs/system_faction_config"
local common_scene_config = require "configs/common_scene_config"

local TELEPORTATION_RADIUS_SQUARE = 16          --传送阵半径平方
local FLY_SKILL_CD = 5
local FLY_BUFF_ID = '997'

local imp_player_only = {}
imp_player_only.__index = imp_player_only

setmetatable(imp_player_only, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_player_only.__params = params

function imp_player_only.__ctor(self)

end

function imp_player_only.get_dungeon_playing_id(self)
    return self.dungeon_in_playing
end

function imp_player_only.get_dungeon_type(self, dungeon_id)
    dungeon_id = dungeon_id or const.DUNGEON_NOT_EXIST
    if dungeon_id == const.DUNGEON_NOT_EXIST or dungeon_id == "free" then
        return "no_dungeon"
    end
    local dungeon_type
    for i, v in pairs(const.DUNGEON_START_INDEX) do
        if dungeon_id > v[1] then
            dungeon_type = v[2]
        end
    end
    if dungeon_type == nil then
        flog("error", "imp_dungeon.get_dungeon_type failed to get dungeon_type "..dungeon_id)
    end

    return dungeon_type
end

function imp_player_only.on_kill_monster(self, monster_data)
    flog("info", "imp_player_only.on_kill_monster")
    local monster_scene_id = monster_data.monster_scene_id
    local monster_pos = monster_data.monster_pos
    local monster_level = monster_data.monster_level
    local anger_value = monster_data.anger_value
    local monster_type = monster_data.monster_type
    local monster_id = monster_data.monster_id

    if self.scene == nil then
        return
    end

    if self.team_member_fight_data_statistics ~= nil then
        self:team_member_fight_data_statistics("kill_monster", 1)
    end

    if self.get_drop_manager ~= nil then
        local drop_manager = self:get_drop_manager()

        if drop_manager ~= nil then
            local dungeon_id = self:get_dungeon_playing_id()
            if dungeon_id == const.DUNGEON_NOT_EXIST then
                dungeon_id = self:get_aoi_scene_id()
            end

            local owner_id = self.actor_id
            local is_team_own = false
            if self.team_id ~= nil and self.team_id ~= 0 then
                owner_id = self.team_id
                is_team_own = true
            end

            if monster_type == const.MONSTER_TYPE.WILD_ELITE_BOSS then
                anger_value = self:get_boss_anger_value(anger_value)
            end
            local drop_set = drop_manager:create_drop_on_monster_die(monster_scene_id, dungeon_id, owner_id, is_team_own, monster_level, anger_value)

            if not table.isEmptyOrNil(drop_set) then
                self:on_drop_item(drop_set, monster_pos)
            end

            if self.get_exp_from_monster ~= nil then
                self:get_exp_from_monster(monster_level, monster_type, monster_id)
            end
        end
    end

    if self.scene:get_scene_type() == const.SCENE_TYPE.ARENA then
        if self.scene:is_dogfight() then
            if self.type == const.ENTITY_TYPE_FIGHT_AVATAR then
                if dogfight_arena_fight_center == nil then
                    dogfight_arena_fight_center = require "fight_server/dogfight_arena_fight_center"
                end
                dogfight_arena_fight_center:kill_entity(self.fight_id,self.actor_id,const.ENTITY_TYPE_MONSTER)
            end
        else
            if self.type == const.ENTITY_TYPE_FIGHT_AVATAR then
                self:set_qualifying_arena_done()
                self:fight_send_to_game({func_name="on_qualifying_arena_fight_result",success=true})
            end
        end
    end

    --刷新任务
    if self.scene:get_scene_type() == const.SCENE_TYPE.WILD or self.scene:get_scene_type() == const.SCENE_TYPE.CITY then
        self:update_task_kill_monster(self.scene:get_scene_type(),self.scene:get_table_scene_id(),monster_scene_id)
    elseif self.scene:get_scene_type() == const.SCENE_TYPE.DUNGEON or self.scene:get_scene_type() == const.SCENE_TYPE.TEAM_DUNGEON then
        self:fight_send_to_game({func_name="on_fight_server_kill_task_monster",scene_type=self.scene:get_scene_type(),scene_id=self.scene:get_table_scene_id(),unit=monster_scene_id})
    end
end

function imp_player_only.get_puppet(self)
    local entity_manager = self:get_entity_manager()
    if entity_manager == nil then
        flog("warn", "imp_player_only.get_puppet: entity_manager is nil")
        return
    end
    return entity_manager.GetPuppet(self.actor_id)
end

function imp_player_only.check_distance_with_scene_unit(self,scene_type,scene_id,unit_id)
    local scene = self:get_scene()
    if scene == nil then
        return false
    end
    if scene_type ~= scene:get_scene_type() then
        return false
    end
    if scene_id ~= scene:get_table_scene_id() then
        return false
    end

    local scene_setting = scene:get_scene_setting()
    if scene_setting == nil or scene_setting[unit_id] == nil then
        flog("warn","can not find scene_setting!!!scene_type "..scene_type.." scene id "..scene_id.." unit_id "..unit_id)
        return false
    end

    local cx,cy,cz = self:get_pos()
    if (cx - scene_setting[unit_id].PosX)*(cx - scene_setting[unit_id].PosX) + (cy - scene_setting[unit_id].PosY)*(cy - scene_setting[unit_id].PosY) + (cz - scene_setting[unit_id].PosZ)*(cz - scene_setting[unit_id].PosZ) > const.TASK_NPC_DISTANCE*const.TASK_NPC_DISTANCE then
        return false
    end

    return true
end

function imp_player_only.check_distance_with_scene_position(self,scene_type,scene_id,pos_string)
    local scene = self:get_scene()
    if scene == nil then
        return false
    end
    if scene_type ~= scene:get_scene_type() then
        return false
    end
    if scene_id ~= scene:get_table_scene_id() then
        return false
    end

    local cx,cy,cz = self:get_pos()
    local pos = string_split(pos_string,"|")
    if #pos ~= 3 then
        flog("info","task config error!!!")
        return false
    end
    if (cx - tonumber(pos[1]))*(cx - tonumber(pos[1])) + (cy - tonumber(pos[2]))*(cy - tonumber(pos[2])) + (cz - tonumber(pos[3]))*(cz - tonumber(pos[3])) > const.TASK_NPC_DISTANCE*const.TASK_NPC_DISTANCE then
        return false
    end

    return true
end

-- 构造掉落物品的坐标
local drop_scheme = require("data/common_parameter_formula").Drop
local min_drop_distance = require("data/common_parameter_formula").Parameter[24].Parameter / 100     --掉落物品之间最小间距
local table_insert = table.insert
local fast_sin_angle = require("basic/fast_math").sin_angle
local math_random = math.random
local fast_cos_angle = require("basic/fast_math").cos_angle
local math_sqrt = math.sqrt
local table_remove = table.remove

local function is_distance_ok(pos, poses)
    for _, v in ipairs(poses) do
        local diff_x = v.x - pos.x
        local diff_z = v.z - pos.z
        local dis = math_sqrt(diff_x * diff_x + diff_z * diff_z)
        if dis < min_drop_distance then
            return false
        end
    end
    return true
end

local function get_nearest_pos(diff_pos, center_pos, aoi_scene_id)
    local pos_x = diff_pos.x + center_pos.x
    local pos_y = center_pos.y
    local pos_z = diff_pos.z + center_pos.z
    local rst, x, y, z = _get_nearest_poly_of_point(aoi_scene_id, pos_x, pos_y, pos_z)
    if rst == true then
        return {x = x, y = y, z = z}
    end
    aoi_scene_id = aoi_scene_id or "nil"
    flog("error", "get_nearest_pos find pos error ! aoi_scene_id "..aoi_scene_id)
    return {x = center_pos.x, y = center_pos.y, z = center_pos.z}
end

local function random_vec2(radius)
    local random_angle = math_random(360)
    local random_randius = math_random() * radius
    local z = fast_sin_angle(random_angle) * random_randius
    local x = fast_cos_angle(random_angle) * random_randius
    return {x = x, z = z}
end

-- 生成一个点
local function generate_one_pos(radius, poses, max_radius, center_pos, aoi_scene_id)
    for i = 1, 10 do
        local pos = random_vec2(radius)
        local dis_ok = is_distance_ok(pos, poses)

        if dis_ok then
            return get_nearest_pos(pos, center_pos, aoi_scene_id)
        end
    end
    return center_pos
end

local function get_offset_positions(count, center_pos, aoi_scene_id)
    local poses = {}
    local radius = 0
    local max_radius = radius
    for k, v in ipairs(drop_scheme)do
        if count >= v.DropLimit and radius < v.DropRadius then
            radius = v.DropRadius
            if drop_scheme[k + 1] then
                max_radius = drop_scheme[k + 1].DropRadius
            else
                max_radius = radius
            end
        end
    end

    for i = 1, count do
        table_insert(poses, generate_one_pos(radius, poses, max_radius, center_pos, aoi_scene_id))
    end
    return poses
end


function imp_player_only.on_drop_item(self, drop_set, monster_pos)
    local output= {func_name = "MonsterDropItem" }

    local puppet_drop_data = {}
    local num = table.getnum(drop_set)
    if num <= 0 then
        return
    end
    local offset_poses = get_offset_positions(num, monster_pos, self:get_aoi_scene_id())
    flog("syzDebug", "get_offset_positions "..table.serialize(offset_poses))
    local index = 1
    local entity_manager = self:get_entity_manager()
    for entity_id, drop_data in pairs(drop_set) do
        puppet_drop_data.entity_id = entity_id
        local position = offset_poses[index]
        if position == nil then
            flog("error", "offset_poses[index] is nil!")
        end
        local pos_cli = {}
        pos_cli.x, pos_cli.y, pos_cli.z = self.pos_to_client(position.x, position.y, position.z)
        drop_data.position = pos_cli
        puppet_drop_data.posX = position.x
        puppet_drop_data.posY = position.y
        puppet_drop_data.posZ = position.z
        index = index + 1
        puppet_drop_data.owner_id = drop_data.owner_id
        puppet_drop_data.is_team = drop_data.is_team_own
        puppet_drop_data.item_id = drop_data.item_id
        puppet_drop_data.count = drop_data.count
        puppet_drop_data.create_time = drop_data.create_time
        puppet_drop_data.create_x = monster_pos.x
        puppet_drop_data.create_y = monster_pos.y
        puppet_drop_data.create_z = monster_pos.z

        entity_manager.CreateDrop(puppet_drop_data)
    end

    Timer.Delay(DISAPPEAR_TIME, function()
    for id, _ in pairs(drop_set) do
        entity_manager.DestroyPuppet(id)
        end
    end)


    --self:broadcast_to_aoi_include_self(const.SC_MESSAGE_LUA_GAME_RPC, output)
end

function imp_player_only.destroy_puppet(self, drop_entity_id)
    local entity_manager = self:get_entity_manager()
    entity_manager.DestroyPuppet(drop_entity_id)
end


function imp_player_only.on_pick_drop(self, input)
    if self.get_drop_manager == nil then
        return
    end
    if not self:enable_get_reward(self.dungeon_in_playing) then
        return
    end

    local drop_manager = self:get_drop_manager()
    local drop_entity_id = input.drop_entity_id
    local pick_mode = input.mode

    local result, is_destroy, mode, drop_data = drop_manager:on_pick_drop(drop_entity_id, self.actor_id, self.team_id, pick_mode)
    if result ~= 0 then
        return self:broadcast_to_aoi_include_self(const.SC_MESSAGE_LUA_GAME_RPC, {func_name = "PickDropRet", result = 0, drop_entity_id = drop_entity_id, actor_id = self.actor_id, position = drop_data.position})
    end

    if is_destroy then
        self:destroy_puppet(drop_entity_id)
    end
    if mode == "direct_get" then
        self:on_get_monster_drop({func_name = "on_get_monster_drop", drop_data = drop_data})
    elseif mode == "auto_roll" then
        local team_members = self:get_team_members()
        local enable_members = {}
        for id, v in pairs(team_members) do
            repeat
                local player = self:get_online_user(id)
                if player == nil then
                    break
                end
                if player:get_aoi_scene_id() ~= drop_data.scene_id then
                    break
                end
                if not player:enable_get_reward(self.dungeon_in_playing) then
                    break
                end
                enable_members[id] = v
            until(true)
        end

        if not table.isEmptyOrNil(enable_members) then
            local member_number = table.getnum(enable_members)
            local score_list = get_random_n(member_number, 100)
            local i = 1
            for id, _ in pairs(enable_members) do
                enable_members[id] = score_list[i]
                i = i + 1
            end

            local lucky_id = drop_manager:auto_roll_item(enable_members, drop_entity_id)
            if lucky_id ~= nil then
                local rpc_data = {func_name = "on_get_monster_drop", drop_data = drop_data, actor_id = lucky_id}
                self:send_message_to_player_game(lucky_id, rpc_data)
            end
        end
    elseif mode == "manual_roll" then
        local team_members = self:get_team_members()
        local drop_manager = self:get_drop_manager()
        for id, _ in pairs(team_members) do
            repeat
                local player = self:get_online_user(id)
                if player == nil then
                    break
                end
                if player:get_aoi_scene_id() ~= drop_data.scene_id then
                    break
                end
                if not player:enable_get_reward(self.dungeon_in_playing) then
                    break
                end

                player:send_message(const.DC_MESSAGE_LUA_GAME_RPC, {func_name = "ManualRollItem", drop_data = drop_data })
                drop_manager:add_manual_roll_waiting_member(drop_entity_id, id)
                if player.manual_roll_timer ~= nil then
                    Timer.Remove(player.manual_roll_timer)
                    player.manual_roll_timer = nil
                end
                player.manual_roll_timer = Timer.Delay(10, function()
                    flog("syzDebug", "player.manual_roll_timer time out")
                    player.manual_roll_timer = nil
                    player:on_reply_manual_roll({drop_entity_id = drop_entity_id, is_want = true})
                end)
            until(true)
        end
        drop_manager:gen_manual_roll_waiting_member_score(drop_entity_id)
    else
        mode = mode or "nil"
        flog("error", "imp_player_only.on_pick_drop mode is error: "..mode)
    end
end

function imp_player_only.send_to_all_team_member_game(self, output)
    local team_members = self:get_team_members()
    for id, _ in pairs(team_members) do
        self:send_message_to_player_game(id, output)
    end
end

function imp_player_only.on_reply_manual_roll(self, input)
    local drop_entity_id = input.drop_entity_id
    local is_want = input.is_want

    if self.manual_roll_timer ~= nil then
        Timer.Remove(self.manual_roll_timer)
        self.manual_roll_timer = nil
    end
    local drop_manager = self:get_drop_manager()
    local result, is_all_reply, drop_data = drop_manager:reply_manual_roll(drop_entity_id, self.actor_id, is_want, self.vocation)
    if result ~= 0 then
        return self:send_message(const.DC_MESSAGE_LUA_GAME_RPC, {func_name = "ReplyManualRollRet", result = result})
    end
    local roll_score = drop_data.waiting_members[self.actor_id].score
    self:send_message(const.DC_MESSAGE_LUA_GAME_RPC, {func_name = "ReplyManualRollRet", result = 0, roll_num = roll_score})

    local message_id
    local params
    if is_want then
        message_id = const.SYSTEM_MESSAGE_ID.player_want_item
        params= {self.actor_name, roll_score}
    else
        message_id = const.SYSTEM_MESSAGE_ID.player_giveup_item
        params= {self.actor_name}
    end
    local props = drop_data.item_id
    self:send_to_all_team_member_game({func_name = "on_send_system_message", message_id = message_id, params = params, props=props})
    if is_all_reply then
        local lucky_id = drop_manager:manual_roll_item(drop_entity_id)
        if lucky_id ~= nil then
            local rpc_data = {func_name = "on_get_monster_drop", drop_data = drop_data, actor_id = lucky_id }
            self:send_message_to_player_game(lucky_id, rpc_data)
        end
    end
end

function imp_player_only.is_operation_allowed(self, operation_name)
    local mutex_operation = const.MUTEX_OPERATE_LIST[operation_name] or const.MUTEX_OPERATE_LIST.default

    for _, func_name in pairs(mutex_operation) do
        if self[func_name] ~= nil and self[func_name](self) then
            return const["error_"..func_name] or const.error_not_allowed_operate
        end
    end

    return 0
end

function imp_player_only.get_pos(self)
    local entity_manager = self:get_entity_manager()
    if entity_manager == nil then
        --flog("error", "get_pos: entity_manager is nil")
        return self:get("posX"),self:get("posY"),self:get("posZ")
    end
    local puppet = entity_manager.GetPuppet(self.actor_id)
    if puppet == nil then
        flog("error", "get_pos: puppet is nil")
        return self:get("posX"),self:get("posY"),self:get("posZ")
    end
    local pos = puppet:GetPosition()
    return pos.x, pos.y, pos.z
end

local function _get_scene_detail(scene, target_scene_id)
    --帮会地图与普通地图在不同表格，如果还有其他表格，建议更改配置
    local scene_type = scene:get_scene_type()
    if scene_type == const.SCENE_TYPE.FACTION then
        return common_scene_config.get_scene_detail_config(target_scene_id)
    elseif (scene_type == const.SCENE_TYPE.WILD or scene_type == const.SCENE_TYPE.CITY) and target_scene_id == const.SCENE_TYPE.FACTION then
        return system_faction_config.get_scene_setting(target_scene_id)
    end
    local index_scheme, total_scheme = scene:get_total_scene_config()
    local scene_cfg = index_scheme[target_scene_id]
    return total_scheme[scene_cfg.SceneSetting]
end

--地图传送点
function imp_player_only.on_map_teleportation(self, input)
    flog("syzDebug", "imp_player_only.on_map_teleportation")
    if self.is_changing_scene then
        return
    end
    local result = self:is_operation_allowed("map_teleportation")
    if result ~= 0 then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = result, func_name = "MapTeleportationRet"})
    end

    local scene = self:get_scene()
    if scene == nil then
        flog("error", "self:get_scene fail!")
        return
    end

    local item_id = input.item_id
    local current_scene_id = scene:get_table_scene_id()

    local current_scene_cfg = scene:get_scene_setting()
    local item_cfg = current_scene_cfg[item_id]
    if item_cfg == nil or item_cfg.Type ~= const.ENTITY_TYPE_WAYOUT then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_not_teleportation_type, func_name = "MapTeleportationRet"})
    end
    --检查与传送阵距离
    local x,y,z = self:get_pos()
    local dx = x - item_cfg.PosX
    local dy = y - item_cfg.PosY
    local dz = z - item_cfg.PosZ

    local distence_square = dx * dx + dy * dy + dz * dz
    if distence_square > TELEPORTATION_RADIUS_SQUARE then
        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC, {result = const.error_to_far_from_teleportation, func_name = "MapTeleportationRet"})
    end

    --实施传送
    local target_scene_id = math.floor(tonumber(item_cfg.Para1))
    local target_item_id = math.floor(tonumber(item_cfg.Para2))
    if target_scene_id == current_scene_id then
        local target_item_cfg = current_scene_cfg[target_item_id]
        if target_item_cfg == nil then
            flog("error", "imp_player_only.on_map_teleportation not exisit scene "..target_scene_id.." item "..target_item_id)
            return
        end
        local client_pos = {0,0,0}
        client_pos[1], client_pos[2], client_pos[3] = self.pos_to_client(target_item_cfg.PosX, target_item_cfg.PosY, target_item_cfg.PosZ)

        return self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name = "MoveToAppointPos", result = 0, pos = client_pos})
    else
        local target_scene_cfg = _get_scene_detail(scene, target_scene_id)
        local target_item_cfg = target_scene_cfg[target_item_id]
        if target_item_cfg == nil then
            flog("error", "imp_player_only.on_map_teleportation not exisit scene "..target_scene_id.." item "..target_item_id)
            return
        end

        local result = self:can_enter_scene(target_scene_id)
        if result == 0 then
            self.posX = target_item_cfg.PosX
            self.posY = target_item_cfg.PosY
            self.posZ = target_item_cfg.PosZ
            self.scene_id = target_scene_id
            self:load_scene(result,target_scene_id)
        end
    end
end

function imp_player_only.use_recovery_drug(self,type,recovery_value)
    local current_time = _get_now_time_second()
    local scene = self:get_scene()
    if scene == nil then
        return const.error_actor_is_not_in_scene
    end
    local entity_manager = scene:get_entity_manager()
    if entity_manager == nil then
        return const.error_actor_is_not_in_scene
    end
    local puppet = nil
    if type == const.RECOVERY_DRUG_TYPE.actor_hp then
        puppet = entity_manager.GetPuppet(self.entity_id)
        if puppet == nil then
            return const.error_actor_is_not_in_scene
        end
        if puppet.hp <= 0 then
            return const.error_skill_target_dead
        end
        --如果血量已满
        if puppet.hp >= puppet.hp_max() then
            return const.error_current_hp_is_full
        end
        SkillAPI.AddHp(puppet,recovery_value)
        --puppet:SetHp(puppet.hp + recovery_value)
        return 0
    elseif type == const.RECOVERY_DRUG_TYPE.actor_mp then
        puppet = entity_manager.GetPuppet(self.entity_id)
        if puppet == nil then
            return const.error_actor_is_not_in_scene
        end
        if puppet.hp <= 0 then
            return const.error_skill_target_dead
        end
        if puppet.mp >= puppet.mp_max() then
            return const.error_current_mp_is_full
        end
        SkillAPI.AddMp(puppet,recovery_value)
        --puppet:SetMp(puppet.mp+recovery_value)
        return 0
    elseif type == const.RECOVERY_DRUG_TYPE.pet_hp then
        local min_percent = 1
        local pet = nil
        for _,v in pairs(self.pet_on_fight) do
            puppet = entity_manager.GetPuppet(v)
            if puppet ~= nil then
                --给血量最少的加血
                local current_percent = puppet.hp/puppet.hp_max()
                if pet == nil or current_percent < min_percent then
                    pet = puppet
                    min_percent = current_percent
                end
            end
        end
        if pet == nil then
            return const.error_pet_is_not_in_scene
        end
        if pet.hp <= 0 then
            return const.error_skill_target_dead
        end
        if pet.hp >= pet.hp_max() then
            return const.error_current_pet_hp_is_full
        end
        SkillAPI.AddHp(pet,recovery_value)
        --pet:AddHp(pet.hp+recovery_value)
        return 0
    end
    return 0
end

function imp_player_only.change_appearance(self,part_id,appearance)
    local puppet = self:get_puppet()
    if puppet ~= nil then
        local aoi_index = self.get_appearance_aoi_index(part_id)
        puppet:SetAppearance(aoi_index, appearance[part_id])
    end
end

local function _fly_state_change(self, is_flying)
    local puppet = self:get_puppet()
    if puppet == nil then
        return
    end

    local skill_manager = puppet.skillManager
    if skill_manager == nil then
        return
    end

    local try_func = function ()
        if is_flying then
            skill_manager:AddBuff(FLY_BUFF_ID)
        else
            local buff = skill_manager:FindBuff(FLY_BUFF_ID)
            if buff ~= nil then
                skill_manager:RemoveBuff(buff)
            end
        end
    end
    local err_handler = function ()
        flog("error", "_fly_state_change : buff operation fail")
    end
    xpcall(try_func, err_handler)
end


function imp_player_only.on_fly_start(self, input, syn_data)
    if self.update_task_system_operation ~= nil then
        self:update_task_system_operation(const.TASK_SYSTEM_OPERATION.qinggong)
    end
    input.func_name = "OnFlyStart"
    input.actor_id = self.actor_id
    self:broadcast_to_aoi_include_self(const.SC_MESSAGE_LUA_GAME_RPC, input)
    _fly_state_change(self, true)
end

function imp_player_only.on_fly_end(self, input, syn_data)
    input.func_name = "OnFlyEnd"
    input.actor_id = self.actor_id
    self:broadcast_to_aoi_include_self(const.SC_MESSAGE_LUA_GAME_RPC, input)
    _fly_state_change(self, false)
end

function imp_player_only.send_message_to_player_game(self, actor_id, data)
    local player = self:get_online_user(actor_id)
    if player ~= nil then
        player:send_to_self_game(data)
        return "local"
    end
    local role_state = db_hiredis.hget("role_state", actor_id)
    if role_state == nil then
        --flog("warn", "imp_player_only.send_message_to_player_game: player is offline "..actor_id)
        return "offline"
    end
    data.actor_id = actor_id
    send_to_game(role_state.game_id, const.OG_MESSAGE_LUA_GAME_RPC, data)
    return "remote"
end

function imp_player_only.on_get_player_position(self, input)
    local player_id = input.player_id
    local result = self:send_message_to_player_game(player_id, {func_name = "send_my_position", client_session_id = string.format("%16.0f",self.session_id)})
    if result == "offline" then
        self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name = "GetPlayerPositionRet", result = const.error_player_is_offline})
    end
end

function imp_player_only.send_my_position(self, input)
    flog("tmlDebug","imp_player_only.send_my_position")
    local client_session_id = tonumber(input.client_session_id)
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, {func_name = "send_my_position", client_session_id = client_session_id})
        return
    end

    local x,y,z = self:get_pos()
    local pos = {0,0,0}
    pos[1], pos[2], pos[3] = self.pos_to_client(x, y, z)
    local scene_id = self:get_aoi_scene_id()
    local game_id = self.game_id
    local output = {func_name = "GetPlayerPositionRet", game_id = game_id, scene_id = scene_id, pos = pos,game_line=line.get_line_by_game_id(game_id)}
    send_to_client(client_session_id, const.SC_MESSAGE_LUA_GAME_RPC, output)
end

local function _player_timer_handle(self)
    if self.pet_die_map ~= nil then
        local current_time = _get_now_time_second()
        for i=#self.pet_die_map,1,-1 do
            if self.pet_die_map[i].rebirth_time > 0 and self.pet_die_map[i].rebirth_time < current_time and self:rebirth_pet(self.pet_die_map[i].entity_id) then
                self:send_fight_pet_to_client()
                local puppet = self:get_puppet()
                if puppet ~= nil and not puppet:IsDied() then
                    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name = "PetRebirthRet", result = 0,uid=self.pet_die_map[i].entity_id})
                end
                table_remove(self.pet_die_map,i)
            end
        end

        if #self.pet_die_map == 0 then
            self:remove_player_timer()
        end
    end
end

function imp_player_only.add_player_timer(self)
    if self.player_timer == nil then
        local function player_timer_handle()
            _player_timer_handle(self)
        end
        self.player_timer = timer.create_timer(player_timer_handle,1000,const.INFINITY_CALL,const.INFINITY_CALL)
    end
end

function imp_player_only.remove_player_timer(self)
    if self.player_timer ~= nil then
        timer.destroy_timer(self.player_timer)
        self.player_timer = nil
    end
end

function imp_player_only.pet_die(self,entity_id,dead_time,rebirth_time)
    if self.pet_die_map == nil then
        self.pet_die_map = {}
    end
    table_insert(self.pet_die_map,{entity_id=entity_id,rebirth_time=rebirth_time})
    self:add_player_timer()
    self:send_fight_pet_to_client()
    self:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{func_name = "PetDieRet", result = 0,uid=entity_id,dead_time=dead_time,rebirth_time=rebirth_time})
end

function imp_player_only.broadcast_nearby(self,data)
    local scene = self:get_scene()
    if scene == nil then
        return
    end
    local all_user = scene:get_nearby_avatars(system_friends_chat_config.get_chat_nearby_distance(),self:get_pos())
    for _,v in pairs(all_user) do
        v:send_message(const.SC_MESSAGE_LUA_CHAT_BROADCAST,data)
    end
end

function imp_player_only.is_in_arena_scene(self)
    if self.in_fight_server ~= nil then
        if not self.in_fight_server then
            return false
        elseif self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA or self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
            return true
        end
    elseif self.fight_type == const.FIGHT_SERVER_TYPE.QUALIFYING_ARENA or self.fight_type == const.FIGHT_SERVER_TYPE.DOGFIGHT_ARENA then
        return true
    end
    return false
end

local pet_attrib = require("data/growing_pet").Attribute
local scheme_param = require("data/common_parameter_formula").Parameter
local param_e = scheme_param[14]  --抓捕概率修正参数

local formula_str = require("data/common_parameter_formula").Formula[2].Formula      --抓宠概率的策划表公式
local formula_str =  "return function (r, x) return "..formula_str.." end"
local formula_addtition_func = loadstring(formula_str)()

local function _change_wild_pet_state(self, pet_entity_id, enabled)
    local puppet
    puppet = self:get_puppet_by_id(pet_entity_id)
    if puppet ~= nil then
        puppet.enabled = enabled
        if not enabled then
            puppet:StopMove()
        end
    end
    return puppet
end

local function reset_data(self)
    _change_wild_pet_state(self, self.pet_uid_in_capture, true)

    self.pet_uid_in_capture = nil
    self.pet_id_capturing = nil
    self.start_time = nil
    self.capture_times = 0
    self.cap_timer = nil
    self.addition_rate_total = 0
    --flog("syzDebug", "CreateImpSeal : reset_data")
end

function imp_player_only.on_prepare_capture_wild_pet(self, input)
    local pet_id = input.pet_id
    local pet_uid_in_capture = input.pet_uid

    local puppet = _change_wild_pet_state(self, pet_uid_in_capture, false)
    if puppet == nil or puppet.data.WildPetId ~= pet_id then
        return self:send_message(const.SC_MESSAGE_LUA_PREPARE_CAPTURE_PET , {result = const.error_wild_pet_not_exsit})
    end

    if self.prepare_timer ~= nil then
        timer.destroy_timer(self.prepare_timer)
        self.prepare_timer = nil
    end
    local function timer_callback()
        reset_data(self)
    end
    self.prepare_timer = timer.create_timer(timer_callback, const.PET_CAPTURE_MAX_TIME * 1000, 0)

    self:send_message(const.SC_MESSAGE_LUA_PREPARE_CAPTURE_PET , {result = 0})
    self.pet_id_capturing = pet_id
    self.pet_uid_in_capture = pet_uid_in_capture
    self.pet_level_capturing = puppet.level
end

local function calc_rate(self, seal_ratio, radius, max_radius)
    local base_rate = pet_attrib[self.pet_id_capturing].SuccessRate + seal_ratio / 10
    local total_rate = base_rate - param_e.Parameter
    total_rate = math.floor(total_rate)
    total_rate = math.max(0, total_rate)
    --radius为空时，返回基础概率
    if radius == nil or radius < 0 then
        return total_rate, 0
    end

    local time_rate = math.min(param_e.Parameter, base_rate)
    local delta_time = _get_now_time_second() - self.start_time
    time_rate = time_rate * delta_time / const.PET_CAPTURE_MAX_TIME
    time_rate = math.floor(time_rate)

    total_rate = total_rate + time_rate + math.max(self.addition_rate_total, 0)

    --计算附加比率
    --[[local addition_rate = (0.5 * max_radius - radius) / 0.3 / max_radius
    addition_rate = addition_rate * addition_rate * addition_rate
    addition_rate = math.max(math.min(addition_rate, 1), -1)
    addition_rate = math.floor(addition_rate * 100)]]
    local addition_rate = math.floor(formula_addtition_func(max_radius, radius) * 100)

    return total_rate, addition_rate
end

function imp_player_only.on_start_capture_wild_pet(self, input, syn_data)
    local pet_id = self.pet_id_capturing
    local current_time = _get_now_time_second()

    --如果有之前的计时器未销毁，则销毁该计时器
    if self.prepare_timer ~= nil then
        timer.destroy_timer(self.prepare_timer)
        self.prepare_timer = nil
    end

    if self.cap_timer ~= nil then
        flog("error", "on_start_capture : timer still not destroy! --"..self.cap_timer)
        timer.destroy_timer(self.cap_timer)
        reset_data(self)
    end

    local puppet = self:get_puppet_by_id(self.pet_uid_in_capture)
    if puppet == nil then
        return self:send_message(const.SC_MESSAGE_LUA_PREPARE_CAPTURE_PET , {result = const.error_wild_pet_not_exsit})
    end

    self.start_time = current_time
    self.last_capture_time = current_time
    self.capture_times = const.PET_CAPTURE_MAX_NUM
    self.addition_rate_total = 0

    local rate = calc_rate(self, input.seal_ratio)

    local function timer_callback()
        reset_data(self)
        self:send_message(const.SC_MESSAGE_LUA_CAPTURE_RET , {result = 0, capture_result = const.CAPTURE_RESULT_FAIL_TIME_OUT})
    end
    self.cap_timer = timer.create_timer(timer_callback, const.PET_CAPTURE_MAX_TIME * 1000, 0)

    self:send_message(const.SC_MESSAGE_LUA_START_CAPTURE_PET , {result = 0, rate = rate, info = {seal_ratio = input.seal_ratio, last_capture_time = self.last_capture_time}})
    return 0
end

function imp_player_only.on_capture_wild_pet(self, input, syn_data)
    self.capture_times = self.capture_times - 1
    local result = 0
    if self.capture_times < 0 then
        result = const.error_capture_num_out
    end
    if self.cap_timer == nil then
        result = const.error_capture_time_out
    end

    if result ~= 0 then
        self:send_message(const.SC_MESSAGE_LUA_CAPTURE_RET , {result = result})
        return result
    end

    local puppet = self:get_puppet_by_id(self.pet_uid_in_capture)
    if puppet == nil then
        if self.cap_timer ~= nil then
            timer.destroy_timer(self.cap_timer)
            self.cap_timer = nil
        end
        reset_data(self)
        return self:send_message(const.SC_MESSAGE_LUA_PREPARE_CAPTURE_PET , {result = const.error_wild_pet_not_exsit})
    end

    flog("info", "radius "..input.radius)
    flog("info", "max_radius"..input.max_radius)
    local rate, rate_addition = calc_rate(self, input.seal_ratio, input.radius, input.max_radius)
    flog("info", "rate "..rate)
    flog("info", "rate_addition  "..rate_addition)
    self.addition_rate_total = self.addition_rate_total + rate_addition
    local rand_num = math.random(100)
    flog("info", "rand_num  "..rand_num)
    if rand_num <= rate then            --捕获宠物成功
        self:destroy_puppet(self.pet_uid_in_capture)
        self:send_message(const.SC_MESSAGE_LUA_CAPTURE_RET , {result = 0, capture_result = 0, pet_info = {pet_id = self.pet_id_capturing}, rate = rate, rate_addition = rate_addition,})
        if self.cap_timer ~= nil then
            timer.destroy_timer(self.cap_timer)
            self.cap_timer = nil
        end
        self:capture_pet_success({pet_id = self.pet_id_capturing})
        reset_data(self)
        return 0
    end
    --捕获宠物失败
    if self.capture_times == 0 then
        flog("syzDebug", "on_end_capture : self.capture_times is 0 ")
        if self.cap_timer ~= nil then
            timer.destroy_timer(self.cap_timer)
            self.cap_timer = nil
        end
        reset_data(self)
        self:send_message(const.SC_MESSAGE_LUA_CAPTURE_RET , {result = 0, capture_result = const.CAPTURE_RESULT_FAIL_TIMES_EXHAUST})
    else
        flog("syzDebug", "on_end_capture : fail, but you can try again ")
        self:send_message(const.SC_MESSAGE_LUA_CAPTURE_RET , {result = 0, capture_result = const.CAPTURE_RESULT_FAIL_CONTINUE,
            pet_on_fight = self.pet_on_fight, rate = rate, rate_addition = rate_addition,})
    end
end

function imp_player_only.on_cancel_capture_wild_pet(self, input, syn_data)
    if self.cap_timer ~= nil then
        timer.destroy_timer(self.cap_timer)
        self.cap_timer = nil
    end
    reset_data(self)
    self:send_message(const.SC_MESSAGE_LUA_CANCEL_CAPTURE , {result = 0})
end

function imp_player_only.set_aoi_pos(self)
    flog("tmlDebug","imp_player_only.set_aoi_pos")
    local scene = self:get_scene()
    if scene == nil then
        return
    end

    if self:get_puppet() == nil then
        flog("tmlDebug","imp_aoi.imp_aoi_set_pos puppet == nil")
        return
    end
    local x,y,z = self:get_pos()
    self:set_pos(x,y,z)
end

function imp_player_only.gm_whosyourdaddy(self, input)
    if self.in_fight_server == true then
        self:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC, input)
        return
    end
    local open = input.open or "1"
    if open == "1" then
        open = true
    else
        open = false
    end
    local puppet = self:get_puppet()
    if puppet ~= nil then
        puppet:SetDaddy(open)
    end
end

return imp_player_only