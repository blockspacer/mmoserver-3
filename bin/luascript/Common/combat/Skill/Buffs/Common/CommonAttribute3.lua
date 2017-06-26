---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 改变属性：按施法者

--提升/降低【固定参数】属性，每【参数1】秒增加/降低【参数2百分比】，降低用负数			
	
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME
local Buff = require "Common/combat/Skill/Buff"

local BuffCommonAttribute = ExtendClass(Buff)

function BuffCommonAttribute:__ctor(scene, buff_id, data)
	self.pulse_interval = self:GetPara(1)

    if not GRunOnClient then
		for k,base_prop_id in pairs(self.buff_data.FixedPara) do
	        self[attrib_id_to_name[base_prop_id]..'Percent'] =  1 + self:GetParaInTable(2, k) / 10000
	    end
	    self.pluse_times = 1
    end
end

-- buff起作用
function BuffCommonAttribute:OnPulse()
    Buff.OnPulse(self)

    if not GRunOnClient then
    	self.pluse_times = self.pluse_times + 1
		for k,base_prop_id in pairs(self.buff_data.FixedPara) do
	        self[attrib_id_to_name[base_prop_id]..'Percent'] =  1 + self:GetParaInTable(2, k) * self.pluse_times / 10000
	    end
	   	self.owner:NeedCalcProperty()
    end
end

return BuffCommonAttribute

