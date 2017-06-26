---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 治愈之光


-- 收集大量的木元素，能快速给主人回复【1：属性ID】*【2 百分比】的血量。
                                        

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
local constant = require "Common/constant"
local attrib_id_to_name = constant.PROPERTY_INDEX_TO_NAME

local skill_type = '10031'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    if self.owner.owner then
        SkillAPI.AddHp(
            self.owner.owner, 
            self.owner[attrib_id_to_name[self:GetPara(1)]]() * self:GetPara(2) / 10000, 
            self.owner, 
            self.skill_id)
    end
end

SkillLib[skill_type] = SkillLocal

return SkillLocal