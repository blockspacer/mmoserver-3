---------------------------------------------------
-- auth： panyinglong
-- date： 2016/9/11
-- desc： 攻击状态
---------------------------------------------------
local flog = require "basic/log"
local AttackState = require "Common/combat/State/AttackState"


local NPCAttackState = ExtendClass(AttackState)

function NPCAttackState:__ctor(scene, name, stateType)
    self.nextDefault = StateType.ePatrol
end

function NPCAttackState:Excute( owner, enemy )
    self.owner = owner
    if owner:IsDied() or owner:IsDestroy() then
        return
    end
    
    if not enemy or enemy:IsDied() or enemy:IsDestroy() then
        enemy = owner:GetCurrentHatredEntity()
    end

    if not enemy or enemy:IsDied() or enemy:IsDestroy() then
        self:StopAttack(owner)
        owner.stateManager:GotoState(StateType.ePatrol)
        return 
    end

    AttackState.Excute(self, owner, enemy)
end

function NPCAttackState:OnActive( owner, ... )
    AttackState.OnActive(self, owner, ...)
    
    if self.activeNum == 1 then -- 第一次触发
        for k, v in pairs(owner.skillManager.skills) do 
            if v:GetSkillType() ~= '1' then -- 是技能非普攻
                v:SetFullCD()
            end
        end
    end
end

return NPCAttackState
