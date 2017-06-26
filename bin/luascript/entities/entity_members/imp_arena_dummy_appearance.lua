--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/3/21 0021
-- Time: 9:48
-- To change this template use File | Settings | File Templates.
--
local const = require "Common/constant"
local flog = require "basic/log"

local params = {
}

local imp_arena_dummy_appearance = {}
imp_arena_dummy_appearance.__index = imp_arena_dummy_appearance

setmetatable(imp_arena_dummy_appearance, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_arena_dummy_appearance.__params = params

function imp_arena_dummy_appearance.__ctor(self)
    self.appearance = {}
end

function imp_arena_dummy_appearance.imp_arena_dummy_appearance_init_from_dict(self, dict)
    self.appearance = table.get(dict, "appearance", {})
end

function imp_arena_dummy_appearance.imp_arena_dummy_appearance_write_to_dict(self, dict)

end

function imp_arena_dummy_appearance.imp_arena_dummy_appearance_write_to_sync_dict(self, dict)

end

return imp_arena_dummy_appearance

