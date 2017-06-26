---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/27
-- desc： 剧毒之甲buff
-- 每秒损失【参数1百分比】的当前血量

---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffToxicArmorBuff = ExtendClass(Buff)

function BuffToxicArmorBuff:__ctor(scene, buff_id, data)
	self.pulse_interval = 1
end

-- buff起作用
function BuffToxicArmorBuff:OnPulse()
    Buff.OnPulse(self)
    -- 每秒损失多少血量
    SkillAPI.MinusHp(
        self.owner, 
        self.owner.hp * self:GetPara(1) / 10000, 
        self.data.source)
end

return BuffToxicArmorBuff
