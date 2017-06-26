---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/25
-- desc： 状态基类
---------------------------------------------------

StateType = 
{
    eNull = 1,
    eAttack = 2,
    ePatrol = 3,
    ePursuit = 4,
	eIdle = 5,
    eGoto = 6,
    eFollow = 7,
    eCharm = 8,
    eFear = 9,
	eHookAttack = 10,
	eHookPatrol = 11,
	eWildHook = 12,
    eKillMonster = 13,
    eArenaHook = 14,
}

local SceneObject = require "Common/basic/SceneObject2"
local State = ExtendClass(SceneObject)

function State:__ctor(scene, name, stateType)
    self.name = name or "unknown"  -- 注:name即animation的名称
    self.stateType = stateType or StateType.eNull

    self.startClock = 0
    self.isActive = false
    self.activeNum = 0
end

function State:Excute( owner, ... )
end

function State:OnActive( owner, ... )
    self.startClock = os.clock()
    self.isActive = true
    self.activeNum = self.activeNum + 1
end

function State:OnDeactive( owner, ... )
    self.isActive = false        
end

return State
