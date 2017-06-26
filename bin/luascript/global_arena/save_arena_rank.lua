--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/4/20 0020
-- Time: 17:25
-- To change this template use File | Settings | File Templates.
--

local flog = require "basic/log"
local data_base = require "basic/db_mongo"
local timer = require "basic/timer"
local const = require "Common/constant"
local online_user = require "global_arena/arena_online_user"
local _get_now_time_second = _get_now_time_second
local challenge_arena = require "data/challenge_arena"

local function _db_callback_save_data(caller, status)
    flog("info", "arena _db_callback_save_data! ")
    if status == false then
        flog("warn", "arena _db_callback_save_data : save fail ")
        return
    end
end

local function save_arena_rank()
    if arena_center_instance ~= nil then
        local arena_ranks = arena_center_instance.arena_ranks
        local actors = {}
        for grade_id,ranks in pairs(arena_ranks) do
            for actor_id,rank in pairs(ranks) do
                if table.isEmptyOrNil(rank) == false then
                    data_base.db_update_doc(0, _db_callback_save_data, "arena_ranks", {actor_id=actor_id}, rank, 1, 0)
                    table.insert(actors,actor_id)
                end
            end
        end
        data_base.db_update_doc(0, _db_callback_save_data, "arena_actors", {}, actors, 1, 0)
    end
end

local function sort_dogfigght_rank(self)
    local tmp_actors = {}
    for actor_id,rank in pairs(self.arena_actors) do
        table.insert(tmp_actors,{actor_id=actor_id,total_score=rank.total_score})
    end

    table.sort(tmp_actors,function(a,b)
        return b.total_score < a.total_score
    end)
    for i=1,#tmp_actors,1 do
        self.arena_actors[tmp_actors[i].actor_id].total_rank = i
    end
    local player = nil
    for actor_id,rank in pairs(self.arena_actors) do
        player = online_user.get_user(actor_id)
        if player ~= nil then
            player:send_message_to_game({func_name="update_arena_dogfight_rank",dogfight_rank=rank.total_rank})
        end
    end
end

local function start_save_arena_data()
    flog("info","start_save_arena_data")
    if arena_center_instance ~= nil then
        if arena_center_instance.sort_timer ~= nil then
            flog("info","start_save_arena_data destroy_timer")
            timer.destroy_timer(arena_center_instance.sort_timer)
            arena_center_instance.sort_timer = nil
        end
        sort_dogfigght_rank(arena_center_instance)
        save_arena_rank()
        arena_center_instance.next_refresh_rank_time = _get_now_time_second() + 600
        local function syn_tick()
            --排序
            flog("info","start_save_arena_data syn_tick")
            sort_dogfigght_rank(arena_center_instance)
            arena_center_instance.next_refresh_rank_time = _get_now_time_second() + 600
            save_arena_rank()
        end

        arena_center_instance.sort_timer = timer.create_timer(syn_tick, 600000, const.INFINITY_CALL)
    end
end

local arena_grade_configs = {}
for _,v in pairs(challenge_arena.QualifyingGrade) do
    arena_grade_configs[v.ID] = v
end

local function init_arena_rank()
    for i,_ in pairs(arena_grade_configs) do
        if arena_center_instance.arena_ranks[i] == nil then
            arena_center_instance.arena_ranks[i] = {}
        end
        if arena_center_instance.qualifying_max[i] == nil then
            arena_center_instance.qualifying_max[i] = 0
        end
    end
end

return {
    save_arena_rank = save_arena_rank,
    start_save_arena_data = start_save_arena_data,
    init_arena_rank = init_arena_rank,
}