---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/2/6
-- desc： 魔法燃烧

-- 消耗【1万分比】的当前血量，造成损失血量*【参数2万分比】的伤害，并可燃烧目标损失血量*【3万分比】的内力
                                        

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10191'

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
        local lost_hp = self.owner.hp * self:GetPara(1) / 10000
        SkillAPI.MinusHp(self.owner, lost_hp, self.owner)
        SkillAPI.ReduceMp(target, lost_hp * self:GetPara(3) / 10000, self.owner, self.skill_id)
        SkillAPI.MinusHp(target, lost_hp * self:GetPara(2) / 10000, self.owner)
    end

end

SkillLib[skill_type] = SkillLocal

return SkillLocal