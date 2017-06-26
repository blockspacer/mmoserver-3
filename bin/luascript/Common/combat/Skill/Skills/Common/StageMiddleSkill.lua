---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/21
-- desc： Skill Test
---------------------------------------------------
require "Common/basic/functions"

local Skill = require "Common/combat/Skill/Skill"
local SkillStageMiddleSkill = ExtendClass(Skill)

function SkillStageMiddleSkill:__ctor(scene, skill_id, data)
    self.first_skill_id = nil
    self.next_skill_id = nil
    self.timer = nil
end

function SkillStageMiddleSkill:TryOnCastStart(data)
    Skill.TryOnCastStart(self, data)
    if self.timer then
        self:GetTimer().Remove(self.timer)
        self.timer = nil
    end
end

    -- skill施法结束
function SkillStageMiddleSkill:TryOnCastFinish(data)
    Skill.TryOnCastFinish(self, data)
    if self.next_skill_id then
        if self.owner and self.owner.skillManager then
            self.owner.skillManager:AddSkill(self.slot_id, self.next_skill_id, self.level, true)
        end
    end
end

-- skill被添加到单位上时
function SkillStageMiddleSkill:OnAdd()
    Skill.OnAdd(self)
    if self.first_skill_id then
        self.timer = self:GetTimer().Delay(self.cd, self.ReturnToFirstSkill, self)
    end
end

function SkillStageMiddleSkill:OnCDReady()
    Skill.OnCDReady(self)
    --[[if self.next_skill_id then
        self.owner.skillManager:AddSkill(self.slot_id, self.next_skill_id, 1)
    end]]
end

function SkillStageMiddleSkill:ReturnToFirstSkill()
    if self.owner and self.owner.skillManager then
        self.owner.skillManager:AddSkill(self.slot_id, self.first_skill_id, self.level, true)
    end
end

return SkillStageMiddleSkill
