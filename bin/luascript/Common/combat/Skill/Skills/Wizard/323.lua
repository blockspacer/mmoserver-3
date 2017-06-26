---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/6/15
-- desc： 323 技能

--[[
向目标区域释放一片由蛊虫形成的迷雾，迷雾会在[Para3]秒内缓缓形成，
形成后的迷雾会对区域内的敌人每秒造成[Para1/100]%的法术伤害以及[math.floor(Para3/10000)]点额外伤害，
并使区域内敌人减速[buff2:Para1/100]%，使迷雾中心的敌人锁足[buff1:time]秒，，迷雾持续存在6s
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '323'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
end

function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)
    local target = data.target
    local position

    local function rangeAttack()
    	local enemys = SkillAPI.EnumUnitsInCircle(
	        self.owner,
	        position, 
	        {
	            area_type = EnumUnitsAreaType.Circle,
	            radius = self.area_radius,
	        }, 
	        nil, true)

        for _, unit in pairs(enemys) do
            SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)

            if Vector3.InDistance(position, unit:GetPosition(), self:GetPara(4)) then
            	unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
            else
            	unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
            end
        end

    end

    local function MakeMist()
    	self:GetTimer().Numberal(1, 6, rangeAttack)   
    end

    if target then
    	position = target:GetPosition()
    	self:GetTimer().Delay(self:GetPara(3), MakeMist)
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    return M4 * percent  + self:GetPara(2) / 10000
end

SkillLib[skill_type] = SkillLocal

return SkillLocal