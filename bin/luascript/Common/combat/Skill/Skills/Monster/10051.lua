---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/3
-- desc： 
--[[
与主人合体，给主人增加【buffID1】的buff。
（增加主人，宠物【参数2百分比】的法术攻击，持续10秒。）
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"


local skill_type = '10051'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
    self.bullet_hit_master = true
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    -- TODO CD得从服务器同步下来
    self:RefreshCD()
    self.owner:GetTimer().Delay(0.5, 
    	function() 
    		self.owner:LeaveAOIScene()
    	end)

end

function SkillLocal:OnBulletHit(target)
	local buff = self.owner.owner.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)


    self.owner:GetTimer().Delay(buff.last_time, 
    	function() 
    		if not self.owner.owner or self.owner.owner:IsDied() or self.owner.owner:IsDestroy() then
    		else
    			self.owner:EnterAOIScene(self.owner.owner:GetPosition())
    		end
    	end)

end

SkillLib[skill_type] = SkillLocal

return SkillLocal