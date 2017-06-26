---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_name = 'Test'

function CreateSkillTest(data)
	local self = CreateSkill(skill_name, data)
    local base = self.base();
    -- 施法距离
    self.cast_distance = 1
    self.cd = 1.6
    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
    -- 技能阶段，主要是普攻
    self.skill_stage_max = 2
    self.skill_stage = 1
    self.skill_stage_refresh_time = 0.5
    self.skill_stage_refresh_timer = nil

    self.OnCastStart = function(data)
        base.OnCastStart(data)
        self.EnterStage()
        self.OnCastStartAtStage(data) 
        --print("SkillTest:OnCastStart")
    end

    self.OnCastStartAtStage = function(data)
        print('OnCastStartAtStage', self.skill_stage)
        local target = data.target
        if target then
            SkillAPI.TakeDamage(target, self.owner, self)
        end
    end

    self.OnCastChannel = function(data)
        base.OnCastChannel(data)
        --print("SkillTest:OnCastChannel")
    end

    self.OnCastFinish = function(data)
        base.OnCastFinish(data)
        --print("SkillTest:OnCastFinish")
    end

    self.OnCDReady = function()
        base.OnCDReady()
        self.PromptStage()
    end

    self.RefreshStage = function()
        self.skill_stage = 1
        print('cur_stage = ', self.skill_stage)
        self:GetTimer().Remove(self.skill_stage_refresh_timer)
        self.skill_stage_refresh_timer = nil
    end

    self.EnterStage = function()
        self:GetTimer().Remove(self.skill_stage_refresh_timer)
        self.skill_stage_refresh_timer = nil
    end

    self.PromptStage = function()
        self.skill_stage = self.skill_stage + 1
        if self.skill_stage > self.skill_stage_max then
            self.RefreshStage()
        else
            self.skill_stage_refresh_timer = self:GetTimer().Delay(self.skill_stage_refresh_time, self.RefreshStage)
        end
        print('cur_stage = ', self.skill_stage)

    end
	
    return self
end

SkillLib[skill_name] = CreateSkillTest