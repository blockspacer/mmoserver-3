--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/9 0009
-- Time: 11:03
-- To change this template use File | Settings | File Templates.
--

local params = {
}
local imp_arena_dummy_arena = {}
imp_arena_dummy_arena.__index = imp_arena_dummy_arena

setmetatable(imp_arena_dummy_arena, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_arena_dummy_arena.__params = params

function imp_arena_dummy_arena.__ctor(self)
    self.defend_pet = {}
    self.arena_defend_skill = {}
end

function imp_arena_dummy_arena.imp_arena_dummy_arena_init_from_dict(self,dict)
    local arena_info = table.get(dict,"arena_info",{})
    for i, v in pairs(params) do
        if arena_info[i] ~= nil then
            self[i] = arena_info[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end

    if arena_info.defend_pet == nil then
        self.defend_pet = {}
    else
        self.defend_pet = table.copy(arena_info.defend_pet)
    end

    if arena_info.arena_defend_skill == nil then
        self.arena_defend_skill = {}
    else
        self.arena_defend_skill = table.copy(arena_info.arena_defend_skill)
    end
end

function imp_arena_dummy_arena.imp_arena_dummy_arena_write_to_dict(self,dict)

end

function imp_arena_dummy_arena.imp_arena_dummy_arena_write_to_sync_dict(self,dict)

end

function imp_arena_dummy_arena.get_defend_pet(self)
    return self.defend_pet
end

return imp_arena_dummy_arena



