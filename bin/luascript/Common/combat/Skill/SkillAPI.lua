---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/09/08
-- desc： SkillManager
---------------------------------------------------
local Vector3 = Vector3
local floor = require'math'.floor

require "Common/combat/Skill/SkillFormula"
require "Common/combat/Skill/SkillConst"
require "Common/basic/MathHelper"
require "Common/basic/Bit"
local constant = require "Common/constant"


--[[
/* take damage
 * 
 * @param unit  承受伤害的单位
 * @param damage (float)  伤害值
 * @param attacker_id 发起伤害的单位
 * @param spell_name 技能id
 */
]]
local grow_skill_config = GetConfig("growing_skill")
local common_fight_base_config = GetConfig('common_fight_base')
local localization = require "Common/basic/Localization"

SkillAPI = {}
local SkillAPI = SkillAPI

function SkillAPI.RequireSkill(skill_type)
	if tonumber(skill_type) < 100 then
		require("Common/combat/Skill/Skills/Common/"..skill_type)
	elseif tonumber(skill_type) < 1000 then
		if string.sub(skill_type, 0, 1) == '1' then
			require("Common/combat/Skill/Skills/Sword/"..skill_type)
		elseif string.sub(skill_type, 0, 1) == '2' then
			require("Common/combat/Skill/Skills/Boxer/"..skill_type)
		elseif string.sub(skill_type, 0, 1) == '3' then
			require("Common/combat/Skill/Skills/Wizard/"..skill_type)
		elseif string.sub(skill_type, 0, 1) == '4' then
			require("Common/combat/Skill/Skills/Archer/"..skill_type)
		end
	else
		require("Common/combat/Skill/Skills/Monster/"..skill_type)
	end
end

function SkillAPI.TakeDamage(target, attacker, skill, skill_damage_correct_func, table)
	if GRunOnClient then
		return 0
	end

	local damage, damage_type = 
		SkillFormula.TakeDamage(target, attacker, skill, skill_damage_correct_func, table)

	-- 输出伤害矫正
	for _, buff in pairs(attacker.skillManager.buffs) do
		--print(buff.buff_name)
		if type(buff.ChangeCauseDamage) == 'function' then 
			--print(buff.buff_name, 'OnTakeDamage')
			damage = buff:ChangeCauseDamage(damage, skill, target)
		end
	end

	-- 进行护盾、buff、伤害加强处理
	for _, buff in pairs(target.skillManager.buffs) do
		--print(buff.buff_name)
		if type(buff.ChangeTakeDamage) == 'function' then 
			--print(buff.buff_name, 'OnTakeDamage')
			damage = buff:ChangeTakeDamage(damage, skill, attacker)
		end
	end

	damage = floor(damage or 1)

	if attacker.this_is_daddy then
		damage = 1000000
	end
	if target.this_is_daddy then
		damage = 0
	end
	
	-- TODO 最后还是要进行敌我判断, 但是在一开始放技能的时候就判断会比较好
	if attacker:IsEnemy(target) or attacker:HasStatus('Charm') then
		target:TakeDamage(damage, attacker, skill.skill_id, damage_type)
	end
	

	return damage
end

function SkillAPI.ReduceMp(target, num, source, skill_id)
	if GRunOnClient then
		return 
	end

    if target:IsDied() or target:IsDestroy() then
        return 
    end
    
	num = floor(num)
	target:ReduceMp(num, source)
end

function SkillAPI.AddMp(target, num, source, skill_id)
	if GRunOnClient then
		return 
	end

    if target:IsDied() or target:IsDestroy() then
        return 
    end

	num = math.floor(num)
	target:AddMp(num, source)
end

function SkillAPI.MinusHp(target, hp, source, skill_id)
	if GRunOnClient then
		return 
	end

    if target:IsDied() or target:IsDestroy() then
        return 
    end

	hp = math.floor(hp)
	target:TakeDamage(hp, source, skill_id, DamageType.Normal)
	--target:ReduceHp(hp, source)
	--target.hp = target.hp - hp
end

function SkillAPI.AddHp(target, hp, source, skill_id)
	if GRunOnClient then
		return 
	end

    if target:IsDied() or target:IsDestroy() then
        return 
    end

	if target:HasStatus('HealBlock') then
		return 
	else
		-- 进行护盾、buff、伤害加强处理
		for _, buff in pairs(target.skillManager.buffs) do
			--print(buff.buff_name)
			if type(buff.ChangeAddHp) == 'function' then 
				--print(buff.buff_name, 'OnTakeDamage')
				hp = buff:ChangeAddHp(hp)
			end
		end

		hp = math.floor(hp)

		target:AddHp(hp, source)
	end
	--TODO 根据unit的自身属性(治疗效果，治疗减益等各种作用，对hp数值进行矫正, 再调用unit.OnAddHp方法)
end

-- 多少概率出指定事件
function SkillAPI.RandEvent(percent, func, ...)
	local luck = math.random()
	--print('SkillAPI.RandEvent', luck, percent)
	local args = {...}
	if luck < percent then
		func(unpack(args))
	end
end

--[[
/* enum units 选取单位
 * 
 * @param reference unit (参考单位。会取这个单位的位置啊阵营啊什么的，省得另外传好多参数)
 * @param area_filter_param ( like circle radius, zero or multiple params, according to filter type )
 * @param attribute_filters (flag sum) ( is visible, no building and so on)
 * @param attribute_filter_param ( zero or multiple params, according to filter(s) type )
 */
]]
function SkillAPI.IsAvailableTarget(source, target, entity_type, is_enemy, is_ally)
	if source == nil or target == nil then
		return false
	end

	if source.uid == target.uid then
		return false
	end

	if entity_type ~= nil then
		if bit:_and(target.entityType, entity_type) == 0 then
			return false
		end
	end

	if is_enemy ~= nil then
		if source:IsEnemy(target) ~= is_enemy then
			return false
		end
	end

	if is_ally ~= nil then
		if source:IsAlly(target) ~= is_ally then
			return false
		end
	end

	if target:IsDied() or target:IsDestroy() then
		return false
	end

	return true
end

function SkillAPI.EnumUnits(unit, area_data, entity_type, is_enemy, is_ally)
	-- TODO 选取单位，用来做区域技能
	local units = unit:AOIQueryPuppets(function(v) 
		-- if ..
		if not SkillAPI.IsAvailableTarget(unit, v, entity_type, is_enemy, is_ally) then
			return false
		end

		if area_data.area_type == EnumUnitsAreaType.Circle then
			if not MathHelper.IsInCircle(unit:GetPosition(), v:GetPosition(), area_data.radius) then
				return false
			end
		elseif area_data.area_type == EnumUnitsAreaType.Rectangle then
			if not MathHelper.IsInForwardRect(
				unit, v:GetPosition(), area_data.width, area_data.height) then
				return false
			elseif area_data.area_type == EnumUnitsAreaType.Sector then
			    if not MathHelper.IsInForwardSector(
			    	unit, v:GetPosition(), area_data.radius, area_data.angle) then
				    return false
				end
			end
		end

		return true
	end)

	return units
end



function SkillAPI.NearestTarget(unit, entity_type, is_enemy, is_ally)
	if unit == nil then
		return nil
	end

	local units = unit:AOIQueryPuppets(function(v) 
		-- if ..

		return SkillAPI.IsAvailableTarget(unit, v, entity_type, is_enemy, is_ally)
	end)


	local distance = 10000000
	local target = nil
	for _,v in pairs(units) do
		if Vector3.InDistance(unit:GetPosition(), v:GetPosition(), distance) then
			distance = Vector3.Distance2D(unit:GetPosition(), v:GetPosition())
			target = v
		end
	end
	return target
end


--@param reference skill_owner (参考单位。会取这个单位的位置啊阵营啊什么的，省得另外传好多参数)
function SkillAPI.EnumUnitsInCircle(skill_owner, location, area_data, entity_type, is_enemy, is_ally)
	-- TODO 选取单位，用来做区域技能
	local units = skill_owner:GetEntityManager().AOIQueryPuppets(
		skill_owner:GetSceneID(), location.x, location.z, 
		function(v) 
			-- if ..

			-- 如果是选择 特定单位类型
			if not SkillAPI.IsAvailableTarget(skill_owner, v, entity_type, is_enemy, is_ally) then
				return false
			end

			if not MathHelper.IsInCircle(location, v:GetPosition(), area_data.radius) then
				return false
			end

			return true
		end)

	return units
end

--@param reference skill_owner (参考单位。会取这个单位的位置啊阵营啊什么的，省得另外传好多参数)
function SkillAPI.EnumUnitsRandomInCircle(skill_owner, location, area_data, entity_type, num, is_enemy, is_ally)
	local units = SkillAPI.EnumUnitsInCircle(skill_owner, location, area_data, entity_type, is_enemy, is_ally)

	if table.getn(units) <= num then
		return units
	end

	local random_units = {}
	for i = 1, num, 1 do 
		local rand_index = math.random(table.getn(units))
		table.insert(random_units, units[rand_index])
		table.remove(units, rand_index)
	end

	return random_units
end

function SkillAPI.EnumUnitsRandom(unit, area_data, entity_type, num, is_enemy, is_ally)
	local units = SkillAPI.EnumUnits(unit, area_data, entity_type, is_enemy, is_ally)

	if table.getn(units) <= num then
		return units
	end

	local random_units = {}
	for i = 1, num, 1 do 
		local rand_index = math.random(table.getn(units))
		table.insert(random_units, units[rand_index])
		table.remove(units, rand_index)
	end

	return random_units
end

function SkillAPI.MoveForward(unit, speed, time)
	if unit:HasStatus('SuperArmor') then
		return 
	end
	local r = unit:GetRotation()
	unit:SpurtTo(r * Vector3.forward, speed, 0, time, 0, true, 0, 0)
end

function SkillAPI.MoveBackward(unit, speed, time)
	if unit:HasStatus('SuperArmor') then
		return 
	end
	local r = unit:GetRotation()
	unit:SpurtTo(r * Vector3.back, speed, 0, time, 0, true, 0, 0)
end


function SkillAPI.CanBeForcedMove(unit)
	if unit:HasStatus('SuperArmor') then
		return false
	end

	if unit.GetElementSceneType and unit:GetElementSceneType() == constant.ENTITY_TYPE_COUNTRY_ARCHER_TOWER then
		return false
	end

	return true
end

--将unit 移动到target位置，耗时time
function SkillAPI.MoveToward(unit, target, time)
	if not SkillAPI.CanBeForcedMove(unit) then
		return 
	end
	dir = target:GetPosition() - unit:GetPosition();
	dir.y = 0
    dir = dir.normalized;
    speed = Vector3.Distance2D(target:GetPosition(), unit:GetPosition()) / time
    unit:SpurtTo(dir, speed, 0, time, 0, true, 0, 0)
end

function SkillAPI.MoveToPostion(unit, target_pos, time)
	if not SkillAPI.CanBeForcedMove(unit) then
		return 
	end
	dir = target_pos - unit:GetPosition();
	dir.y = 0
    dir = dir.normalized;
    speed = Vector3.Distance2D(target_pos, unit:GetPosition()) / time
    unit:SpurtTo(dir, speed, 0, time, 0, true, 0, 0)
end

--将unit 向target的反方向移动distance距离，耗时time
function SkillAPI.MoveBackwardTo(unit, target, distance, time)
	if not SkillAPI.CanBeForcedMove(unit) then
		return 
	end
	dir = unit:GetPosition() - target:GetPosition();
	dir.y = 0
    dir = dir.normalized;
    local destination = unit:GetPosition() + dir * distance
    destination = unit:GetCombatScene():GetNearestPolyOfPoint(destination)
    distance = Vector3.Distance2D(destination, unit:GetPosition())
    speed = distance / time
    unit:SpurtTo(dir, speed, 0, time, 0, true, 0, 0)
end

function SkillAPI.CreateTrigger(trigger_type, pos, radius, callback)
    require "Logic/SceneWidget/AreaTrigger"
    local data = { 
        TrggerPara1 = trigger_type,
        TrggerPara2 = 
            tostring(radius*2).."|"..
            tostring(radius*2).."|"..
            tostring(radius*2),
        PosX = pos.x,
        PosY = pos.y,
        PosZ = pos.z,
    }
     
    local areaTrigger = CreateAreaTrigger(data)
    areaTrigger.OnTrigger = function(uid)
        local target = SceneManager.GetEntityManager().GetPuppet(uid)
        callback(target)
        areaTrigger.Destroy()
    end
    areaTrigger.callback = areaTrigger.OnTrigger
    areaTrigger.Start()
end

function SkillAPI.PlayShake(unit, ShockID, ShockTime)
	
	local shake_config = common_fight_base_config.VibrationScreen[ShockID]

	local function shake()
		if unit.behavior then
			unit.behavior:PlayShakeEvent(shake_config.Range, shake_config.Duration)
		end
	end

	if shake_config.Object == 1 then
		if unit.entityType ~= EntityType.Hero then
			return 
		end
	end

	if ShockTime > 0 then
		unit:GetTimer().Delay(ShockTime/1000, shake)
	else
		shake()
	end
end

local motionTable = GetConfig("MotionEffects")

function SkillAPI.GetBulletData(unit, animation)
	if unit == nil or unit.behavior == nil then
		return nil
	end
	local modelId = unit.behavior.modelId
	if motionTable[modelId] then
		if motionTable[modelId][animation] then
			if motionTable[modelId][animation].bulletEffects then
				return motionTable[modelId][animation].bulletEffects[1]
			end
		end
	end
	return nil
end

function SkillAPI.GetSkillEffectData(unit, animation)
	if unit == nil or unit.behavior == nil then
		return nil
	end
	local modelId = unit.behavior.modelId
	if motionTable[modelId] then
		if motionTable[modelId][animation] then
			if motionTable[modelId][animation].skillEffects then
				return motionTable[modelId][animation].skillEffects
			end
		end
	end
	return nil
end

function SkillAPI.GetSkillBehitData(unit, skill_id)
	if unit == nil or unit.behavior == nil then
		return 
	end
	local skill_data = grow_skill_config.Skill[tonumber(skill_id)]
	local skill_effect_type = tostring(skill_data.EffectClass)
	require("Common/combat/Skill/SkillEffects/"..skill_effect_type)
	local skill_effect = SkillEffectLib[skill_effect_type](unit.scene, skill_id, {})
	local animation = skill_effect.default_animation


	local modelId = unit.behavior.modelId
	if motionTable[modelId] then
		if motionTable[modelId][animation] then
			if motionTable[modelId][animation].hitEffects then
				return motionTable[modelId][animation].hitEffects
			end
		end
	end
	return nil
end

function SkillAPI.ChangeBattleExp(unit, exp)
	for _, buff in pairs(unit.skillManager.buffs) do
		--print(buff.buff_name)
		if type(buff.ChangeBattleExp) == 'function' then 
			--print(buff.buff_name, 'OnTakeDamage')
			exp = buff:ChangeBattleExp(exp)
		end
	end
	exp = SkillAPI.ChangeAllExp(unit, exp)
	return exp
end

function SkillAPI.ChangeAllExp(unit, exp)
	for _, buff in pairs(unit.skillManager.buffs) do
		--print(buff.buff_name)
		if type(buff.ChangeAllExp) == 'function' then 
			--print(buff.buff_name, 'OnTakeDamage')
			exp = buff:ChangeAllExp(exp)
		end
	end
	return exp
end

function SkillAPI.GetBuffPara(buff_id, index, level, count, key)
	if buff_id == '0' or buff_id == '' then
		return 0
	end
	key = key or 1
	count = count or 1
	local buff_data = grow_skill_config.Buff[tonumber(buff_id)]
	if buff_data == nil then
		return 0
	end
	local base = 0
    if type(buff_data['Para'..tostring(index)]) == 'number' then
    	base = buff_data['Para'..tostring(index)] or 0
    else
    	base = buff_data['Para'..tostring(index)][key] or 0
    end
    local up = 0
    if type(buff_data['ParaUpdate'..tostring(index)]) == 'number' then
    	up = buff_data['ParaUpdate'..tostring(index)] or 0
    else
    	up = buff_data['ParaUpdate'..tostring(index)][key] or 0
    end
    return ( base + level * up ) * count
end

function SkillAPI.GetSkillPara(skill_id, index, level)
	local skill_data = grow_skill_config.Skill[tonumber(skill_id)]

	local para = nil

	if SkillUp.GetSkillPara(tonumber(skill_id), level, index) then
		para =  
			skill_data['Para'..tostring(index)] + 
			SkillUp.GetSkillPara(tonumber(skill_id), level, index)
	else
		para = skill_data['Para'..tostring(index)]
	end

	return para
end

function SkillAPI.GetSkillDescription(skill_id, level)

	local skill_data = grow_skill_config.Skill[tonumber(skill_id)]
	if skill_data.Description == "0" or skill_data.Description == "" then
		return ""
	end
	--local desc = localization.GetChineseName(skill_data.Description)
	local desc = skill_data.Description1

	local buff1_data = grow_skill_config.Buff[tonumber(skill_data.Buff1)] or {}
	local buff2_data = grow_skill_config.Buff[tonumber(skill_data.Buff2)] or {}
	local replace = {
		['Para1'] = SkillAPI.GetSkillPara(skill_id, 1, level),
		['Para2'] = SkillAPI.GetSkillPara(skill_id, 2, level),
		['Para3'] = SkillAPI.GetSkillPara(skill_id, 3, level),
		['Para4'] = SkillAPI.GetSkillPara(skill_id, 4, level),
		['buff1:Para1'] = SkillAPI.GetBuffPara(skill_data.Buff1, 1, level),
		['buff1:Para2'] = SkillAPI.GetBuffPara(skill_data.Buff1, 2, level),
		['buff1:time'] = (buff1_data.time or 0)/1000,
		['buff2:Para1'] = SkillAPI.GetBuffPara(skill_data.Buff2, 1, level),
		['buff2:Para2'] = SkillAPI.GetBuffPara(skill_data.Buff2, 2, level),
		['buff2:time'] = (buff2_data.time or 0)/1000,
		['CD'] = skill_data.CD,
		}

	local function fuck_off(chstr)

		function chartoint(chstr)  
	        if replace[chstr] then
	        	return replace[chstr]
	        else
	        	return chstr;  
	        end
	    end  

		local y=string.gsub(chstr,"%a[%w:]+",chartoint);  
		local y=string.gsub(y,"%[",''); 
		local y=string.gsub(y,"%]",''); 
	    y ="return "..y
	    y = math.abs( loadstring(y)() )
    	return y;  
	end

	desc = string.gsub(desc, "%[[%w/*+-.():]+%]", fuck_off)
	--[[for k,v in pairs(replace) do
		
	end]]
	return desc
end

function SkillAPI.GetBuffDescription(buff_id, level)
	local buff_data = grow_skill_config.Buff[tonumber(buff_id)]
	local desc = buff_data.Description1
	if desc == "0" or desc == "" then
		return ""
	end
	
	local replace = {
		['Para1'] = SkillAPI.GetBuffPara(buff_id, 1, level),
		['Para2'] = SkillAPI.GetBuffPara(buff_id, 2, level),
		}
		
	local function fuck_off(chstr)

		function chartoint(chstr)  
	        if replace[chstr] then
	        	return replace[chstr]
	        else
	        	return chstr;  
	        end
	    end  

		local y=string.gsub(chstr,"%a[%w:]+",chartoint);  
		local y=string.gsub(y,"%[",''); 
		local y=string.gsub(y,"%]",''); 
	    y ="return "..y
	    y = math.abs( loadstring(y)() )
    	return y;  
	end

	desc = string.gsub(desc, "%[[%w/*+-.():]+%]", fuck_off)
	return desc
end

return SkillAPI