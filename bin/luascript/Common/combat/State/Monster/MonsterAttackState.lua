---------------------------------------------------
-- auth： panyinglong
-- date： 2016/9/11
-- desc： 攻击状态
---------------------------------------------------

local AttackState = require "Common/combat/State/AttackState"


local MonsterAttackState = ExtendClass(AttackState)

function MonsterAttackState:__ctor(scene, name, stateType)
    
end

function MonsterAttackState:Excute( owner, enemy )
    self.owner = owner
    if owner:IsDied() or owner:IsDestroy() then
        return
    end
    
    -- 如果不是npc则找仇恨最高的
    if not enemy or enemy.entityType ~= EntityType.NPC then
        enemy = owner:GetCurrentHatredEntity()
    end

    if not enemy or enemy:IsDied() or enemy:IsDestroy() then
        self:StopAttack(owner)
        owner.stateManager:GotoState(StateType.ePatrol)
        return 
    end

    AttackState.Excute(self, owner, enemy)
end

function MonsterAttackState:OnActive( owner, ... )
    AttackState.OnActive(self, owner, ...)
    
    if self.activeNum == 1 then -- 第一次触发
        for k, v in pairs(owner.skillManager.skills) do 
            if v:GetSkillType() ~= '1' then -- 是技能非普攻
                v:SetFullCD()
            end
        end
    end

    -- print("------ skill list --------")
    -- for k, v in pairs(owner.skillManager.skills) do 
    --     print("slot:" .. k .. ", cd:" .. v.cd .. ", comcd:" .. v.common_cd .. ", dis:" .. v.cast_distance)
    -- end
    -- print("--------------------------")
end

return MonsterAttackState
