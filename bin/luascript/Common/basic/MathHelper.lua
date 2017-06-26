---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/20
-- desc： MathHelper 数学库
---------------------------------------------------
local Vector3 = Vector3

MathHelper = {}
local MathHelper = MathHelper

-- 两个向量相乘
function MathHelper.MultiplyByPoints(p1x , p1y, p2x, p2y, p0x, p0y)
    return ((p1x - p0x) * (p2y - p0y) - (p2x - p0x) * (p1y - p0y));
end

function MathHelper.MultiplyVector(v1x, v1y, v2x, v2y)
    return v1x * v2y - v2x * v1y
end

function MathHelper.GetVector2D(pos1, pos2)
    return pos1.x - pos2.x, pos1.z - pos2.z
end

function MathHelper.GetForward(unit, distance)
    return (unit:GetPosition() + (unit:GetRotation() * Vector3.forward) * distance);
end

function MathHelper.GetForwardVector(unit, vector)
    return (unit:GetPosition()  + (unit:GetRotation() * vector));
end
 
-- 是否在矩形内
function MathHelper.IsINRect( point, v0, v1, v2, v3)
    local x = point.x;
    local y = point.z;

    local v0x = v0.x;
    local v0y = v0.z;

    local v1x = v1.x;
    local v1y = v1.z;

    local v2x = v2.x;
    local v2y = v2.z;

    local v3x = v3.x;
    local v3y = v3.z;

    if (MathHelper.MultiplyByPoints(x,y, v0x,v0y, v1x,v1y) * MathHelper.MultiplyByPoints(x,y, v3x,v3y, v2x,v2y) <= 0 and
     MathHelper.MultiplyByPoints(x,y, v3x,v3y, v0x,v0y) * MathHelper.MultiplyByPoints(x,y, v2x,v2y, v1x,v1y) <= 0) then
         return true;
    else
        return false;
    end
end

-- 在unit面前的矩形内
function MathHelper.IsInForwardRect(unit, location, width, height)
    local r = unit:GetRotation();
    local left =  (unit:GetPosition()  + (r * Vector3.left) * width/2);
    local right =  (unit:GetPosition()  + (r * Vector3.right) * width/2);
    local leftEnd = (left  + (r * Vector3.forward) * height);
    local rightEnd = (right  + (r *Vector3.forward) * height);
    local point = location;

    if MathHelper.IsINRect(point,leftEnd,rightEnd,right,left) then
        return true
    else
        return false
    end
end

function MathHelper.IsInRotationRect(rect_pos, rect_rot, location, width, height)
    local r = rect_rot;
    local left =  (rect_pos  + (r * Vector3.left) * width/2);
    local right =  (rect_pos  + (r * Vector3.right) * width/2);
    local leftEnd = (left  + (r * Vector3.forward) * height);
    local rightEnd = (right  + (r *Vector3.forward) * height);
    local point = location;

    if MathHelper.IsINRect(point,leftEnd,rightEnd,right,left) then
        return true
    else
        return false
    end
end

-- 是否在 矩形内
function MathHelper.IsInMiddleRect(rect_middle_pos, rect_rotation, rect_shape, target_location)
    local unit = {}
    local width = rect_shape.x
    local height = rect_shape.z
    unit.GetPosition = function()
        return (rect_middle_pos  + (rect_rotation * Vector3.back) * height/2);
    end
    unit.GetRotation = function()
        return rect_rotation
    end
    return MathHelper.IsInForwardRect(unit, target_location, width, height)
end

-- 在圆内
function MathHelper.IsInCircle(positionA, postionB, radius)
    if Vector3.InDistance(positionA, postionB, radius) then
        return true
    else
        return false
    end
end

-- 在某个unit面前某个角度范围内
function MathHelper.IsInFowardDirection(unit, location, angle)
    -- 左边和右边的 朝向
    local r0 = Quaternion.Euler(
            unit:GetRotation().eulerAngles.x,
            unit:GetRotation().eulerAngles.y - angle/2, 
            unit:GetRotation().eulerAngles.z);
    local r1 = Quaternion.Euler(
            unit:GetRotation().eulerAngles.x,
            unit:GetRotation().eulerAngles.y + angle/2,
            unit:GetRotation().eulerAngles.z);
 
    local left_end =  (unit:GetPosition()  + (r0 * Vector3.forward) * distance);
    local right_end =  (unit:GetPosition()  + (r1 * Vector3.forward) * distance);

    if  MathHelper.MultiplyVector(
            MathHelper.GetVector2D(location, unit:GetPosition()),
            MathHelper.GetVector2D(left_end, unit:GetPosition())) * 
        MathHelper.MultiplyVector(
            MathHelper.GetVector2D(location, unit:GetPosition()),
            MathHelper.GetVector2D(right_end, unit:GetPosition())) <= 0 then
        return true
    else
        return false
    end
end

function MathHelper.IsInForwardSector(unit, location, radius, angle)
    if not Vector3.InDistance(unit:GetPosition(), location, radius) then
        return false
    elseif MathHelper.IsInFowardDirection(unit, location, angle) then
        return true
    else
        return false
    end

end

return MathHelper





