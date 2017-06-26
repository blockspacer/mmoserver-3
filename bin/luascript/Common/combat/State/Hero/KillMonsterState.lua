---------------------------------------------------
-- auth： panyinglong
-- date： 2017/3/17
-- desc： 杀怪任务
---------------------------------------------------

local HeroAttackState = require "Common/combat/State/Hero/HeroAttackState"
local KillMonsterState = ExtendClass(HeroAttackState)

function KillMonsterState:__ctor(scene, name, stateType)
    self.nextDefault = stateType -- 默认下一状态还是自己 
    self.curEnemy = nil
end

function HeroAttackState:FindEnemy(owner, taskData)
    local selectMonster = function(puppet)
        if puppet.entityType == EntityType.Monster and 
            puppet.data.ElementID == taskData.getMonsterSceneId() 
            and not puppet:IsDied() then
            return true
        end
        return false
    end

    local enemy = owner:AOIQueryPuppet(selectMonster) --优先选择npc
    if enemy then
        return enemy
    end
    return nil
end

function KillMonsterState:Excute(owner, taskData)
    if not taskData then
        error('杀怪状态必须要有taskData')
    end
    if taskData.isKilledEnough() then
        owner:StopKillMonster()
        return
    end
    if not self.curEnemy or self.curEnemy:IsDied() or self.curEnemy:IsDestroy() then
        self.curEnemy = self:FindEnemy(owner, taskData)
    end
    HeroAttackState.Excute(self, owner, self.curEnemy)
end

return KillMonsterState
