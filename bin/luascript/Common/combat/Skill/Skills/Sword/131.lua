---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
-- 以极快的身法向面朝方向冲刺10米距离（CD7s），并且每次使用都有20%几率刷新【4槽1】的技能
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '131'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)
    
    local function RefreshCD()
        -- 刷新141技能
        self.owner.skillManager:RefreshBySkillID(tostring(self:GetPara(3)))
    end

    SkillAPI.RandEvent(self:GetPara(2) / 10000, RefreshCD)
end

SkillLib[skill_type] = SkillLocal

return SkillLocal