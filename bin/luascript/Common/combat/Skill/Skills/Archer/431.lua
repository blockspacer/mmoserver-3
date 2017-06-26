---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test

--[[
【陷阱】向前方扇形区域一次性安置3个藤蔓陷阱，
会对触发的敌人造成【参数1百分比】的物理伤害，并使束缚他们无法移动持续3s
]]          

---------------------------------------------------
--[[local Vector3 = Vector3

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"
require "Logic/Common/TriggersManager"

local skill_type = '431'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    local function OnCaughtMonster(target)
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect)
        target.skillManager:AddBuffFromSkill(tostring(skill_data.Buff1), self)
    end

    local function createTrigger(pos)
        SkillAPI.CreateTrigger(TriggerType.Monster, pos, self:GetPara(2), OnCaughtMonster)
    end

    local forward = (self.owner:GetPosition() + (self.owner:GetRotation() * Vector3.forward) * self.area_radius);

    local r0 = Quaternion.Euler(
            self.owner:GetRotation().eulerAngles.x,
            self.owner:GetRotation().eulerAngles.y - self.area_angle/2, 
            self.owner:GetRotation().eulerAngles.z);
    local r1 = Quaternion.Euler(
            self.owner:GetRotation().eulerAngles.x,
            self.owner:GetRotation().eulerAngles.y + self.area_angle/2,
            self.owner:GetRotation().eulerAngles.z);
 
    local left_end =  (self.owner:GetPosition()  + (r0 * Vector3.forward) * self.area_radius);
    local right_end =  (self.owner:GetPosition()  + (r1 * Vector3.forward) * self.area_radius);

    createTrigger(forward)
    createTrigger(left_end)
    createTrigger(right_end)

end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(3) / 10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal]]