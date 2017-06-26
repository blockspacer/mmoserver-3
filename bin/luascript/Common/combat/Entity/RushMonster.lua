---------------------------------------------------
-- auth： panyinglong
-- date： 2017/3/3
-- desc： 对冲monster
---------------------------------------------------

local CreateMonsterAttackState = require "Common/combat/State/Monster/MonsterAttackState"
local CreateMonsterRushPatrolState = require "Common/combat/State/Monster/MonsterRushPatrolState"
local CreateCharmState = require "Common/combat/State/Skill/CharmState"
local CreateFearState = require "Common/combat/State/Skill/FearState"

local Monster = require "Common/combat/Entity/Monster"
local RushMonster = ExtendClass(Monster)

-- 设置行为
function RushMonster:SetState()
	self.stateManager:AddState(StateType.eAttack, CreateMonsterAttackState(scene, 'attack', StateType.eAttack))
	self.stateManager:AddState(StateType.ePatrol, CreateMonsterRushPatrolState(scene, 'patrol', StateType.ePatrol))
	self.stateManager:AddState(StateType.eCharm, CreateCharmState(scene, 'charm', StateType.eCharm))
   	self.stateManager:AddState(StateType.eFear, CreateFearState(scene, 'fear', StateType.eFear))
	self.stateManager:GotoState(StateType.ePatrol)
	self.stateManager:StartTick()
end

function RushMonster:Born() 	
	Monster.Born(self)
end

return RushMonster