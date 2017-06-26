--region *.lua
--Date
--此文件由[BabeLua]插件自动生成



--endregion

local entity_manager = {}

local function addentity(entityid, entity)
    if entity_manager[entityid] == nil then
        _warn("The entity to add is exist and will be override")
    end
    entity_manager[entityid] = entity
end

local function delentity(entityid)
    if entity_manager[entityid] == nil then
        _warn("The entity to del is not exist")
    end
    entity_manager[entityid] = nil    
end

local function getentity(entityid)
    return entity_manager[entityid]
end

return {
    addentity = addentity,
    delentity = delentity,
    getentity = getentity,
}