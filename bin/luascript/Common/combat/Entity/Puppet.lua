---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/26
-- desc： 基类
---------------------------------------------------



local CommonPuppet = require "Common/combat/Entity/CommonPuppet"
local Puppet = ExtendClass(CommonPuppet)

function Puppet:__ctor(scene, data, event_delegate)

end

-- 创建自带buff
function Puppet:CreateDefaultBuffs(buffs)
	if GRunOnClient then
		return 
	end 
	if buffs then
		for _, buff_id in pairs(buffs) do
			self.skillManager:AddBuff(tostring(buff_id))
		end
	end
end

return Puppet
