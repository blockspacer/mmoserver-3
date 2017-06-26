---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/02/07
-- desc： 指定技能参数修正   

-- 修改指定【技能ID】的参数，修改的参数*原参数          

---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
local Buff = require "Common/combat/Skill/Buff"

local SkillParaChange = ExtendClass(Buff)

function SkillParaChange:__ctor(scene, buff_id, data)
	self.work_independent = true
end

function SkillParaChange:ChangeSkillPara(para, skill_id, index)
	if self.buff_data.FixedPara[1] ~= tonumber(skill_id) then
		return para
	end
	
    for k,v in pairs(self.buff_data['Para1']) do
        if v == index then
            return para * self.buff_data['Para2'][k] / 10000
        end
    end

end

return SkillParaChange
