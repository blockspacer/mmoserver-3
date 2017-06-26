---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： Skill Test
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

function CreateSkillStageSkill(skill_name, data)
	local self = CreateSkill(skill_name, data)
    local base = self.base();
    -- 技能阶段，主要是普攻
    self.skill_stage_max = 2
    self.skill_stage = 1
    self.skill_stage_refresh_time = 0.3
    self.skill_stage_refresh_timer = nil
    self.skill_list = '101:102:103'

    self.OnCastStart = function(data)
        base.OnCastStart(data)
        self.EnterStage()
        self.OnCastStartAtStage(data) 
        --print("SkillTest:OnCastStart")
    end

    self.OnCastStartAtStage = function(data)

    end

    -- skill被添加到单位上时
    self.OnAdd = function()
        -- TODO 将skill_list里的技能全部取出来, 并修改self.skill_stage_max
        for skill_id in string.gmatch(self.skill_list, "%d+") do
        end
    end

    self.OnEnterCD = function()
        -- TODO 等于当前技能的cd
        self.cd_left = self.cd
    end

    self.OnCDReady = function()
        base.OnCDReady()
        self.PromptStage()
    end

    self.RefreshStage = function()
        self.skill_stage = 1
        --print('cur_stage = ', self.skill_stage)
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
        --print('cur_stage = ', self.skill_stage)
    end
	
    return self
end