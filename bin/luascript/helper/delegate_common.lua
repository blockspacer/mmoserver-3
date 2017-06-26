--------------------------------------------------------------------
-- 文件名:	delegate_common.lua
-- 版  权:	(C) 华风软件
-- 创建人:	Shangyz(nmdwgll@gmail.com)
-- 日  期:	2017/5/9 0009
-- 描  述:	delegate中常用函数
--------------------------------------------------------------------
local flog = require "basic/log"

local function get_entity(self, entity_id)
	local scene_id = self.owner:GetSceneID()
	local scene = scene_manager.find_scene(scene_id)
	if scene == nil then
		flog("syzDebug","MonsterDelegate.lua get_entity scene == nil")
		return
	end
	return scene:get_entity(entity_id)
end

local function get_entity_of_owner(self, entity_id)
	local scene_id = self.owner:GetSceneID()
	local scene = scene_manager.find_scene(scene_id)
	if scene == nil then
		flog("syzDebug","MonsterDelegate.lua _get_entity scene == nil")
		return
	end
	local entity = scene:get_entity(entity_id)
	local pet_entity
	if entity ~= nil and entity.on_get_owner ~= nil then
		local owner_entity = entity:on_get_owner()
		if owner_entity ~= nil then
			pet_entity = entity
			entity = owner_entity
		end
	end
	return entity, pet_entity
end

return {
    get_entity = get_entity,
    get_entity_of_owner = get_entity_of_owner,
}