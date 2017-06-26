--
-- Created by IntelliJ IDEA.
-- User: 吴培峰
-- Date: 2016/12/26 0022
-- Time: 15:29
-- To change this template use File | Settings | File Templates.
--
--[[
              

]]

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '20015'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

-- skill施法中
function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal