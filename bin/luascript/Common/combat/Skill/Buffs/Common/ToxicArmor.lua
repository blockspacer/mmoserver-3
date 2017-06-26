---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/27
-- desc： 剧毒之甲
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffToxicArmor = ExtendClass(Buff)

function BuffToxicArmor:__ctor(scene, buff_id, data)

end

function BuffToxicArmor:OnTakeDamage(damage, attacker, spell_name, event_type)
	attacker.skillManager:AddBuff(tostring(self.buff_data.FixedPara[1]), {source = self.owner})
end

return BuffToxicArmor
