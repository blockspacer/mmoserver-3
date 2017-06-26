--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/11 0011
-- Time: 13:51
-- To change this template use File | Settings | File Templates.
--

local const = require "Common/constant"
local flog = require "basic/log"

local params = {
    cur_plan = {db = true,sync = true, default = 1},
}

local imp_fight_avatar_skill = {}
imp_fight_avatar_skill.__index = imp_fight_avatar_skill

setmetatable(imp_fight_avatar_skill, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_fight_avatar_skill.__params = params

function imp_fight_avatar_skill.__ctor(self)
    self.skill_level = {}
    self.skill_plan = {}
end

--根据dict初始化
function imp_fight_avatar_skill.imp_fight_avatar_skill_init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
    self.skill_level = table.copy(table.get(dict, "skill_level", {1,1,1,1}))
    self.skill_plan = table.copy(table.get(dict, "skill_plan", {{},{},{}}))
end

function imp_fight_avatar_skill.imp_fight_avatar_skill_write_to_dict(self, dict)
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
    dict.skill_level = table.copy(self.skill_level)
    dict.skill_plan = table.copy(self.skill_plan)
end

function imp_fight_avatar_skill.imp_fight_avatar_skill_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
    dict.skill_level = table.copy(self.skill_level)
    dict.skill_plan = table.copy(self.skill_plan)
end

return imp_fight_avatar_skill

