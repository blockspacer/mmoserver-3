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

local skill_type = '20029'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
end

-- skill施法中
function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)
end

function SkillLocal:OnBulletHit(target)
    Skill.OnBulletHit(self, target)

	local distance = Vector3.Distance2D(self.owner:GetPosition(), target:GetPosition())
	local rotation = Quaternion.LookRotation(target:GetPosition() - self.owner:GetPosition())

	local units = self.owner:AOIQueryPuppets(function(v) 
		-- if ..
		if not SkillAPI.IsAvailableTarget(self.owner, v, nil, true) then
			return false
		end

		if not MathHelper.IsInRotationRect(
			self.owner:GetPosition(), rotation, v:GetPosition(), 4, distance+2) then
			return false
		end

		return true
	end)
    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
    end

end


function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal