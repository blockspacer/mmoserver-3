---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/2
-- desc： 同步管理器
---------------------------------------------------
local Vector3 = Vector3

require "Common/basic/LuaObject"
require "Common/SyncManager"
local CreateEntityManager = require "Common/combat/Entity/EntityManager"
local CreateTriggersManager = require "Common/combat/Trigger/TriggersManager"
local CreateTimer = require "Common/basic/Timer"

local CombatScene = ExtendClass()

function CombatScene:__ctor(scene_id)
    self.scene_id = scene_id
    self.entity_manager = CreateEntityManager(self)

    self.triggers_manager = CreateTriggersManager(self)
    self.timer = CreateTimer()
    -- 大的场景数据表
    self.scheme = nil
    self.scene_setting_name = nil
end

-- 每次重新载入得清理一遍
function CombatScene:Clear()
    self.timer.RemoveAll()
    self.entity_manager.DestroyAll()
    self.triggers_manager:Release()
    self.scheme = nil
end

function CombatScene:GetEntityManager()
    return self.entity_manager
end

function CombatScene:GetTriggersManager()
    return self.triggers_manager
end

function CombatScene:GetTimer()
    return self.timer
end

function CombatScene:SetScheme(scheme, scene_setting_name)
    self.scheme = scheme
    self.scene_setting_name = scene_setting_name
end

function CombatScene:GetScheme()
    return self.scheme
end

function CombatScene:GetNearestPolyOfPoint(pos)
    if GRunOnClient then
        return pos, true
    else
        local res, x, y, z = _get_nearest_poly_of_point(self.scene_id, pos.x, pos.y, pos.z)
        return Vector3.New(x, y, z), res
    end
end

return CombatScene
