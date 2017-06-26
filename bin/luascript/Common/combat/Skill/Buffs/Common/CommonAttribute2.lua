---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 改变属性：A属性转化为B属性	

--"【固定参数】=A|B（A转化为B）
--【参数1万分比】%的A属性转化为B，转化系数为【参数2万分比】"			

---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME
local Buff = require "Common/combat/Skill/Buff"

local BuffCommonAttribute = ExtendClass(Buff)

function BuffCommonAttribute:__ctor(scene, buff_id, data)
    if not GRunOnClient then
    		self[attrib_id_to_name[self.buff_data.FixedPara[2]]] = 
    			self.owner[attrib_id_to_name[self.buff_data.FixedPara[1]]]() * ( self:GetPara(1) / 10000) * ( self:GetPara(2) / 10000)
    		self[attrib_id_to_name[self.buff_data.FixedPara[1]]] = 
    		 	- self.owner[attrib_id_to_name[self.buff_data.FixedPara[1]]]() * ( self:GetPara(1) / 10000)
    end
end

return BuffCommonAttribute

