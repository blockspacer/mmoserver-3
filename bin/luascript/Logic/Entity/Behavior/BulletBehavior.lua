---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/1
-- desc： 单位表现
---------------------------------------------------
local scene_func = require "scene/scene_func"

local ToyBehavior = require "Logic/Entity/Behavior/ToyBehavior"
local BulletBehavior = ExtendClass(ToyBehavior)

function BulletBehavior:__ctor(owner)
    self.posX = owner.data.posX
    self.posY = owner.data.posY
    self.posZ = owner.data.posZ
    self.move_speed = 0
    self.move_timer = nil
end

function BulletBehavior:SetSpeed(s)
    self.move_speed = s
end

-- 停止移动
function BulletBehavior:StopMove()
    self:stop_move_timer()
end

function BulletBehavior:SetPosition(pos)
    self.posX = x
    self.posY = y
    self.posZ = z
end

function BulletBehavior:Moveto(pos)
    self.targetPosX = pos.x
    self.targetPosY = pos.y
    self.targetPosZ = pos.z
    self:start_move_timer()
end

function BulletBehavior:MoveToDirectly(pos)
    self:Moveto(pos)
end

function BulletBehavior:GetPosition()
	return Vector3.New(self.posX, self.posY, self.posZ)
end

function BulletBehavior:destroy_move_timer()
    if self.move_timer ~= nil then
    	self.owner:GetTimer().Stop(self.move_timer)
        self.move_timer = nil
    end
end

function BulletBehavior:start_move_timer()
    if self.move_timer == nil then
        self.last_move_time = scene_func.get_now_time_mille()
        local function move_timer_handle()
            local diffrence = Vector3.New(self.targetPosX-self.posX,self.targetPosY - self.posY,self.targetPosZ-self.posZ)
            local distance = diffrence:Magnitude()
            local current_time = scene_func.get_now_time_mille()
            local delta_time = current_time - self.last_move_time
            local move_distance = (self.move_speed / 100) * delta_time / 1000
            if move_distance >= distance then
                self.posX = self.targetPosX
                self.posY = self.targetPosY
                self.posZ = self.targetPosZ
                self:destroy_move_timer()
            else
                diffrence = diffrence:Normalize()
                diffrence = diffrence*move_distance
                self.posX = self.posX + diffrence.x
                self.posY = self.posY + diffrence.y
                self.posZ = self.posZ + diffrence.z
            end
            if self.owner.approachDistance and self.owner.approachDistance + move_distance > distance then
                self.owner:StopApproachTarget()
                if self.owner.approachCallback then
                    self.owner.approachCallback(unpack(self.owner.approachArgs))
                end
            end
            self.last_move_time = current_time
        end
        self.move_timer = self.owner:GetTimer().Repeat(0.1, move_timer_handle)
    end
end

function BulletBehavior:stop_move_timer()
    self:destroy_move_timer()
end

return BulletBehavior
