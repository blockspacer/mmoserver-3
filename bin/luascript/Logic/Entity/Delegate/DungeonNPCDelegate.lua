---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/13
-- desc： 单位的事件delegate
---------------------------------------------------
local const = require "Common/constant"
local flog = require "basic/log"

local Delegate = require "Logic/Entity/Delegate/Delegate"
local DungeonNPCDelegate = ExtendClass(Delegate)

function DungeonNPCDelegate:__ctor()

end

function DungeonNPCDelegate:OnBorn()
	local owner = self.owner
	local scene = scene_manager.find_scene(self.owner:GetSceneID())
	if scene ~= nil then
		--组队副本根据玩家等级设置怪物等级
		if scene:get_scene_type() == const.SCENE_TYPE.TEAM_DUNGEON then
			local monster_level = scene:get_scene_monster_level()
			if monster_level ~= nil then
				owner:SetLevel(monster_level)
			end
		end
	end
end

return DungeonNPCDelegate

