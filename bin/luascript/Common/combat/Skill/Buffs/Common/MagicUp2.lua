---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 提升目标，释放者【参数1百分比】法术攻击力
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local BuffMagicUp2 = ExtendClass(Buff)

function BuffMagicUp2:__ctor(scene, buff_id, data)
	if not GRunOnClient then
		if self.data.source then
		    self.magic_attack = 
		        self.data.source.magic_attack()
		        * 
		        self:GetPara(1)/10000
		end
	end
end

function BuffMagicUp2:OnTick(interval)
    Buff.OnTick(self, interval)

end

-- buff被添加到单位上时
function BuffMagicUp2:OnAdd()
    Buff.OnAdd(self)
    self.owner:AddStatus('MagicUp', self)
end

-- buff被删除的时候
function BuffMagicUp2:OnRemove()
    Buff.OnRemove(self)
    self.owner:RemoveStatus('MagicUp', self)
end

return BuffMagicUp2

