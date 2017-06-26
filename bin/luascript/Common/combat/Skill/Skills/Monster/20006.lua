--
-- Created by IntelliJ IDEA.
-- User: hou
-- Date: 2016/12/22 0022
-- Time: 10:53
-- To change this template use File | Settings | File Templates.
--
--[[
-- 毒性引爆	大范围攻击		大招	20006
-- 1	发出毒雾：对BOSS周围15米范围内玩家造成伤害。
-- 2	伤害为：BOSS法术攻击力x50%xmax(1,剧毒之甲buff层数)的伤害
-- 3	技能冷却时间30秒
-- 3	BOSS血量低于50%时释放。
 ]]

require "Common/basic/functions"
require "Common/combat/Skill/Skill"
require "Common/combat/Skill/SkillManager"
require "Common/combat/Skill/SkillAPI"

local skill_type = '20006'

local Skill = require "Common/combat/Skill/Skill"
local SkillLocal = ExtendClass(Skill)

function SkillLocal:__ctor(scene, skill_id, data)
    local config = GetConfig("growing_skill")
    self.skill_data = config.Skill[tonumber(skill_id)]

    -- 目标类型
    self.cast_target_type = CastTargetType.CAST_TARGET_NONE
end

-- skill开始施法
function SkillLocal:OnCastStart(data)
    Skill.OnCastStart(self, data)
end

-- skill施法中
function SkillLocal:OnCastChannel(data)
    Skill.OnCastChannel(self, data)

    local units = SkillAPI.EnumUnitsRandom(
        self.owner,
        {
            area_type = EnumUnitsAreaType.Circle,
            radius = self.area_radius,
        },
        nil, 100000, true)

    for _, unit in pairs(units) do
        SkillAPI.TakeDamage(unit, self.owner, self, self.OnDamageCorrect, self)
        unit.skillManager:AddBuffFromSkill(tostring(self.skill_data.Buff1), self)
    end
end

function SkillLocal:OnTakeDamage(damage, attacker, spell_name, event_type)
    Skill.OnTakeDamage(self, damage, attacker, spell_name, event_type)
    --TODO 当受到 攻击的时候xxxx
end

function SkillLocal:IsFillCondition()
    return self.owner.hp < self.owner.hp_max() * self:GetPara(1) / 10000
end

function SkillLocal:OnDamageCorrect(M1, M2, M3, M4, target)

    local percent = self:GetPara(1) / 10000

    local chenshu = 1
    local toxic_armor_buff = target.skillManager:FindBuffByID(tostring(self.skill_data.Buff1))
    if toxic_armor_buff then
        chenshu = toxic_armor_buff.count
    end
    return M4 * percent * chenshu;
end

SkillLib[skill_type] = SkillLocal

return SkillLocal

