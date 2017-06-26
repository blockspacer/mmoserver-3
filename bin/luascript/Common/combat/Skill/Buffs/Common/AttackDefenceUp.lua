---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/08
-- desc： 被杀愤怒补偿
--[[
攻击玩家时每次攻击时附带自身攻击力x【参数1百分比】的额外伤害，
并受到玩家攻击时额外降低自身防御x【参数2百分比】的伤害
]]



---------------------------------------------------

require "Common/basic/Timer"
require "Common/basic/Bit"
require "Common/combat/Skill/Buff"

local Buff = require "Common/combat/Skill/Buff"

local BuffAttackDefenceUp = ExtendClass(Buff)

function BuffAttackDefenceUp:__ctor(scene, buff_id, data)
    self.work_independent = true
end

function BuffAttackDefenceUp:OnTick(interval)
    Buff.OnTick( self , interval )
end

-- 接受伤害时统一使用这个函数
function BuffAttackDefenceUp:ChangeTakeDamage(damage, skill)
	local defence = nil
    if skill.damage_mode == AttackMode.Magic then
    	defence = self.owner.magic_defence()
    else
    	defence = self.owner.physic_defence()
    end
    return math.max(0, damage - defence * self:GetPara(2) / 10000)
end

-- 造成伤害时统一使用这个函数
function BuffAttackDefenceUp:ChangeCauseDamage(damage, skill, target)
    local attack = nil
    if skill.damage_mode == AttackMode.Magic then
    	attack = self.owner.magic_attack()
    else
    	attack = self.owner.physic_attack()
    end
    return damage + attack * self:GetPara(1) / 10000
end


return BuffAttackDefenceUp

