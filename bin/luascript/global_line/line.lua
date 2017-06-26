--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/4 0004
-- Time: 17:48
-- To change this template use File | Settings | File Templates.
--

local db_hiredis = require "basic/db_hiredis"
local common_parameter_formula_config = require "configs/common_parameter_formula_config"
local flog = require "basic/log"
local const = require "Common/constant"
local tostring = tostring
local tonumber = tonumber

local game_line = {}
local line_game = {}

--caller,callback回调函数，在需要创建新线路时，callback参数params回传的参数,error出错信息(可能无法找到新线路，比如所有线路已满员等)，game_id目标线路
--scene_id,场景id
--game_id,第一优先目标线路，为nil时表示没有，随机选择线路
--captain 是否队长，bool类型
--fllow是否跟随，只有captain为false时才生效
local function auto_select_line(scene_id,game_id,fllow)
    flog("tmlDebug","line|auto_select_line")
    local error = 0
    if scene_id == nil then
        flog("debug","auto_select_line param error!!!")
        return
    end

    if fllow == nil then
        fllow = false
    end

    if game_id ~= nil then
        --指定分线
        local result = db_hiredis.zscore("scene_"..scene_id,tostring(game_id))
        if result ~= nil then
            result = tonumber(result)
            --指定分线流畅或者跟随时指定分线未达到绝对上限，可以直接进入
            flog("tmlDebug","result "..result..",LINE_PLAYER_UPPER_LIMIT_FLUENCY "..common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_FLUENCY..",fllow "..tostring(fllow)..",LINE_PLAYER_UPPER_LIMIT_B "..common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_B)
            if result < common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_FLUENCY or (fllow and result < common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_B ) then
                return game_id
            end
        end
    end
    --指定分线无法满足条件，寻早第一个满足条件的分线
    local lines = db_hiredis.zrangebyscore("scene_"..scene_id,-10000,common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_FLUENCY,false)
    local new_game_id = nil
    if lines ~= nil then
        local tmp_game_id = 0
        for i = 1,#lines,1 do
            tmp_game_id = tonumber(lines[i])
            if new_game_id == nil or tmp_game_id < new_game_id then
                new_game_id = tmp_game_id
            end
        end
    end
    --已找到合适的分线
    if new_game_id ~= nil then
        return new_game_id
    end
    --找不到合适分线,找人数最少的分线
    lines = db_hiredis.zrange("scene_"..scene_id,0,-1,false)
    if lines ~= nil and #lines > 0 then
        return tonumber(lines[1])
    end
    return nil
end

local function manual_select_game_line(params,callback,scene_id,game_id,fllow)
    flog("tmlDebug","manual_select_game_line")
    local error = 0
    if params == nil or callback == nil or scene_id == nil or game_id == nil then
        flog("debug","manual_select_game_line param error!!!")
        return
    end

    --指定分线
    local result = db_hiredis.zscore("scene_"..scene_id,tostring(game_id))
    if result ~= nil then
        result = tonumber(result)
        --指定分线流畅或者跟随时指定分线未达到绝对上限，可以直接进入
        flog("tmlDebug","result "..result..",LINE_PLAYER_UPPER_LIMIT_A "..common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_A)
        if result < common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_A or (fllow and result < common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_B) then
            callback(params,error,game_id)
            return
        else
            error = const.error_select_game_line_scene_is_busy
        end
    else
        error = const.error_select_game_line_scene_not_start
    end
    callback(params,error,game_id)
end

local function response_convene(scene_id,game_id)
    flog("tmlDebug","response_convene")
    local error = 0
    if scene_id == nil or game_id == nil then
        flog("debug","response_convene param error!!!")
        return const.error_data
    end

    --指定分线
    local result = db_hiredis.zscore("scene_"..scene_id,tostring(game_id))
    if result ~= nil then
        result = tonumber(result)
        --指定分线流畅或者跟随时指定分线未达到绝对上限，可以直接进入
        flog("tmlDebug","result "..result..",LINE_PLAYER_UPPER_LIMIT_B "..common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_B)
        if result < common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_B then
            return 0
        else
            return const.error_select_game_line_scene_is_busy
        end
    end
    return const.error_select_game_line_scene_not_start
end

local function team_member_follow(scene_id,game_id)
    flog("tmlDebug","team_member_follow")
    if scene_id == nil or game_id == nil then
        flog("debug","team_member_follow param error!!!")
        return
    end

    --指定分线
    local result = db_hiredis.zscore("scene_"..scene_id,tostring(game_id))
    if result ~= nil then
        result = tonumber(result)
        --指定分线流畅或者跟随时指定分线未达到绝对上限，可以直接进入
        if result < common_parameter_formula_config.LINE_PLAYER_UPPER_LIMIT_B then
            return true
        end
    end
    return false
end

local function on_update_game_line_info(input)
    flog("tmlDebug","on_update_game_line_info input "..table.serialize(input))
    game_line = table.copy(input.game_line)
    line_game = table.copy(input.line_game)
end

local function get_line_by_game_id(game_id)
    return game_line[game_id]
end

local function get_game_id_by_line(line)
    return line_game[line]
end

return {
    auto_select_line = auto_select_line,
    manual_select_game_line = manual_select_game_line,
    team_member_follow = team_member_follow,
    on_update_game_line_info = on_update_game_line_info,
    get_line_by_game_id = get_line_by_game_id,
    get_game_id_by_line = get_game_id_by_line,
    response_convene = response_convene,
}