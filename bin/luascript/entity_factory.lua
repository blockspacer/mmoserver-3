--region *.lua
--Date
--此文件由[BabeLua]插件自动生成



--endregion

local IDManager = require "idmanager"
local entity_factory = {}

local function register_entity(entity_type, create_function)
    --[[if type(create_function) ~= "function" then
        _error("The create_function of entity_type is not function" ..entity_type )
    end]]
    if entity_factory[entity_type] ~= nil then
        _warn("The entitytype to create is exist " .. entity_type)
    end
    entity_factory[entity_type] = create_function
end

local function create_entity(entity_type)
    local entity_function = entity_factory[entity_type]
    if entity_function == nil then
        _error("The class to create is not exist -- " .. entity_type)
        return nil
    end

    local entityID =  IDManager.get_valid_uid()

    return entity_function(entityID)
end


return {
    register_entity =register_entity,
    create_entity = create_entity,
}