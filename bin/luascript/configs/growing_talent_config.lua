--------------------------------------------------------------------
-- 文件名:	growing_talent_config.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/6/20 0020
-- 描  述:	天赋成长配置文件
--------------------------------------------------------------------
local growing_talent_scheme = require("data/growing_talent")
local const = require "Common/constant"
local flog = require "basic/log"
local recreate_scheme_table_with_key = require("basic/scheme").recreate_scheme_table_with_key
local page_unlock_orignal = growing_talent_scheme.TalentUnlock
local page_unlock_scheme
local levelup_exp_orignal = growing_talent_scheme.TalentLv
local levelup_exp_scheme
local talent_upgrade_orignal = growing_talent_scheme.TalentUpgrade
local talent_upgrade_scheme
local talent_orignal = growing_talent_scheme.Talent
local talent_scheme
local string_split = require("basic/scheme").string_split
local tostring = tostring
local string_format = string.format
local PROPERTY_INDEX_TO_NAME = const.PROPERTY_INDEX_TO_NAME
local tonumber = tonumber

local function get_page_unlock_condition(page_index)
    local config = page_unlock_scheme[page_index]
    if config == nil then
        flog("error", "get_page_unlock_condition fail "..tostring(page_index))
        return
    end
    return config.NeedPlayerLv, config.NeedTalentLv
end

local function get_talent_upgrade_consume(talent_id, slot_level)
    local config = talent_upgrade_scheme[talent_id]
    if config == nil then
        flog("error", "get_talent_upgrade_require fail "..tostring(talent_id))
        return
    end
    local index = #config
    for i, v in pairs(config) do
        if slot_level < v.Lv_lower then
            index = i - 1
            break
        end
    end
    if config[index] == nil then
        flog("error", "get_talent_upgrade_require wrong level config "..tostring(slot_level))
        return
    end
    local consume = {}
    local detail_config = config[index]
    local delta_level = slot_level - detail_config.Lv_lower
    for i = 1, 2 do
        local key = string_format("Consume%dID", i)
        local inc_key = "ConsumeIncrement"..i
        local id = detail_config[key][1]
        local count = detail_config[key][2]
        count = count + delta_level * detail_config[inc_key]
        consume[id] = count
    end

    return consume
end

local function get_talent_level(exp_consumed)
    local level = 0
    for i, v in ipairs(levelup_exp_scheme) do
        if exp_consumed >= v.NeedExp then
            level = i
        else
            break
        end
    end
    return level
end


local function reload()
    page_unlock_scheme = recreate_scheme_table_with_key(page_unlock_orignal, "TalentPage")
    levelup_exp_scheme = recreate_scheme_table_with_key(levelup_exp_orignal, "Lv")
    talent_upgrade_scheme = {}
    for _, v in ipairs(talent_upgrade_orignal) do
        talent_upgrade_scheme[v.TalentSlotID] = talent_upgrade_scheme[v.TalentSlotID] or {}
        table.insert(talent_upgrade_scheme[v.TalentSlotID], v)
    end
    talent_scheme = {}
    for i, v in pairs(talent_orignal) do
        local new_v = table.copy(v)
        if new_v.LogicID == const.TALENT_TYPE.attrib_modify then
            new_v.base_addition = {}
            new_v.percent_addition = {}
            for j = 1, 5 do
                local key = "Parameter"..j
                if v[key] ~= "" and v[key] ~= nil then
                    local param = string_split(v[key], "|")
                    if param[1] == "A" then
                        local addition = string_split(param[2], "=")
                        new_v.base_addition[PROPERTY_INDEX_TO_NAME[tonumber(addition[1])]] = tonumber(addition[2])
                    elseif param[1] == "B" then
                        local addition = string_split(param[2], "=")
                        new_v.percent_addition[PROPERTY_INDEX_TO_NAME[tonumber(addition[1])]] = tonumber(addition[2])
                    else
                        flog("error", "growing_talent_scheme talent_scheme error type "..tostring(param[1]))
                    end
                end
            end
            talent_scheme[new_v.PostionID] = new_v
        end
    end
end
reload()

return {
    reload = reload,
    get_page_unlock_condition = get_page_unlock_condition,
    get_talent_upgrade_consume = get_talent_upgrade_consume,
    talent_scheme = talent_scheme,
    get_talent_level = get_talent_level,
}
