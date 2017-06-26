--------------------------------------------------------------------
-- 文件名:	imp_interface
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/2/3 0003
-- 描  述:	接口组件，存放一般接口
--------------------------------------------------------------------
local online_user = require "onlinerole"
local const = require "Common/constant"
local flog = require "basic/log"

local imp_interface = {}
imp_interface.__index = imp_interface

setmetatable(imp_interface, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
imp_interface.__params = params

function imp_interface.__ctor(self)

end

function imp_interface.entity_die(self,killer_id)

end

function imp_interface.is_attackable(self, enemy_id)
    return true
end

function imp_interface.on_attack_entity(self, enemy_id, damage)
    local scene = self:get_scene()
    if scene == nil then
        return
    end
    local enemy = scene:get_entity(enemy_id)
    if enemy == nil then
        return
    end
    if enemy.team_member_fight_data_statistics ~= nil then
        enemy:team_member_fight_data_statistics("inhury", damage)
    end
end

function imp_interface.on_be_attacked(self, enemy_id, damage)
    if self.team_member_fight_data_statistics ~= nil then
        self:team_member_fight_data_statistics("inhury", damage)
    end
end

function imp_interface.on_treat_entity(self, entity_id, treat)
    if self.team_member_fight_data_statistics ~= nil then
        self:team_member_fight_data_statistics("treat", treat)
    end
end

return imp_interface