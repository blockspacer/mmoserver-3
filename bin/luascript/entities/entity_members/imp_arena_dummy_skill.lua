--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/9 0009
-- Time: 9:56
-- To change this template use File | Settings | File Templates.
--

local params = {
    cur_plan = {db = true,sync = true, default = 1},
}

local imp_arena_dummy_skill = {}
imp_arena_dummy_skill.__index = imp_arena_dummy_skill

setmetatable(imp_arena_dummy_skill, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_arena_dummy_skill.__params = params

function imp_arena_dummy_skill.__ctor(self)
    self.skill_level = {}
    self.skill_plan = {}
end

--根据dict初始化
function imp_arena_dummy_skill.imp_arena_dummy_skill_init_from_dict(self, dict)
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

function imp_arena_dummy_skill.imp_arena_dummy_skill_write_to_dict(self, dict)

end

function imp_arena_dummy_skill.imp_arena_dummy_skill_write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
    dict.skill_level = table.copy(self.skill_level)
    dict.skill_plan = table.copy(self.skill_plan)
end

--竞技场假人设置防守技能，只允许竞技场假人调用
function imp_arena_dummy_skill.set_arena_dummy_skill(self,skill_info)
    self.skill_plan ={}
    self.skill_plan[1] = skill_info
    self.cur_plan = 1
end

return imp_arena_dummy_skill