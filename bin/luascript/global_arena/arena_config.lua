--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/12/23 0023
-- Time: 14:35
-- To change this template use File | Settings | File Templates.
--

local flog = require "basic/log"
local challenge_arena = require "data/challenge_arena"

local first_arena_grade_id = 0
local arena_grade_configs = {}
for _,v in pairs(challenge_arena.QualifyingGrade) do
    arena_grade_configs[v.ID] = v
    if v.NextGrade == 0 then
        first_arena_grade_id = v.ID
    end
end

--竞技场段位索引，混战赛匹配使用
local tmp_grade_config = arena_grade_configs[first_arena_grade_id]
if tmp_grade_config == nil then
    flog("error","arena grade configs error!!")
end

local tmp_index = 1
local arena_grade_index = {}
local arena_grade_list = {}
while tmp_grade_config ~= nil do
    arena_grade_index[tmp_grade_config.ID]=tmp_index
    tmp_index = tmp_index + 1
    table.insert(arena_grade_list,tmp_grade_config.ID)
    if tmp_grade_config.ExGrade ~= tmp_grade_config.ID then
        tmp_grade_config = arena_grade_configs[tmp_grade_config.ExGrade]
    end
end

local function get_arena_grade_list()
    return arena_grade_list
end

return{
    get_arena_grade_list = get_arena_grade_list,
}