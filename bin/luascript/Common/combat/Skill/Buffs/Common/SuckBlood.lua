---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 吸血：计算数值
 
-- 回复将自身输出伤害的比例【参数1】的血量	
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local SuckBlood = ExtendClass(Buff)

function SuckBlood:__ctor(scene, buff_id, data)
	self.work_independent = true
end


function SuckBlood:OnCauseDamage(damage, victim, skill_id, event_type)

    SkillAPI.AddHp(self.owner, damage * self:GetPara(1) / 10000, self.owner)
end
return SuckBlood
