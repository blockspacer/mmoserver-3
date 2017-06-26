---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 增加战斗经验

-- 增加战斗时获取经验增加【参数1百分比】
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffExpUp = ExtendClass(Buff)

function BuffExpUp:__ctor(scene, buff_id, data)
	self.work_independent = true
end

function BuffExpUp:ChangeBattleExp(exp)
	return exp * (1 + self:GetPara(1) / 10000)
end

return BuffExpUp

