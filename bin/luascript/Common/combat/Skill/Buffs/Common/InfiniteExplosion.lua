---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 

--持续时间过后，会对自身周围造成【参数1百分比】物理伤害，并附加【固定参数】buff
		
	
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME
local Buff = require "Common/combat/Skill/Buff"

local InfiniteExplosion = ExtendClass(Buff)

function InfiniteExplosion:__ctor(scene, buff_id, data)

end

function InfiniteExplosion:OnRemove()
    Buff.OnRemove(self)
    
    local units = SkillAPI.EnumUnitsInCircle(
        self.data.source,
        self.owner:GetPosition(), 
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self:GetPara(2),
        }, 
        nil, true)

    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.data.source, self, self.OnDamageCorrect, self)
        unit.skillManager:AddBuff(tostring(self.buff_data.FixedPara[1]), {source = self.data.source})
    end
end

function InfiniteExplosion:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent;
end

return InfiniteExplosion

