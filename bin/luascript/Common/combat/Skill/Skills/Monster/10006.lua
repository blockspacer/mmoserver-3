---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 三尾狐 10006 技能
--[[
狐影迷踪    辅助技能                            
a   妖狐尾部摆动，进入吟唱蓄力状态。吟唱蓄力状态持续3秒。                         
b   妖狐分出2个分身。每个分身的基础属性是本体的一半，血量的百分比与本体相同。                           
c   分身持续5秒。                         
d   分身的血量小于等于零时，消失。                         
e   技能冷却时间为15秒。                         
f   技能释放条件:无                                                               
]]
---------------------------------------------------
local Vector3 = Vector3

require "Common/basic/functions"
require "Common/basic/Timer"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10006'

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
            unit_data.PosX = self.owner:GetPosition().x
            unit_data.PosY = self.owner:GetPosition().y
            unit_data.PosZ = self.owner:GetPosition().z
            local unit = self:GetEntityManager().CreateScenePuppet(unit_data, EntityType.Monster)
            
            SkillAPI.MoveToPostion(unit, pos , 0.1)
            table.insert(self.avatars, unit.uid)
            unit:SetHp( unit.hp_max() * self.owner.hp / self.owner.hp_max() )
        end
        -- 交换位置
        local tmp = math.random(100)
        if tmp > 33 then
            local num = 1
            tmp = math.random(100)
            if tmp > 50 then
                num = 2
            end
            local unit = self:GetEntityManager().GetPuppet(self.avatars[num])
            local tmp = unit:GetPosition()
            unit:SetPosition( self.owner:GetPosition() )
            self.owner:SetPosition(tmp)

            print('switch to ', num)
        else
            print(' dont switch, rand = ', tmp)
        end
    end

    self:GetTimer().Delay(self:GetPara(1) / 1000, self.destroyAllAvatar, self)
end

SkillLib[skill_type] = SkillLocal

return SkillLocal