---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 13
--[[
召唤技能                           
                                                             
]]
---------------------------------------------------
local Vector3 = Vector3

require "Common/basic/functions"
require "Common/basic/Timer"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '13'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE

    self.avatars = {}
end

function SkillLocal:destroyAllAvatar()
    for k,v in pairs(self.avatars) do
        self:GetEntityManager().DestroyPuppet(v)
    end
    self.avatars = {}
end

-- skill开始施法
function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)
end

-- skill施法中
function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    if self.owner.summoned then
        for _,v in ipairs(self.owner.summoned) do

            local scheme = self:GetSceneSetting()

            if scheme[v] == nil then
                return 
            end
            local unit_data = table.copy(scheme[v])
            local pos = MathHelper.GetForwardVector(
                self.owner, 
                Vector3.New(unit_data.PosX, unit_data.PosY, unit_data.PosZ))
            unit_data.PosX = pos.x
            unit_data.PosY = pos.y
            unit_data.PosZ = pos.z
            local unit = self:GetEntityManager().CreateScenePuppet(unit_data, EntityType.Monster)
            unit.owner = self.owner
            table.insert(self.avatars, unit.uid)

        end
    end

    self:GetTimer().Delay(self:GetPara(1) / 1000, self.destroyAllAvatar, self)
end

SkillLib[skill_type] = SkillLocal

return SkillLocal