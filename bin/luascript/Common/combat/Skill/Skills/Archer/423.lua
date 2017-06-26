---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/31
-- desc： Skill Test

-- 【宠物】攻击单体敌人，造成120%的物理伤害，同时回复血量最低的宠物血量30%                               

---------------------------------------------------

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '423'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_UNIT
end

function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)
    local target = data.target
    if target then
        SkillAPI.TakeDamage(target, self.owner, self, self.OnDamageCorrect, self)
        
        -- 范围伤害
        local units = SkillAPI.EnumUnitsRandom(
            self.owner, 
            {
                area_type = EnumUnitsAreaType.Circle,
                radius = 10000,
            }, 
            EntityType.Pet, 100)

        local pet = nil

        for _, unit in pairs(units) do
            if pet == nil or pet.hp > unit.hp then
                pet = unit
            end
        end
        -- 加血
        if pet then
            SkillAPI.AddHp(pet, pet.hp_max() * self:GetPara(2) / 10000, self.owner, self.skill_id)
        end
    end
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)
    local percent = self:GetPara(1) / 10000
    return M4 * percent + self:GetPara(3) / 10000;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal