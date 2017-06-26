---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/06
-- desc： 无敌
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local Invincible = ExtendClass(Buff)

function Invincible:__ctor(scene, buff_id, data)
	self.work_independent = true
end

function Invincible:ChangeTakeDamage(damage)
    return 0
end

return Invincible
