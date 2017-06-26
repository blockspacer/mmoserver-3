--------------------------------------------------------------------
-- 文件名:	team.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/12/5
-- 描  述:	队伍
--------------------------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"
local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"
local MAX_LEVEL_CONFIG = challenge_team_dungeon_config.MAX_LEVEL_CONFIG     --等级上限
local challenge_team_dungeon_config = require "configs/challenge_team_dungeon_config"
local id_manager = require "idmanager"
local player_team_index = {}
local table_insert = table.insert
local pairs = pairs
local system_faction_config = require "configs/system_faction_config"
local onlinerole = require "global_team/team_online_user"

local serial_num = 1

local team = {}
team.__index = team

setmetatable(team, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})

function team.__ctor(self)
    self.members = {}
    self.captain_id = nil
    self.target = nil
    self.team_id = nil
    self.auto_join = false
    self.min_level = 1
    self.max_level = MAX_LEVEL_CONFIG.Value[1]
    self.in_dungeon = false
    self.altar_spritual_update_flag = false
end

function team.team_init_from_dict(self, dict)
    self.members = table.get(dict, "members", {})
    self.captain_id = dict.captain_id
    self.target = dict.target
    self.team_id = dict.team_id
    self.auto_join = dict.auto_join
    self.country = dict.country
    self.min_level = dict.min_level or 1
    self.max_level = dict.max_level or MAX_LEVEL_CONFIG.Value[1]
end

function team.team_write_to_dict(self, dict)
    dict.members = table.copy(self.members)
    dict.captain_id = self.captain_id
    dict.target = self.target
    dict.team_id = self.team_id
    dict.auto_join = self.auto_join
    dict.country = self.country
    dict.min_level = self.min_level
    dict.max_level = self.max_level
end

function team.team_write_to_sync_dict(self, dict, detail)
    detail = detail or "normal"
    dict.captain_id = self.captain_id
    dict.target = self.target
    dict.team_id = self.team_id
    dict.auto_join = self.auto_join
    dict.country = self.country
    dict.sure_sign = self.sure_sign
    dict.min_level = self.min_level
    dict.max_level = self.max_level
    if detail == "normal" then
        dict.members = table.copy(self.members)
        for i, v in pairs(dict.members) do
            v.session_id = string.format("%16.0f",v.session_id)
        end
    elseif detail == "brief" then
        dict.member_num = #self.members
        dict.captain_info = self.members[1]
    else
        flog("error", "team_write_to_sync_dict: error detail")
    end

end

function team.is_match(self, player)
    if player.level < self.min_level or player.level > self.max_level then
        return const.error_level_not_match_team
    end
    if player.country ~= self.country then
        return const.error_country_different
    end
    return 0
end

function team.set_level(self, min_level, max_level)
    min_level = min_level or 1
    max_level = max_level or MAX_LEVEL_CONFIG.Value[1]
    if min_level <= max_level then
        if min_level > 0 and min_level < MAX_LEVEL_CONFIG.Value[1] then
            self.min_level = min_level
        end
        if max_level > 0 and max_level < MAX_LEVEL_CONFIG.Value[1] then
            self.max_level = max_level
        end
    end
    return self.min_level, self.max_level
end


function team.add_member(self, player)
    if player_team_index[player.actor_id] ~= nil then
        return const.error_already_in_anothor_team
    end

    if self:is_full() then
        return const.error_team_is_full
    end
    table.insert(self.members, player)
    player_team_index[player.actor_id] = self.team_id
    self.altar_spritual_update_flag = true
    return 0
end

function team.create_team(self, captain, target, auto_join)
    self.members = {}
    self.captain_id = captain.actor_id
    self.target = target
    self.team_id = id_manager.get_valid_uid()
    self.auto_join = auto_join or false
    self.country = captain.country
    local result = self:add_member(captain)
    return result
end

function team.remove_member(self, member_id)
    local index
    for idx, member in pairs(self.members) do
        if member.actor_id == member_id then
            index = idx
            break
        end
    end

    if index == nil then
        return const.error_team_member_not_exist
    end
    local member = self.members[index]
    table.remove(self.members, index)
    player_team_index[member_id] = nil
    self.altar_spritual_update_flag = true
    return 0, member
end

function team.set_target(self, target)
    self.target = target
    if target == "free" then
        self.min_level = 1
    else
        self.min_level = challenge_team_dungeon_config.get_dungeon_unlock_level(target)
    end
    return 0
end


function team.change_captain_by_id(self, new_captain_id)
    if new_captain_id == self.captain_id then
        return const.error_is_team_captain_already
    end
    local new_cap_idx
    for idx, member in pairs(self.members) do
        if member.actor_id == new_captain_id then
            new_cap_idx = idx
            break
        end
    end
    if new_cap_idx == nil then
        return const.error_team_member_not_exist
    end

    local old_captain = self.members[1]
    self.members[1] = self.members[new_cap_idx]
    self.members[new_cap_idx] = old_captain
    self.captain_id = new_captain_id
    return 0, old_captain
end


function team.is_full(self)
    if #self.members >= const.MAX_TEAM_MEMBER_NUM then
        return true
    end
    return false
end

function team.clear_waiting_state(self)
    self.direct_enter = nil
    self.sure_sign = nil
    for _, member in pairs(self.members) do
        member.sure_sign = nil 
    end
    serial_num = serial_num + 1
end

function team.apply_member_operate(self)
    if self.sure_sign then
        return const.error_is_waiting_team_member_confirm
    end
    self:clear_waiting_state()
    self.sure_sign = serial_num
    return 0
end

function team.member_ensure_operate(self, member_id, sure_sign)
    if sure_sign ~= self.sure_sign then
        return false
    end
    local is_all_ready = true
    for _, v in pairs(self.members) do
        if v.sure_sign ~= self.sure_sign and v.actor_id ~= member_id then
            is_all_ready = false
        elseif v.actor_id == member_id then
            v.sure_sign = sure_sign
        end
    end

    return is_all_ready
end

function team.update_member_info(self, member_id, member_new_info)
    for i, v in pairs(self.members) do
        if v.actor_id == member_id then
            if self.members[i].scene_id ~= member_new_info.scene_id or self.members[i].faction_id ~= member_new_info.faction_id or self.members[i].faction_altar_level ~= member_new_info.faction_altar_level then
                self.altar_spritual_update_flag = true
            end
            self.members[i] = member_new_info
        end
    end
end

function team.get_unsure_members(self)
    local unsure_index = {}
    for i, v in pairs(self.members) do
        if v.sure_sign == nil then
            table.insert(unsure_index, i)
        end
    end
    return unsure_index
end

function team.get_captain(self)
    local v = self.members[1]
    if v.actor_id == self.captain_id then
        return v
    end
    flog("error", "team.get_captain: find captain error!")
end

function team.member_reconnect(self, member_id)
    local member
    local index
    for i, v in pairs(self.members) do
        if v.actor_id == member_id then
            v.is_online = true
            member = v
            index = i
            break
        end
    end
    if member ~= nil and member_id ~= self.captain_id then
        local captain = self:get_captain()
        if captain~= nil and not captain.is_online then
            self.members[1] = member
            self.members[index] = captain
            self.captain_id = member_id
        end
    end

    return member
end


function team.member_logout(self, member_id)
    local is_captain_change = false
    local member
    for i, v in pairs(self.members) do
        if v.actor_id == member_id then
            member = v
            break
        end
    end
    member.is_online = false

    if member ~= nil and self.captain_id == member_id then
        for i, v in pairs(self.members) do
            if v.is_online then
                self.members[1] = v
                self.members[i] = member
                self.captain_id = v.actor_id
                is_captain_change = true
                break
            end
        end
    end

    return is_captain_change, member
end

function team.get_members(self)
    local members = {}
    for _, member in pairs(self.members) do
        table.insert(members,member.actor_id)
    end
    return members
end

function team.altar_spritual_update(self)
    flog("tnlDebug","team.altar_spritual_update")
    self.altar_spritual_update_flag = false
    local factions = {}
    for member_id,member in pairs(self.members) do
        if member.faction_id ~= 0 then
            local team_player = onlinerole.get_user(member_id)
            if team_player ~= nil then
                local key = string_format("%s-%d-%d",member.faction_id,member.scene_id,team_player.game_id)
                if factions[key] == nil then
                    factions[key] = {}
                end
                table_insert(factions[key],member_id)
            end
        end
    end
    for faction_id,faction in pairs(factions) do
        if #faction > 1 then
            local max_spritual = 0
            for i=1,#faction,1 do
                if self.members[faction[i]].real_spritual > max_spritual then
                    max_spritual = self.members[faction[i]].real_spritual
                end
            end
            for i=1,#faction,1 do
                repeat
                    local spritual = max_spritual - self.members[faction[i]].real_spritual
                    if spritual <= 0 then
                        break
                    end
                    local altar_config = system_faction_config.get_altar_config(self.members[faction[i]].faction_altar_level)
                    if altar_config == nil then
                        break
                    end
                    spritual = math.floor(altar_config.Sp1*spritual/100)
                    if spritual > altar_config.Sp2 then
                        spritual = altar_config.Sp2
                    end
                    local team_player = onlinerole.get_user(faction[i])
                    if team_player == nil then
                        break
                    end
                    team_player:send_message_to_game({func_name="on_update_faction_altar_share_spritual",spritual=spritual})
                until(true)
            end
        end
    end
end

function team.update(self)
    if self.altar_spritual_update_flag then
        self:altar_spritual_update()
    end
end

function team.update_team_member_info(self,actor_id,property_name,value)
    if self.members[actor_id] == nil then
        return
    end
    self.members[actor_id][property_name] = value
    self.altar_spritual_update_flag = true
end

function team.set_altar_spritual_update_flag(self)
    self.altar_spritual_update_flag = true
end

function team.get_team_members_number(self)
    local count = 0
    for _, member in pairs(self.members) do
        count = count + 1
    end
    return count
end

return team