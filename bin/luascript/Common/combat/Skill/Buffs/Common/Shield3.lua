---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： 护盾：固定值
-- 增加【参数1】点护盾

---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"
local BuffShield = require "Common/combat/Skill/Buffs/Common/Shield"

local BuffShield3 = ExtendClass(BuffShield)


function BuffShield3:__ctor(scene, buff_id, data)

end


function BuffShield3:rechargeShield(data)
    self.shield = self:GetPara(1) / 10000
end

return BuffShield3
