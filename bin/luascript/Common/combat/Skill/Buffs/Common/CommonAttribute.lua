---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 改变属性：百分比+固定	

--自身【固定属性】提高比例【参数1】，再额外附加提高固定【参数2】，多项分开时一一对应。负数表示降低	
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME
local Buff = require "Common/combat/Skill/Buff"

local BuffCommonAttribute = ExtendClass(Buff)

function BuffCommonAttribute:__ctor(scene, buff_id, data)
	self.work_independent = true
	if not GRunOnClient then
		for k,base_prop_id in pairs(self.buff_data.FixedPara) do
	        self[attrib_id_to_name[base_prop_id]] = self:GetParaInTable(2, k) / 10000
	        self[attrib_id_to_name[base_prop_id]..'Percent'] =  1 + self:GetParaInTable(1, k) / 10000
	    end
	end
end

return BuffCommonAttribute

