--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/6/14 0014
-- Time: 18:02
-- To change this template use File | Settings | File Templates.
--
local progress_test = require "data/progress_test"
local string_split = require("basic/scheme").string_split
local scene_routes = {}
local tonumber = tonumber
local flog = require "basic/log"

local function reload()
    scene_routes = {}
    for _,v in pairs(progress_test.Scene) do
        scene_routes[v.ID] = {}
        for i = 1,4,1 do
            if v["Coordinate"..i] ~= nil and v["Coordinate"..i] ~= "" then
                local pos_str = string_split(v["Coordinate"..i],"|")
                if #pos_str==3 then
                    table.insert(scene_routes[v.ID],{x=tonumber(pos_str[1]),y=tonumber(pos_str[2]),z=tonumber(pos_str[3])})
                end
            end
        end
    end
end

local function get_next_random_pos(id)
    flog("tmlDebug","id "..id)
    return scene_routes[id][math.random(#scene_routes[id])]
end


reload()

return {
    reload = reload,
    get_next_random_pos = get_next_random_pos,
}

