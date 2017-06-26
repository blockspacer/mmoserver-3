--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/10 0010
-- Time: 9:55
-- To change this template use File | Settings | File Templates.
--

local common_fight_base = require "data/common_fight_base"
local flog = require "basic/log"

local attributes = {}
for key,attribute in pairs(common_fight_base.Attribute) do
    attributes[key] = attribute
end

local function get_monster_attribute(key)
    return attributes[key]
end

local function get_monster_move_speed()
    return common_fight_base.Parameter[28].Value/100
end

local rebirth_index = {}
for i, v in ipairs(common_fight_base.Revive) do
    rebirth_index[v.Rebirthtype] = rebirth_index[v.Rebirthtype] or {}
    table.insert(rebirth_index[v.Rebirthtype], {index = i, lv = v.LowerLimit})
end

local function get_index_from_rebirth_times(type, times)
    local type_index = rebirth_index[type]
    if type_index == nil then
        flog("error", "get_index_from_rebirth_times: error type "..type)
        return
    end
    local idx
    local lv = 0
    for _, v in ipairs(type_index) do
        if times >= v.lv and v.lv > lv then
            idx = v.index
            lv = v.lv
        end
    end
    if idx == nil then
        idx = type_index[#type_index].index
    end
    return idx
end

local function get_rebirth_config(rebirth_type,times)
    local rebirth_config = nil
    local idx = get_index_from_rebirth_times(rebirth_type, times)
    if idx ~= nil then
        rebirth_config = common_fight_base.Revive[idx]
    end
    return rebirth_config
end

local boss_animation = {}
for _,v in pairs(common_fight_base.BossAnimation) do
    boss_animation[v.ID] = v
end
local function get_boss_animation_config(animation_id)
    return boss_animation[animation_id]
end

local function get_pet_rebirth_time()
    return common_fight_base.Parameter[62].Value
end

return{
    get_monster_attribute = get_monster_attribute,
    get_monster_move_speed = get_monster_move_speed,
    get_rebirth_config = get_rebirth_config,
    get_boss_animation_config = get_boss_animation_config,
    get_pet_rebirth_time = get_pet_rebirth_time,
}