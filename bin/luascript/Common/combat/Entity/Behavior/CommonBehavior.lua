---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/26
-- desc： 单位表现
---------------------------------------------------

require "Common/basic/LuaObject"

local CommonBehavior = ExtendClass()

function CommonBehavior:__ctor(owner)
	self.owner = owner
end

-- 展示动作
function CommonBehavior:UpdateBehavior(animation)
	end

function CommonBehavior:GetCurrentBehaviorLength()
	return 0
end

	-- 停止展示动作
function CommonBehavior:StopBehavior(animation)
end

	-- 移动到pos点
function CommonBehavior:Moveto(pos)
end

	-- 沿direction方向移动
function CommonBehavior:MoveDir(direction)
end

	-- 停止移动
function CommonBehavior:StopMove()
end

	-- 获取当前位置
function CommonBehavior:GetPosition()
end

function CommonBehavior:GetPartPosition(name)
	return self:GetPosition()
end

	-- 执行移动动作
function CommonBehavior:BehaveMove()
end

	-- 是否正在移动
function CommonBehavior:IsMoving()		
end

	-- 执行idle动作
function CommonBehavior:BehaveIdle()
end

	-- 执行死亡动作
function CommonBehavior:BebaveDie(callback)
end

	-- 添加特效
function CommonBehavior:AddEffect(resName, rootName, recyle, pos, angle, scale, detach, lossyScale)
end

	-- 移除特效
function CommonBehavior:RemoveEffect(res)
end

	-- 移除所有特效
function CommonBehavior:RemoveAllEffect()
end

	-- 销毁
function CommonBehavior:Destroy()        
end

    -- 执行受击动作
function CommonBehavior:BehaveBehit(damage, event_type)
end

function CommonBehavior:BehaveAddHp(num)
end

function CommonBehavior:BehaveAddMp(num)
end
	
	-- 朝向向pos点
function CommonBehavior:LookAt(pos)
	end

	-- 设置半径
function CommonBehavior:SetRadius(r)
end

	-- 设置速度
function CommonBehavior:SetSpeed(s)
end
	
	-- 设置停止距离
function CommonBehavior:SetStoppingDistance(sd)	
end
	
	-- 获取停止距离
function CommonBehavior:GetStoppingDistance()	
end
    
    -- 设置位置
function CommonBehavior:SetPosition(pos)
end

	-- 获取转角　返回一个Quaternion值
function CommonBehavior:GetRotation()		
end

	-- 设置转向
function CommonBehavior:SetRotation(rotation)
end

	-- 瞬移
function CommonBehavior:SpurtTo(dir, speed, btime, time, atime, visible, bspeed, aspeed, stopFrame)	
end

function CommonBehavior:SetDefaultAnimation(anim)
end

function CommonBehavior:GetCurrentAnim()
    return nil
end

function CommonBehavior:CastEffect(effect_name)
end

function CommonBehavior:RevertEffect()
end

function CommonBehavior:SetModel(prefab, scale)
end

function CommonBehavior:GetModelId()
	return self.modelId
end

function CommonBehavior:GetModelScale()
	return self.modelScale
end

function CommonBehavior:SetCurrentAnimationSpeed(speed)
end

function CommonBehavior:SetAnimationSpeed(animation, speed)
end

function CommonBehavior:GetAnimationLength(animation)
    return 0
end    
    -- Default = 0,Once = 1,Clamp = 1,Loop = 2,PingPong = 4,ClampForever = 8
function CommonBehavior:GetAnimationWrapMode(animation)
    return -1
end
    
function CommonBehavior:IsAnimationLoop(animation)
    return false
end

function CommonBehavior:HasAnimation(animation)
    return false
end

function CommonBehavior:PlayShakeEvent( shakeRange,duration)

end

function CommonBehavior:PlayHitEffect(attacker, skill_id, is_bullet, damage, event_type)
end

function CommonBehavior:ToBeResurrect()

end

function CommonBehavior:createBar()

end

function CommonBehavior:ShowBar()
end

return CommonBehavior