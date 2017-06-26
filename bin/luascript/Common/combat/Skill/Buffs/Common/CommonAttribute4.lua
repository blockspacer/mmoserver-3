---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 改变属性：按施法者

--提升/降低目标   施法者【A属性】*【参数1】   的【B属性】	
---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME
local Buff = require "Common/combat/Skill/Buff"

local BuffCommonAttribute = ExtendClass(Buff)

function BuffCommonAttribute:__ctor(scene, buff_id, data)
    if not GRunOnClient then
    	if self.data.source then
    		self[attrib_id_to_name[self.buff_data.FixedPara[2]]] = 
    			self.data.source[attrib_id_to_name[self.buff_data.FixedPara[1]]]() * ( self:GetPara(1) / 10000)
    	end
    end
end

return BuffCommonAttribute

