---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： SkillManager
---------------------------------------------------

require "Common/combat/Skill/SkillConst"

local config = GetConfig("common_fight_base")
local b_config = GetConfig("common_parameter_formula")

BattleParam = 
{
	F1 = config.Parameter[1].Value or 100,
	F2 = config.Parameter[2].Value or 100,
	F3 = config.Parameter[3].Value or 100,
	F4 = config.Parameter[4].Value or 100,
	U_Hero = config.Parameter[5].Value or 2000,
	U_Others = config.Parameter[6].Value or 6000,
	G1 = config.Parameter[15].Value / 10000 or 0.01,
	G2 = config.Parameter[16].Value / 10000 or 0.1,
	G3 = config.Parameter[24].Value / 100 or 0.2,
	T = config.Parameter[7].Value / 100 or 0.05,
	R_L = config.Parameter[22].Value or 80,
	R_H = config.Parameter[23].Value or 110,
}

Parameter = 
{
	Parameter7 = b_config.Parameter[7].Parameter / 100
}

SkillFormula = {}

function SkillFormula.TakeDamage(target, attacker, skill, skill_damage_correct_func, table)
	local damage_type = SkillFormula.DamageType(target, attacker, skill)
	local M1 = SkillFormula.BaseDamage(target, attacker, damage_type, skill)
	local M2 = SkillFormula.ElementDamage(target, attacker, skill.damage_mode)
	local M3 = SkillFormula.CorrectDamage(target, attacker, M1, M2)
	local M4 = SkillFormula.SpiritDamage(target, attacker, M3)
	local M5 = M4
	if skill_damage_correct_func then
		if table then
			M5 = skill_damage_correct_func(table, M1, M2, M3, M4, target)
		else
			M5 = skill_damage_correct_func(M1, M2, M3, M4, target)
		end
		--print('M4, M5', M4, M5)
	end
	local M6 = SkillFormula.FinalDamageLimitCorrect(attacker, M5, skill.damage_mode)
	local M7 = SkillFormula.RandDamage(M6)
	--print('damage_type,M1,M2,M3,M4,M5,M6,M7', damage_type, M1, M2, M3, M4, M5, M6, M7)
	return M7, damage_type
end

function SkillFormula.DamageType(unit, attacker, skill)
	local A = attacker
	local B = unit
	local E1 = math.max(0, (B.miss() - A.hit()) * BattleParam.F1)
	local E2 = math.max(0, (A.crit() * skill.self_crit_percent - B.resist_crit()) * BattleParam.F2)
	local E3 = math.max(0, (B.block() - A.break_up()) * BattleParam.F3)
	local E4 = math.max(0, (A.puncture() - B.guardian()) * BattleParam.F4)
	local E0 = E1 + E2 + E3 + E4
	local U = 0
	if attacker.entityType == EntityType.Hero then
		U = BattleParam.U_Hero
	else
		U = BattleParam.U_Others
	end
	--print('U_Hero, U_Others', U_Hero, U_Others)
	--print('U , 10000-E0', U, 100000 - E0)
	local E5 = math.max(U, 10000 - E0) * math.max(1, E0/(10000 - U))
	--print('E1, E2, E3, E4, E5', E1, E2, E3, E4, E5)
 	local num = math.random(E0 + E5)

 	if skill.ignore_miss then
 		E5 = E5 + E1
		E1 = 0
	end
 	--print('Random', num)
 	if num <= E1 then
 		return  DamageType.Miss
 	elseif num <= E1 + E2 then
 		return DamageType.Crit
 		elseif num <= E1 + E2 + E3 then
 			return DamageType.Block
 			elseif num <= E0 then
 				return DamageType.Puncture
 			else
 				return DamageType.Normal
 			end

end

--[[
M1 = max【0，A攻击*（A攻击 - 0.5 * B防御 * H）/（A攻击 + B防御*H）* L/2】
]]
function SkillFormula.BaseDamage(unit, attacker, damage_type, skill)
	local switch = {
		[DamageType.Miss] = function()
			return 0,0
		end,
		[DamageType.Crit] = function()
			return 2,1
		end,
		[DamageType.Block] = function()
			return 0.5,1
		end,
		[DamageType.Puncture] = function()
			return 1,0
		end,
		[DamageType.Normal] = function()
			return 1,1
		end,
	}

	local A = attacker
	local B = unit
	local attack, defence
	if skill.damage_mode == AttackMode.Physic then
		attack = A.physic_attack()
		defence = B.physic_defence()
	else
		attack = A.magic_attack()
		defence = B.magic_defence()
	end

	defence = defence * skill.target_defence_percent

	local L,H = switch[damage_type]()

	if (attack + defence * H) == 0 then
		return 0
	else
		return math.max( 0, attack * (attack - 0.5 * defence * H) / (attack + defence * H) * L / 2)
	end

end

--[[
M2 = 
	{
		max【0，（己方最大元素攻击 - 敌方对应元素防御）】+
		∑max【0，（己方其他元素攻击-敌方对应元素防御）*G3】
	} * min（敌方最大血量*G1，己方攻击力*G2）
]]
function SkillFormula.ElementDamage(unit, attacker, attack_mode)
	local A = attacker
	local B = unit

	local attack
	if attack_mode == AttackMode.Physic then
		attack = A.physic_attack()
	else
		attack = A.magic_attack()
	end

	local element = {
		'gold','wood', 'water', 'fire', 'soil', 'wind', 'light', 'dark'
	}
	local max = -1000
	local first_half = 0
	local second_half = 0

	for _,v in pairs( element ) do
		--print('SkillFormula.ElementDamage ',v..'_attack')
		local aattack = A[v..'_attack']()
		local bdefence = B[v..'_defence']()
		if aattack > max then
			max = aattack
			first_half = math.max( 0, aattack - bdefence)
		end
		second_half = second_half + math.max( 0, aattack - bdefence)
	end

	second_half = (second_half - first_half) * BattleParam.G3
 	
 	local element_damage = 
 		(first_half + second_half) 
 		* 
 		math.min( B.hp_max() * BattleParam.G1, attack * BattleParam.G2 )

 	return element_damage
end

--[[
M3 =
	【 
		M1*（1 + A基础增伤）*...(1 - B基础减伤)*...+
		M2*（1 + A元素增伤) *...(1 - B元素减伤)*...
	】
	*
	（1 + A增伤）*...（1 - B减伤）*... 
	+ A额外伤害增加 - B额外伤害减免
]]
function SkillFormula.CorrectDamage(unit, attacker, baisc_damage, element_damage)
	local A = attacker
	local B = unit

	local damage = 
		(
			baisc_damage * A.buffData.BasicDamagePlusPercent * B.buffData.BasicDamageMinusPercent
			+
			element_damage * A.buffData.ElementDamagePlusPercent * B.buffData.ElementDamageMinusPercent
		)
		* A.buffData.DamagePlusPercent * B.buffData.DamageMinusPercent 
		+ A.buffData.ExtraDamagePlus - B.buffData.ExtraDamageMinus

	return damage
end

--[[
若PVP，则 M4 = M3 * K1 * K2
若PVE状态，则 M4 = M3
灵性伤害加成修正公式： K1 = 1 + MAX（0，A灵性 - B灵性）/200
灵性伤害衰减公式：K2 = 200/（200 + MAX（0，B灵性 - A灵性）)
]]
function SkillFormula.SpiritDamage(unit, attacker, correct_damage)
	local A = attacker
	local B = unit
	local spirit_damage = correct_damage
	-- 只在服务器进行计算
	if not GRunOnClient then
		if unit.entityType == EntityType.Dummy and 
			attacker.entityType == EntityType.Dummy then

			local K1 = math.min(1.5, 1 + math.max(0, attacker.spritual() - unit.spritual())/200)
			local K2 = math.max(1, 200/(200 + math.max(0, unit.spritual() - attacker.spritual())))
			spirit_damage = math.min(spirit_damage * K1 * K2, unit.hp_max() * Parameter.Parameter7 )
		end
	end

	return spirit_damage
end


--[[
保底伤害：M6 = MAX（M5，A攻击 * T）
T = 5%
]]
function SkillFormula.FinalDamageLimitCorrect(attacker, damage, attack_mode)
	local A = attacker

	local attack
	if attack_mode == AttackMode.Physic then
		attack = A.physic_attack()
	else
		attack = A.magic_attack()
	end

	return math.max(damage, attack * BattleParam.T)
end

--[[
M7 = int[ M6*rand(80%,110%)]
]]
function SkillFormula.RandDamage(damage)

	return math.max(1,math.floor(damage * math.random(BattleParam.R_L, BattleParam.R_H) / 100))
end

function SkillFormula.TestFormulaEfficiency()
	require "Logic/Entity/Attribute/Attribute"
	local config = GetConfig("growing_actor")
	local target_data = config.Attribute["1_1"]
	local attacker_data = config.Attribute["2_1"]

	local target = {}
	target.attribute = CreateAttribute(target_data)
	local attacker = {}
	attacker.attribute = CreateAttribute(attacker_data)

	print('begin_time:', os.time())
	for i=1,1000000,1 do
		SkillFormula.TakeDamage(target, attacker, AttackMode.Physic)
	end
	print('end_time:', os.time())
	for i=1,1000000,1 do
	end
	print('end2_time:', os.time())


end













