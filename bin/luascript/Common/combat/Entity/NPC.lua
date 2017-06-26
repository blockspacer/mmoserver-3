---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/26
-- desc： npc,逻辑层
---------------------------------------------------

require "Common/combat/Entity/Puppet"
local CreateNPCBehavior = require "Logic/Entity/Behavior/NPCBehavior"

local Puppet = require "Common/combat/Entity/Puppet"
local NPC = ExtendClass(Puppet)

function NPC:__ctor(scene, data, event_delegate)
    self.configID = tonumber(data.Para1)
    self.entityType = EntityType.NPC 
    self.modelId = data.ModelID
    self.sceneObjectID = data.ID
    self.name = self:GetName(data)
end

function NPC:Born()
    Puppet.Born(self)
    self.behavior = CreateNPCBehavior(self)
    self.eventManager.Fire('OnBorn')
end 
    
function NPC:OnDestroy()
    Puppet.OnDestroy(self)
end

return NPC


