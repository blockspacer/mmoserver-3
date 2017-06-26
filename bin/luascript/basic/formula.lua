--------------------------------------------------------------------
-- 文件名:	formula.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2016/09/28
-- 描  述:	全局的公式
--------------------------------------------------------------------

local NV_MAGICCONST = 1.71552776992
local math_random = math.random
local math_log = math.log

function Gauss(mu, sigma)
    --[[Normal distribution.

    mu is the mean, and sigma is the standard deviation.

    --]]
    -- mu = mean, sigma = standard deviation

    -- Uses Kinderman and Monahan method. Reference: Kinderman,
    -- A.J. and Monahan, J.F., "Computer generation of random
    -- variables using the ratio of uniform deviates", ACM Trans
    -- Math Software, 3, (1977), pp257-260.
    local z

    for i = 1, 10 do
        local u1 = math_random()
        local u2 = 1.0 - math_random()
        z = NV_MAGICCONST*(u1-0.5)/u2
        local zz = z*z/4.0
        if zz <= -math_log(u2) then
            break
        end
    end

    if z ~= nil then
        return mu + z*sigma
    else
        return mu
    end
end