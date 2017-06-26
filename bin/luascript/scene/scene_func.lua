--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2016/11/17 0017
-- Time: 18:33
-- To change this template use File | Settings | File Templates.
--

local function create_aoi_scene(sceneID, radius, top_left_x, top_left_z, bottom_right_x, bottom_right_z,detour_name)
    _info("create_aoi_scene,sceneID="..sceneID)
    return _create_aoi_scene(sceneID, radius, top_left_x, top_left_z, bottom_right_x, bottom_right_z,detour_name)
end

local function create_dungeon_scene(sceneID, detour_name)
    _info("create_dungeon_scene,sceneID="..sceneID)
    return _create_dungeon_scene(sceneID, detour_name)
end

local function destroy_aoi_scene(sceneID)
    _info("destroy_aoi_scene sceneID "..sceneID)
    _destroy_aoi_scene(sceneID)
end

local function create_aoi_proxy(entityid, entitytype, entityinfo,session_id,move_speed,viewRadius)
    _trace("create_aoi_proxy,entityid:"..entityid..",entitytype:"..entitytype..",session_id:"..session_id)
    return _create_aoi_proxy(entityid, entitytype, entityinfo,session_id,move_speed,viewRadius)
end

local function destroy_aoi_proxy(proxyid)
    _destroy_aoi_proxy(proxyid)
end

local function enter_aoi_scene(proxyid, sceneid, pos_x,pos_y, pos_z)
    _trace("enter_aoi_scene,sceneid:"..sceneid..",pos_x:"..pos_x..",pos_y:"..pos_y..",pos_z:"..pos_z)
    return _enter_aoi_scene(proxyid, sceneid, pos_x,pos_y, pos_z)
end

local function leave_aoi_scene(proxyid, sceneid)
    _trace("leave_aoi_scene,sceneid:"..sceneid)
    return _leave_aoi_scene(proxyid, sceneid)
end

local function get_pos(proxyid)
    if proxyid == 0 then
        assert(false)
    end
    return _get_pos(proxyid)
end

local function update_entity_info(proxy, entityinfo)
    _update_entity_info(proxy, entityinfo)
end

local function get_rotation(proxyid)
    if proxyid == 0 then
        assert(false)
    end
    return _get_rotation(proxyid)
end

local function set_rotation(proxyid, rotation)
    if proxyid == 0 then
        assert(false)
    end
    return _set_rotation(proxyid,rotation)
end

local function move_to(proxyid,x,y,z)
    if proxyid == 0 then
        assert(false)
    end
    return _move_to(proxyid, x, y ,z)
end

local function move_to_directly(proxyid,x,y,z)
    if proxyid == 0 then
        assert(false)
    end
    return _move_to_directly(proxyid, x, y ,z)
end

local function set_speed(proxyid,speed)
    if proxyid == 0 then
        assert(false)
    end
    _set_speed(proxyid,speed)
end

local function stop_move(proxyid)
    if proxyid == 0 then
        assert(false)
    end
    _stop_move(proxyid)
end

local function is_moving(proxyid)
    if proxyid == 0 then
        assert(false)
    end
    return _is_moving(proxyid)
end


local function set_position(proxyid,x,y,z)
    if proxyid == 0 then
        assert(false)
    end
    _set_pos(proxyid,x,y,z)
end

local function get_now_time_mille()
    return _get_now_time_mille()
end

return {
    create_aoi_scene = create_aoi_scene,
    destroy_aoi_scene = destroy_aoi_scene,
    create_aoi_proxy = create_aoi_proxy,
    destroy_aoi_proxy = destroy_aoi_proxy,
    enter_aoi_scene = enter_aoi_scene,
    leave_aoi_scene = leave_aoi_scene,
    get_pos = get_pos,
    update_entity_info = update_entity_info,
    get_rotation = get_rotation,
    move_to = move_to,
    move_to_directly = move_to_directly,
    set_speed = set_speed,
    set_rotation = set_rotation,
    stop_move = stop_move,
    is_moving = is_moving,
    set_position = set_position,
    get_now_time_mille = get_now_time_mille,
    create_dungeon_scene = create_dungeon_scene,
}
