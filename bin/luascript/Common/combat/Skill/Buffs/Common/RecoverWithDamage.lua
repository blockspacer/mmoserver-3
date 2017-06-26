---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 回光：吸收伤害，并回血
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffRecoverWithDamage = ExtendClass(Buff)

function BuffRecoverWithDamage:__ctor(scene, buff_id, data)
	self.work_independent = true
end

-- 处理特殊伤害统一使用这个函数
function BuffRecoverWithDamage:ChangeTakeDamage(damage)
    SkillAPI.AddHp(self.owner, damage, self.owner)
    return 0
end

return BuffRecoverWithDamage
