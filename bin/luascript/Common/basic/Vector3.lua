


function Vector3.InDistance(va, vb, range)
    local dis_2 = (va.x - vb.x)^2 + (va.z - vb.z)^2 
    if dis_2 < range^2 then
        return true
    else
        return false
    end
end

function Vector3.Distance2D(va, vb)
    local dis = (va.x - vb.x)^2 + (va.z - vb.z)^2 
    return math.sqrt(dis)
end
