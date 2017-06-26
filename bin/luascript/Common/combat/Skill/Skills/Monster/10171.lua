---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 媚狐之吻

-- 使用自己的天性能及其容易魅惑对手，【1万分比】的概率使对方中【buffID1】。
-- 如果对方没有中buff则受到最大生命值【2万分比】伤害。
                                        

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10171'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)

    local target = data.target
    if target then
        local luck = math.random(1, 100)
        if luck <= self:GetPara(1) then
            target.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
        else
            SkillAPI.MinusHp(
                target, 
                target.hp_max() * self:GetPara(2) / 100, 
                self.owner, 
                self.skill_id)
        end
    end

end

SkillLib[skill_type] = SkillLocal

return SkillLocal