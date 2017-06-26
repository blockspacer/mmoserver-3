--------------------------------------------------------------------
-- 文件名:	gm_command.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/29
-- 描  述:	gm指令，删除改指令则gm不可用
--------------------------------------------------------------------
local string_split = require("basic/scheme").string_split
local tonumber = tonumber
local scheme = require "basic/scheme"
local const = require "Common/constant"

local function gm_command(avatar, command, syn_data)
    local params = string_split(command)
    if params[1] == "add" then  --添加物品与资源
        return avatar:gm_add_item(tonumber(params[2]), tonumber(params[3]), syn_data)
    elseif params[1] == "setres" then        --设置资源
        return avatar:gm_set_resource(params[2], tonumber(params[3]), syn_data)
    elseif params[1] == "local" then        --本地指令直接下发
        return 0
    elseif params[1] == "pet" then      --宠物相关
        if params[2] == "upgrade" then  --宠物升级
            local new_level
            if params[4] ~= nil then
                new_level = tonumber(params[4])
            end
            return avatar:gm_pet_upgrade(tonumber(params[3]), new_level)
        elseif params[2] == "add" then  --添加宠物
            local level = 1
            if params[4] ~= nil then
                level = tonumber(params[4])
            end
            return avatar:gm_add_pet(tonumber(params[3]), level)
        elseif params[2] == "detail" then --获取宠物分数详情
            return avatar:gm_get_pet_score_detail(tonumber(params[3]))
        elseif params[2] == "prop" then --获取宠物属性详情
            return avatar:gm_get_pet_property(tonumber(params[3]))
        end
        return -1
    elseif params[1] == "wander" then   --云游商人相关
        if params[2] == "appear" then   --云游商人强制出现
            return avatar:gm_wander_appear(tonumber(params[3]))
        end
    elseif params[1] == "hegemon" then   --霸主榜相关
        if params[2] == "clear" then      --清空霸主榜
            return avatar:gm_clear_dungeon_hegemon()
        elseif params[2] == "mail" then     --发霸主榜每日邮件奖励
            return avatar:gm_hegemon_dispense_rewards()
        end
    elseif params[1] == "set" then     --人物属性设置
        if params[2] == "level" then    --设置等级
            return avatar:gm_set_player_level(tonumber(params[3]), syn_data)
        elseif params[2] == "addlevel" then
            local current_level = avatar:get("level")
            return avatar:gm_set_player_level(tonumber(params[3]) + current_level, syn_data)
        elseif params[2] == "prestige" then
            return avatar:gm_set_player_prestige(tonumber(params[3]), syn_data)
        elseif params[2] == "pkvalue" then
            return avatar:gm_set_pk_value(tonumber(params[3]), syn_data)
        elseif params[2] == "openday" then
            return avatar:gm_set_open_day(tonumber(params[3]))
        elseif params[2] == "petenergy" then
            return avatar:gm_set_capture_energy(tonumber(params[3]), syn_data)
        elseif params[2] == "hp" then
            return avatar:gm_set_puppet_value("hp", tonumber(params[3]))
        elseif params[2] == "mp" then
            return avatar:gm_set_puppet_value("mp", tonumber(params[3]))
        elseif params[2] == "liveness" then
            return avatar:gm_set_avatar_value("liveness_current", tonumber(params[3]))
        elseif params[2] == "livenesstotal" then
            return avatar:change_value_on_rank_list("liveness_history", tonumber(params[3]))
        elseif params[2] == "task" then
            return avatar:gm_set_task(tonumber(params[3]))
        elseif params[2] == "karma" then
            return avatar:change_value_on_rank_list("karma_value", tonumber(params[3]))
        elseif params[2] == "warscore" then
            return avatar:change_value_on_rank_list("country_war_score", tonumber(params[3]))
        end
    elseif params[1] == "warrank" then
        if params[2] == "regetreward" then
            return avatar:gm_war_rank_reward_reget()
        elseif params[2] == "set" then
            return avatar:gm_set_war_rank(tonumber(params[3]))
        elseif params[2] == "refresh" then
            return avatar:gm_force_refresh_daily_data()
        end
    elseif params[1] == "player" then
        if params[2] == "reset" then
            return avatar:gm_on_reset()
        end
    elseif params[1] == "rpc" then
        return avatar[params[2]](avatar)
    elseif params[1] == "clear" then
        if params[2] == "buylimit" then
            return avatar:gm_clear_shop_item_buy_num()
        end
    elseif params[1] == "unlockall" then
        return avatar:gm_unlock_all_dungeon(syn_data)
    elseif params[1] == "add_player_equipment" then
        return avatar:gm_add_player_equipment(syn_data)
    elseif params[1] == "system" then
        if params[2] == "notice" then
            return gm_broadcast_loudspeaker(tonumber(params[3]), params[4], params[5], params[6], params[7], params[8], params[9])
        end
    elseif params[1] == "laosiji" then
        return gm_dispatch_transport_fleet_now()
    elseif params[1] == "war" then
        if params[2] == "start" then
            return avatar:gm_start_country_war(tonumber(params[3]))
        end
    elseif params[1] == "test" then
        if params[2] == "msg" then
            local common_char_chinese_config = require "configs/common_char_chinese_config"
            local msg = common_char_chinese_config.get_configed_ui_text("election_remaining_time", "2天")
            local output = {func_name = "SystemDirectMessage", msg = msg }
            avatar:send_message(const.DC_MESSAGE_LUA_GAME_RPC, output)
        end
    elseif params[1] == "ele" then
        if params[2] == "qual" then
            return avatar:gm_start_qualification_office_candidate()
        elseif params[2] == "count" then
            return avatar:gm_start_count_votes()
        elseif params[2] == "state" then
            return avatar:gm_change_election_state(params[3])
        elseif params[2] == "cleardata" then
            return avatar:gm_clear_election_data()
        elseif params[2] == "office" then
            return avatar:gm_become_officer(tonumber(params[3]))
        elseif params[2] == "resetcd" then
            return avatar:gm_clear_skill_cd()
        end
    elseif params[1] == "time" then
        local new_time = scheme.get_time_from_date_string(params[2])
        _set_now_time_second(new_time)
    elseif params[1] == "save" then
        return avatar:save_data()
    elseif params[1] == "ranklist" then
        if params[2] == "refresh" then
            return avatar.gm_refresh_all_player_rank()
        end
    elseif params[1] == "candidate" then
        avatar:change_value_on_rank_list("liveness_history", 1000)
        avatar:change_value_on_rank_list("karma_value", 1000)
        avatar:change_value_on_rank_list("country_war_score", 1000)
        avatar:save_data()
        avatar.gm_refresh_all_player_rank()
    elseif params[1] == "whosyourdaddy" then
        avatar:gm_whosyourdaddy({func_name = "gm_whosyourdaddy", open = params[2]})
    end
end


return gm_command