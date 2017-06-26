
---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/15
-- desc： 
---------------------------------------------------

require "Common/basic/LuaObject"

local SceneObject = ExtendClass()

function SceneObject:__ctor(scene)
    self.scene = scene
end

function SceneObject:GetEntityManager()
    return self.scene:GetEntityManager()
end

function SceneObject:GetTriggersManager()
    return self.scene:GetTriggersManager()
end

function SceneObject:GetTimer()
    return self.scene:GetTimer()
end

function SceneObject:GetOSTime()
	if GRunOnClient then
		return UnityEngine.Time.time
	else
		return _get_now_time_second()
	end
end

function SceneObject:GetSceneID()
    return self.scene.scene_id
end

function SceneObject:GetCombatScene()
	return self.scene
end

function SceneObject:GetSceneType()
	if GRunOnClient then
		return SceneManager.currentSceneType
	else
		local scene = scene_manager.find_scene(self:GetSceneID())
		if scene ~= nil then
			return scene:get_scene_type()
		end
	end
end

function SceneObject:GetMonsterSetting(monster_id)
	if monster_id and self.scene:GetScheme() then
		return self.scene:GetScheme().MonsterSetting[monster_id]
	else
		return nil
	end
end

function SceneObject:GetSceneSetting()
	if self.scene:GetScheme() and self.scene.scene_setting_name then
		return self.scene:GetScheme()[self.scene.scene_setting_name]
	else
		return nil
	end
end

function SceneObject:AOIQueryPuppet(selector)
	local pos = self:GetPosition()
	if pos then
		return self:GetEntityManager().AOIQueryPuppet(self:GetSceneID(), pos.x, pos.z, selector)
	end
end

function SceneObject:AOIQueryPuppets(selector)
	local pos = self:GetPosition()
	if pos then
		return self:GetEntityManager().AOIQueryPuppets(self:GetSceneID(), pos.x, pos.z, selector)
	else
		return {}
	end
end

function SceneObject:GetChapterScheme()
	return self:GetTriggersManager().scheme
end

return SceneObject
