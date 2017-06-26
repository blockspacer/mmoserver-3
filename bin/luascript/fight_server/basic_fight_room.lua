--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/6/12 0012
-- Time: 14:48
-- To change this template use File | Settings | File Templates.
--

local basic_fight_room = {}
basic_fight_room.__index = basic_fight_room

setmetatable(basic_fight_room, {
  __call = function (cls, ...)
    local self = setmetatable({}, cls)
    self:__ctor(...)
    return self
  end,
})

function basic_fight_room.__ctor(self)
    self.members = {}
end

function basic_fight_room.add_member(self,actor_id)
    self.members[actor_id] = 1
end

function basic_fight_room.remove_member(self,actor_id)
    self.members[actor_id] = nil
end

function basic_fight_room.check_member(self,actor_id)
    return self.members[actor_id] ~= nil
end

return basic_fight_room

