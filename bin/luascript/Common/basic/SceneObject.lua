
---------------------------------------------------
-- auth： panyinglong
-- date： 2016/8/16
-- desc： 所有lua类的基类
---------------------------------------------------
require "Common/basic/LuaObject"


function CreateSceneObject(scene)
	local self = CreateObject()

	self.scene = scene

	self.GetEntityManager = function()
        return self.scene:GetEntityManager()
    end

    self.GetTriggersManager = function()
        return self.scene:GetTriggersManager()
    end

    self.GetTimer = function()
        return self.scene:GetTimer()
    end

    self.GetSceneID = function()
        return self.scene.scene_id
    end

    self.GetCombatScene = function()
        return self.scene
    end
    
    self.GetSceneType = function()
        if GRunOnClient then
            return SceneManager.currentSceneType
        else
            local scene = scene_manager.find_scene(self:GetSceneID())
            if scene ~= nil then
                return scene:get_scene_type()
            end
        end
    end

    self.GetMonsterSetting = function(monster_id)
        if monster_id and self.scene:GetScheme() then
            return self.scene:GetScheme().MonsterSetting[monster_id]
        else
            return nil
        end
    end

	return self
end