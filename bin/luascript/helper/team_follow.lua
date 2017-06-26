--------------------------------------------------------------------
-- 文件名:	team_follow.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/1/20 0020
-- 描  述:	组队跟随
--------------------------------------------------------------------
local flog = require "basic/log"
local const = require "Common/constant"

local FOLLOW_TIME_INTERVAL = 1      --组队跟随采样间隔时间

local team_follow_info_hash = {}

local function start_team_follow(captain, followers)
    if captain == nil then
        return
    end

    if table.isEmptyOrNil(followers) then
        return
    end

    local captain_id = captain.actor_id
    local info = team_follow_info_hash[captain_id] or {}
    if info.timer ~= nil then
        Timer.Remove(info.timer)
        info.timer = nil
    end
    info.followers = followers or {}
    local follow_callback = function ()
        flog("syzDebug", "follow....")
        if captain == nil then
            return
        end
        local x,y,z = captain:get_pos()
        local scene_id = captain:get_aoi_scene_id()
        local path = info.path
        if path == nil then
            info.path = {}
            path = info.path
            path.scene_id = scene_id
        end
        if path[2] == nil or path[1][1] ~= x or path[1][2] ~= y or path[1][3] ~= z then
            if path.scene_id == scene_id then
                path[2] = path[1]
            else
                path[2] = nil
                path.scene_id = scene_id
            end
            path[1] = {x,y,z }
        end

        local follow_num = #info.followers
        for index, member in pairs(info.followers) do
            if follow_num == 0 then
                flog("error", "start_team_follow: follow_num is 0")
                break
            end
            if path[2] == nil then
                break
            end

            local x2 = path[2][1]
            local y2 = path[2][2]
            local z2 = path[2][3]

            local fx = x - (x - x2) / const.MAX_TEAM_MEMBER_NUM * index
            local fy = y - (y - y2) / const.MAX_TEAM_MEMBER_NUM * index
            local fz = z - (z - z2) / const.MAX_TEAM_MEMBER_NUM * index
            repeat
                if member == nil then
                    break
                end
                if member.in_fight_server and member.fight_type ~= const.FIGHT_SERVER_TYPE then
                    break
                end
                if not member.in_fight_server then
                    local member_scene_id = member:get_aoi_scene_id()
                    if member_scene_id ~= scene_id then
                        --member:teleport_to_scene(scene_id, fx, fy, fz)
                    else
                        local puppet = member:get_puppet()
                        if puppet ~= nil then
                            puppet:Moveto(Vector3.New(fx, fy, fz))
                        end
                    end
                elseif not captain.in_fight_server then
                    member:send_to_fight_server(const.GD_MESSAGE_LUA_GAME_RPC,{func_name="on_leave_task_dungeon"})
                end
            until(true)
        end
    end
    info.timer = Timer.Repeat(FOLLOW_TIME_INTERVAL, follow_callback)
    team_follow_info_hash[captain_id] = info
end

local function end_team_follow(captain)
    local captain_id = captain.actor_id
    local info = team_follow_info_hash[captain_id] or {}
    if info.timer ~= nil then
        Timer.Remove(info.timer)
        info.timer = nil
    end
    team_follow_info_hash[captain_id] = nil
end

local function add_team_follower(captain, follower)
    local captain_id = captain.actor_id
    local follower_id = follower.actor_id
    if captain == follower or captain_id == follower_id then
        return
    end
    local info = team_follow_info_hash[captain_id]
    if info == nil then
        return start_team_follow(captain, {follower})
    end

    local followers = info.followers
    for _, v in pairs(followers) do
        if v.actor_id == follower_id then
            return
        end
    end

    table.insert(followers, follower)

end

local function remove_team_follower(captain, follower)
    if captain == nil then
        return
    end
    local captain_id = captain.actor_id
    local follower_id = follower.actor_id
    local info = team_follow_info_hash[captain_id]
    if info == nil then
        return
    end
    local index
    for i, v in pairs(info.followers) do
        if v.actor_id == follower_id then
            index = i
            break
        end
    end
    if index~=nil then
        local follower = table.remove(info.followers, index)
        local puppet = follower:get_puppet()
        if puppet ~= nil then
            puppet:StopMove()
        end
    end
    
    if table.isEmptyOrNil(info.followers) then
        end_team_follow(captain)
    end
end

return {
    start_team_follow = start_team_follow,
    end_team_follow = end_team_follow,
    add_team_follower = add_team_follower,
    remove_team_follower = remove_team_follower,
}