---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/1
-- desc： 单位表现
---------------------------------------------------
local Vector3 = Vector3
local const = require "Common/constant"

local scene_func = require "scene/scene_func"
local flog = require "basic/log"

local CommonBehavior = require "Common/combat/Entity/Behavior/CommonBehavior"
local Behavior = ExtendClass(CommonBehavior)

function Behavior:__ctor(owner)
    self.behavior = {}
end

-- 展示动作
function Behavior:UpdateBehavior(animation)
    self.behavior.currentAnim = animation
end

-- 停止展示动作
function Behavior:StopBehavior(animation)
    
end

function Behavior:Moveto(pos)
    if self.owner.aoi_proxy == nil then
        return false
    end
    local ret = scene_func.move_to(self.owner.aoi_proxy, pos.x, pos.y, pos.z)
    if not ret then
        local src = self:GetPosition()
        flog("info", "move failed! uid=" .. self.owner.data.entity_id .. " from:(" .. src.x .. "," .. src.y .. "," .. src.z .. ") to:(" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ")")
    end
    return ret
end

function Behavior:MoveToDirectly(pos)
    if self.owner.aoi_proxy == nil then
        return false
    end
    local ret = scene_func.move_to_directly(self.owner.aoi_proxy, pos.x, pos.y, pos.z)
    if not ret then
        local src = self:GetPosition()
        flog("info", "move_to_directly failed! uid=" .. self.owner.data.entity_id .. " from:(" .. src.x .. "," .. src.y .. "," .. src.z .. ") to:(" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ")")
    end
    return ret
end

function Behavior:MoveDir(direction)
    -- 
end

function Behavior:SetSpeed(s)
    if self.owner.aoi_proxy == nil then
        return
    end
    scene_func.set_speed(self.owner.aoi_proxy, s)
end

-- 停止移动
function Behavior:StopMove()
    if self.owner.aoi_proxy == nil then
        return
    end
    scene_func.stop_move(self.owner.aoi_proxy)
end

function Behavior:IsMoving()
    if self.owner.aoi_proxy == nil then
        return
    end
    return scene_func.is_moving(self.owner.aoi_proxy)
end

function Behavior:SetSyncPosition(b)
    if self.behavior then
        self.behavior.SyncPosition = b
    end
end

function Behavior:SetSync(b)
    if self.behavior then
        self.behavior.IsSync = b
    end
end
function Behavior:GetSync()
    if self.behavior then
        return self.behavior.IsSync
    end
end

function Behavior:GetPosition()
    local x,y,z 
    if self.owner.aoi_proxy == nil then
        x,y,z = self.owner.data.posZ,self.owner.data.posY,self.owner.data.posZ
        return Vector3.New(x, y, z)
    end
    x,y,z = scene_func.get_pos(self.owner.aoi_proxy)

    return Vector3.New(x, y, z)
end

-- 执行受击动作
function Behavior:BehaveBehit(damage, event_type)

end

function Behavior:BebaveDie(callback)
    self.owner:GetTimer().Delay(self:GetCurrentBehaviorLength(), callback)
end

function Behavior:LookAt(pos)
    local self_pos = self:GetPosition()
    local forward = pos - self_pos
    local mag = forward:Magnitude()
    if mag < 1e-6 then
        return 
    end
    self:SetRotation(Quaternion.LookRotation(forward))
end

function Behavior:SetPosition(pos)

    if self.owner.aoi_proxy == nil then
        return
    end
    scene_func.set_position(self.owner.aoi_proxy, pos.x, pos.y, pos.z)
end

function Behavior:GetRotation()
    local ro
    if self.owner.aoi_proxy == nil then
        ro =  0
    end
    ro = scene_func.get_rotation(self.owner.aoi_proxy)

    return Quaternion.Euler(0, ro, 0)
end

function Behavior:SetRotation(rotation)
    if self.owner.aoi_proxy == nil then
        return
    end
    scene_func.set_rotation(self.owner.aoi_proxy, rotation.eulerAngles.y)
end

function Behavior:SetDefaultAnimation(anim)
end

function Behavior:GetCurrentAnim()
    if self.behavior then
        return self.behavior.currentAnim
    end
    return nil
end

function Behavior:SpurtTo(dir, speed, btime, time, atime, visible, bspeed, aspeed, stopFrame) 
    self.owner:GetTimer().Delay(btime + time + atime,
        function()
            local distance = btime*bspeed + time * speed + atime * aspeed
            local pos = self:GetPosition() + dir * distance
            self:SetPosition(pos)
        end)
end

-- 销毁
function Behavior:Destroy()   

end

function Behavior:SetNavMesh(b)
end

return Behavior
