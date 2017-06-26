--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/23 0023
-- Time: 15:20
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local challenge_main_dungeon_config = require "configs/challenge_main_dungeon_config"
local timer = require "basic/timer"
local flog = require "basic/log"
local math = require "math"
local online_user = require "fight_server/fight_server_online_user"
local scheme = require "basic/scheme"
local table = table
local _get_now_time_second = _get_now_time_second
local fight_ser

local DungeonState =
{
    no_start = 1,       --未开始
    playing = 2,        --进行中
    over = 3,           --已结束
    done = 4,           --已完成
}

local dungeon_type = const.DUNGEON_TYPE

local dungeon_room = {}
dungeon_room.__index = dungeon_room

setmetatable(dungeon_room, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

local params = {
}
dungeon_room.__params = params

function dungeon_room.__ctor(self,dungeon_config,aoi_scene_id)
    self.dungeon_config = dungeon_config
    self.aoi_scene_id = aoi_scene_id
    self.over = false
    self.start_time = _get_now_time_second()
    self.state = DungeonState.no_start
    self.isWin = false
    self.mark = 0
    self.mark_change = false
    self.current_wave = 1
    self:init()
end

--结束副本
local function end_dungeon(self,iswin,wave)
    if self.state == DungeonState.over or self.state == DungeonState.done then
        return
    end
    flog("tmlDebug","end_dungeon")
    self.isWin = iswin
    if wave == nil then
        if iswin then
            self.wave = 1
        else
            self.wave = 0
        end
    else
        self.wave = wave
    end
    self.state = DungeonState.over
end

-- 查询某场景元素是否死亡
local function is_dead(self,scene_entity_id)
    local is_entity_dead = false
    local scene = scene_manager.find_scene(self.aoi_scene_id)
    if scene == nil then
        return is_entity_dead
    end
    is_entity_dead = scene:get_entity_manager().IsPuppetDead(scene_entity_id/1)
    return is_entity_dead
end
-- 查询是不是都死了
local function is_all_dead(self,sceneIDArray)
    for _, v in ipairs(sceneIDArray) do
        if not is_dead(self,v) then
            return false
        end
    end
    return true
end

function dungeon_room.init(self)
    if self.dungeon_config == nil then
        return
    end
    self.type = self.dungeon_config.type

    flog("tmlDebug","dungeon start type:" .. tostring(self.dungeon_config.type) ..
			", para1:" .. tostring(self.dungeon_config.element1) .. ", para2:" .. tostring(self.dungeon_config.element2))

    self.leftTime = math.floor(self.dungeon_config.Time / 1000) + _get_now_time_second()

    if self.type == dungeon_type.kill_target then
        self.para1 = self.dungeon_config.element1
    elseif self.type == dungeon_type.peotect then -- 保卫
        self.para1 = self.dungeon_config.element1
        self.para2 = string.split(self.dungeon_config.element2, '|')
    elseif self.type == dungeon_type.escort then -- 护送

    elseif self.type == dungeon_type.sneakon then -- 潜入
    elseif self.type == dungeon_type.fenxian then -- 分线对推
        self.para1 = self.dungeon_config.element1
        self.para2 = self.dungeon_config.element2
    elseif self.type == dungeon_type.in_limited_time then --限时击杀
        self.para1 = {}
        local targets = scheme.string_split(self.dungeon_config.element2,'|')
        for _,target in pairs(targets) do
            table.insert(self.para1,math.floor(tonumber(target)))
        end
        self.para2 = #targets
        if self.para2 == 0 then
            flog("error","can not find targets!!!")
        end
    end
end

--死亡多少个了？？？
local function dead_count(self,sceneIDArray)
    local count = 0
    for _, v in ipairs(sceneIDArray) do
        if is_dead(self,v) then
            count = count + 1
        end
    end
    return count
end

function dungeon_room.update(self,current_time)
    if self.state == DungeonState.over or self.state == DungeonState.done then
        return
    end

    local mark = 0
    local count = 0
    if self.dungeon_config.type == dungeon_type.in_limited_time then
        count = dead_count(self,self.para1)
        mark = challenge_main_dungeon_config.get_dungeon_mark(self.dungeon_config.type,count,self.para2)
        self.current_wave = count + 1
        if mark == 0 then
            flog("warn","dungeon_room.update mark == 0 type "..self.dungeon_config.type..",count "..count..",para2 "..self.para2)
        end
    else
        mark = challenge_main_dungeon_config.get_dungeon_mark(self.dungeon_config.type,self.leftTime - current_time,self.dungeon_config.Time)
        if mark == 0 then
            flog("warn","dungeon_room.update mark == 0 type "..self.dungeon_config.type..",time "..(self.leftTime - current_time)..",para2 "..self.dungeon_config.Time)
        end
    end
    if mark ~= self.mark then
        self.mark = mark
        self.mark_change = true
    end

    if self.leftTime <= current_time then -- 时间到
        if self.type ~= dungeon_type.in_limited_time then
            end_dungeon(self,false)
        else
            if count > 0 then
                end_dungeon(self,true,count)
            else
                end_dungeon(self,false,count)
            end
        end
        return
    end

    if self.type == dungeon_type.kill_target then
        if is_dead(self,self.para1) then
            end_dungeon(self,true)
            return
        end
    elseif self.type == dungeon_type.peotect then -- 保卫
        if is_dead(self,self.para1) then -- 保卫的对象死了
            end_dungeon(self,false)
            return
        end
        if is_all_dead(self,self.para2) then -- 怪物都死光了
            end_dungeon(self,true)
            return
        end
    elseif self.type == dungeon_type.escort then -- 护送
        if self.para1 == nil then
            local scene = scene_manager.find_scene(self.aoi_scene_id)
            if scene ~= nil and self.dungeon_config ~= nil then
                self.para1 = scene:get_entity_manager().QueryPuppet(function(v)
                    if v.data.ElementID == self.dungeon_config.element1 then
                        return true
                    else
                        return false
                    end
                end)
            end
        end
        if self.para1 == nil then
            return
        end
        if is_dead(self,self.para1.data.ElementID) then
            end_dungeon(self,false)
            return
        end
        if self.para1.taskData.isReached then
            end_dungeon(self,true)
        end
    elseif self.type == dungeon_type.sneakon then -- 潜入
    elseif self.type == dungeon_type.fenxian then -- 分线对推
        if is_dead(self,self.para2) then -- 保卫的对象死了
            end_dungeon(self,false)
            return
        end
        if is_dead(self, self.para1) then -- boss 死亡了
            end_dungeon(self,true)
            return
        end
    elseif self.type == dungeon_type.in_limited_time then       --限时击杀
        if is_all_dead(self,self.para1) then -- 怪物都死光了
            end_dungeon(self,true,self.para2)
            return
        end
    end
end

function dungeon_room.set_state_done(self)
    self.state = DungeonState.done
end

function dungeon_room.is_over(self)
    return self.state == DungeonState.over
end

function dungeon_room.is_done(self)
    return self.state == DungeonState.done
end

function dungeon_room.get_start_time(self)
    return self.start_time
end

function dungeon_room.get_isWin(self)
    return self.isWin
end

function dungeon_room.set_mark_change(self,value)
    self.mark_change = value
end

function dungeon_room.get_mark_change(self)
    return self.mark_change
end

function dungeon_room.send_mark_to_client(self,actor_id,enter_aoi)
    flog("tmlDebug","dungeon_room.send_mark_to_client enter_aoi "..tostring(enter_aoi))
    if self.state == DungeonState.over or self.state == DungeonState.done then
        if enter_aoi then
            local player = online_user.get_user(actor_id)
            if player ~= nil then
                player:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{func_name="UpdateDungeonMark",result=0,mark=self.mark,start_time=self.start_time,current_wave=self.current_wave,over=true})
            end
        end
        return
    end

    local player = online_user.get_user(actor_id)
    if player ~= nil then
        player:send_message(const.DC_MESSAGE_LUA_GAME_RPC,{func_name="UpdateDungeonMark",result=0,mark=self.mark,start_time=self.start_time,current_wave=self.current_wave,over=false})
    end
end

function dungeon_room.get_mark(self)
    return self.mark
end

function dungeon_room.get_wave(self)
    return self.wave
end

return dungeon_room