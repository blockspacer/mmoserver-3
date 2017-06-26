---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/26
-- desc： 三尾狐 10007 技能
--[[
狐媚之环    控制技能                            
a   妖狐抖动自己的身体和尾巴，进入吟唱蓄力状态。吟唱蓄力状态持续3秒。                           
b   以妖狐为中心，发出一道光环向外扩散。扩散后的最大半径为10米，扩散时间为3秒。                         
c   被光环击中的玩家，会处于封技状态，技能无法使用。持续5秒。                           
d   被光环击中的宠物，会处于混乱状态，攻击身边的友方玩家或者宠物。持续5秒。                            
e   技能冷却时间为20秒。                         
f   技能释放条件:妖狐血量低于50%。                                                                                     
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/basic/Timer"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10007'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE

    self.pass_time = 0
    self.interval = 1
end

-- skill开始施法
function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)
end

-- skill施法中
function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)
    self:GetTimer().Numberal(self.interval, self:GetPara(1) / 1000 / self.interval, self.rangeAttack, self)   
end

function SkillLocal:rangeAttack()
    self.pass_time = self.pass_time + self.interval
    -- 给英雄添加buff1
    local units = SkillAPI.EnumUnitsRandom(
        self.owner, 
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self.area_radius * self.pass_time / (self:GetPara(1) / 1000),
        }, 
        EntityType.Hero, 1000)

    for _, unit in pairs(units) do
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end
    -- 给宠物添加buff2
    local units = SkillAPI.EnumUnitsRandom(
        self.owner, 
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self.area_radius * self.pass_time / (self:GetPara(1) / 1000),
        }, 
        EntityType.Pet, 1000)

    for _, unit in pairs(units) do
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff2), self)
    end
end

SkillLib[skill_type] = SkillLocal

return SkillLocal