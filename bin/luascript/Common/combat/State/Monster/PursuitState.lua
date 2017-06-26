-- ---------------------------------------------------
-- -- auth： panyinglong
-- -- date： 2016/9/13
-- -- desc： 追击状态
-- ---------------------------------------------------
-- local Vector3 = Vector3
-- require "Common/combat/State/State"

-- function CreatePursuitState(name, stateType, scene)
-- 	local self = CreateState(name, stateType, scene)
-- 	local base = self.base()

--     local movePos = Vector3.zero

--     local isOutOfPursuit = function(owner, enemy)       
--         if Vector3.Distance(owner:GetBornPosition(), enemy:GetPosition()) >= owner.LeaveRadius then
--             return true
--         end
--         return false
--     end

--     local pursuitEnemy = function(owner, enemy)
--         if not Vector3.Equals(enemy:GetPosition(), movePos) then
--             owner:Moveto(enemy:GetPosition())
--             movePos = enemy:GetPosition()
			
--             enemy:BeTarget(owner) --通知敌人，我开始追击你
--         end
--     end

-- 	self.Excute = function( owner, enemy, slot )
--         if owner:IsDied() then
--             return
--         end
--         if enemy:IsDied() then
--             owner.stateManager:GotoState(StateType.ePatrol)
--             return
--         end
        
--         if isOutOfPursuit(owner, enemy) then
--             owner:StopMove()
--             owner.stateManager:GotoState(StateType.ePatrol)
--             return
--         end     

--         if not slot then
--             slot = SlotIndex.Slot_Attack
--         end

--         if owner.skillManager:IsInCastRange(slot, enemy) then
--             owner:StopMove()
--             owner.stateManager:GotoState(StateType.eAttack, enemy)
--             enemy:BeTarget(owner)
--         else
--             pursuitEnemy(owner, enemy)
--         end

--    --      local canCast = owner:CanCastSkill(slot, enemy)
--    --      if canCast == Const.error_skill_cast_ok then
--    --          owner:StopMove()
--    --          owner.stateManager:GotoState(StateType.eAttack, enemy)
-- 			-- enemy:BeTarget(owner) --通知敌人，我开始追击你
--    --      elseif canCast == Const.error_skill_too_far then                
--    --          pursuitEnemy(owner, enemy)
--    --      else
--    --          owner:StopMove()
--    --          owner.stateManager:GotoState(StateType.ePatrol)            
--    --      end
--     end

--     return self
-- end