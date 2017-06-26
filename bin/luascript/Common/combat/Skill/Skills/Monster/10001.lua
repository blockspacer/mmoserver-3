---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/10/21
-- desc： 10001 技能
--[[
从场景外围的八卦地面中，召唤出【参数1】个半径为5米的岩浆球（对应技能ID=【参数2】）。                                                  
]]
---------------------------------------------------

require "Common/basic/functions"
require "Common/basic/Timer"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '10001'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    if not GRunOnClient then
        return 
    end
    print('10001', self.owner.summoned)
    -- 确实有召唤物
    if self.owner.summoned then
        for _,v in ipairs(self.owner.summoned) do
            if self:GetChapterScheme()[v] == nil then
                error("未找到对应的召唤物")
                return
            end 

            local scheme = self:GetChapterScheme()

            local toyData = {
                entity_id = self:GetEntityManager().GenerateEntityUID(),
                posX = scheme[v].PosX,
                posY = scheme[v].PosY,
                posZ = scheme[v].PosZ,
                res = scheme[v].res or 'Toy/empty',
                scale = scheme[v].scale or 1,
                Speed = self:GetPara(3),
            }
            local unit = self:GetEntityManager().CreateSummon(toyData)
            unit:AddEffect("Boss/eff_boss@chiyou_skill01_bullet")
            
            unit.HitTarget = function(target)
                print('HitTarget')
                SkillAPI.MinusHp(target, target.hp_max() * self:GetPara(1) / 10000, self.owner)
                unit.Bang()
            end

            unit.Bang = function()
                print('Bang')
                unit:RemoveEffect("Boss/eff_boss@chiyou_skill01_bullet")
                unit:AddEffect("Boss/eff_boss@chiyou_skill01_hit")

                -- 如果是由 撞击触发的 自爆 那就要把之前的定时器取消掉
                if unit.timer then
                    self:GetTimer().Remove(unit.timer)
                    unit.timer = nil
                end
                local units = SkillAPI.EnumUnitsRandom(
                    unit, 
                    {
                        area_type = EnumUnitsAreaType.Circle,
                        radius = self.area_radius,
                    }, 
                    nil, 100000, true)

                for _, v in pairs(units) do
                    SkillAPI.MinusHp(v, v.hp_max() * self:GetPara(2) / 10000, self.owner)
                    v.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
                end
                self:GetTimer().Delay(0.5, function() self:GetEntityManager().DestroyPuppet(unit.uid) end)
                --unit.OnDestroy()
            end
            -- 自爆时间
            unit.timer = self:GetTimer().Delay(5, unit.Bang)

            local target = SkillAPI.NearestTarget(unit, bit:_or(EntityType.Hero, EntityType.Pet))
            unit:StartApproachTarget(target, 1, unit.HitTarget, target)

        end

    end 

end

SkillLib[skill_type] = SkillLocal

return SkillLocal