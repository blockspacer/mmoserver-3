--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/2/8 0008
-- Time: 15:48
-- To change this template use File | Settings | File Templates.
--

require "Common/basic/LuaObject"
local item_effect = require "entities/items/item_effect"
local const = require "Common/constant"
local math = require "math"
local string_split = require("basic/scheme").string_split
local flog = require "basic/log"
local growing_pet_config = require "configs/growing_pet_config"

local pet_egg_effect = ExtendClass(item_effect)

function pet_egg_effect:__ctor()
    self.pet_id = 1
    self.output_type = 1
    self.level = 1
end

function pet_egg_effect:effect(launcher,target,count)
    local result = launcher:add_pet(self.output_type,self.pet_id,self.level)
    if result ~= 0 then
        return result
    end
    launcher:send_message(const.SC_MESSAGE_LUA_GAME_RPC,{result=0,func_name="UseBagItemReply",pet_id=self.pet_id})
    return 0
end

function pet_egg_effect:parse_effect(id,param1,param2)
    self.output_type = math.floor(tonumber(param1))
    if growing_pet_config.check_output_type(self.output_type) == false then
        flog("error","pet_egg_effect|parse_effect is fail,output_type is not find!!!,id:"..id..",output_type:"..self.output_type)
    end
    local params = string_split(param2,'|')
    if #params ~= 2 then
        flog("error","pet_egg_effect|parse_effect fail!!!")
    end
    self.pet_id = tonumber(params[1])
    if growing_pet_config.get_pet_config(self.pet_id) == nil then
        flog("error","pet_egg_effect|parse_effect fail!!!,can not find pet attribute,pet_id:"..self.pet_id)
    end
    self.level = tonumber(params[2])
    return true
end

return pet_egg_effect
