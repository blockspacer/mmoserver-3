---------------------------------------------------
-- auth： wupeifeng
-- date： 2017/1/19
-- desc： 魅惑状态
---------------------------------------------------

local State = require "Common/combat/State/State"
local CharmState = ExtendClass(State)

function CharmState:__ctor(scene, name, stateType)
    self.target = nil
end

function CharmState:FindAlly(owner)
    if owner.entityType == EntityType.Hero then
        if not TeamManager.InTeam() then
            local pets = owner:GetPets()
            for _, pet in pairs(pets) do
                return pet
            end
            return nil
        else
            local info = TeamManager.GetTeamInfo()
            if table.isEmptyOrNil(info) then
                return nil
            end     
            for _,v in pairs(info.members) do
                local unit = owner:GetEntityManager().GetPuppet(v.actor_id)
                if v.actor_id ~= owner.uid then
                    return unit
                end

            end
        end
    elseif owner.entityType == EntityType.Pet then
        return owner.owner
    else
        return SkillAPI.NearestTarget(owner, nil, nil, true)
    end
end

function CharmState:Excute(owner, ...)
    self.owner = owner

    if owner:IsDied() or owner:IsDestroy() then
        return
    end
    if self.target == nil or self.target:IsDied() or self.target:IsDestroy() then
        self.target = self:FindAlly(self.owner)
    end

    --[[if self.target then
        self.owner:ApproachAndCastSkill(SlotIndex.Slot_Attack, self.target)  
        return
    end]]

    if owner.skillManager:IsOnCommonCD() then
        return
    end

    if owner.skillManager:IsInCastRange(SlotIndex.Slot_Attack, self.target) then
        owner:StopMove()
        owner:StopApproachTarget()
        owner:CastSkill(SlotIndex.Slot_Attack, self.target)
    else
        if not owner:IsOnApproachTarget(self.target) then
            owner:StopApproachTarget()
            local skillDis = owner.skillManager.skills[SlotIndex.Slot_Attack].cast_distance
            owner:StartApproachTarget(self.target, skillDis)
        end
    end
end

return CharmState
