---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
---------------------------------------------------

require "Common/combat/Skill/Skills/Common/StageSkill"


local skill_name = 'Monster/CommonAttack'

function CreateSkillMonster_CommonAttack(data)
	local self = CreateSkillStageSkill(skill_name, data)
    local base = self.base();
    -- 施法距离
    self.cast_distance = 1
    self.cd = 1.6
    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
    -- 技能阶段，主要是普攻
    self.skill_stage_max = 1

    self.OnCastStartAtStage = function(data)
        base.OnCastStartAtStage(data)
        --print('OnCastStartAtStage', self.skill_stage)
        local target = data.target
        if target then
            SkillAPI.TakeDamage(target, self.owner, self)
        end
    end
	
    return self
end

SkillLib[skill_name] = CreateSkillMonster_CommonAttack