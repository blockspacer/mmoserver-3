#pragma once
#ifndef _LUA_PROXY_FUNCTION_H_
#define _LUA_PROXY_FUNCTION_H_

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

#include "IProxyModuel.h"
#include "message/LuaMessage.pb.h"
#include "AOIProxy.h"
#include "AOIScene.h"
#include "math3d/types.h"

// 创建一个AOI场景
static int lua_create_aoi_scene(lua_State *L)
{
	uint32_t sceneID = static_cast<uint32_t>(luaL_checknumber(L, 1));
	uint32_t radius = static_cast<uint32_t>(luaL_checknumber(L, 2));

	float minX = static_cast<float>(luaL_checknumber(L, 3));
	float maxX = static_cast<float>(luaL_checknumber(L, 4));

	float minZ = static_cast<float>(luaL_checknumber(L, 5));
	float maxZ = static_cast<float>(luaL_checknumber(L, 6));

	size_t len;
	const char* data = luaL_checklstring(L, 7, &len);
	std::string mapName(data, len);

	bool ret = GlobalProxyModule->AddAOIScene(sceneID, radius, minX, maxX, minZ, maxZ, mapName);
	if (!ret)
	{
		_xerror("Failed Create AOIScene %d Map %s", sceneID, mapName.c_str());
		//assert(false);
	}
	lua_pushboolean(L, ret);
	return 1;
}

// 创建一个副本场景
static int lua_create_dungeon_scene(lua_State *L)
{
	uint32_t sceneID = static_cast<uint32_t>(luaL_checknumber(L, 1));

	size_t len;
	const char* data = luaL_checklstring(L, 2, &len);
	std::string mapName(data, len);

	bool ret = GlobalProxyModule->CreateDungeonScene(sceneID, mapName);
	if (!ret)
	{
		_xerror("Failed CreateDungeonScene ID %d and MapName %s", sceneID, mapName.c_str());
	}
	lua_pushboolean(L, ret);
	return 1;
}

// 销毁一个AOI场景
static int lua_destroy_aoi_scene(lua_State *L)
{
	uint32_t sceneID = static_cast<uint32_t>(luaL_checknumber(L, 1));

	GlobalProxyModule->DestroyAOIScene(sceneID);
	return 0;
}

// 获取一个AOIProxy，需要视野管理的entity都需要绑定一个对应的AOIProxy
static int lua_create_aoi_proxy(lua_State *L)
{
	size_t en;
	ENTITYID entityID = luaL_checklstring(L, 1, &en); //entityID
	if (entityID.size() != en)
	{
		_xerror("字符串截断，在objectid不应该发生");
		lua_pushnumber(L, -1);
		return 1;
	}
	uint32_t entityType = static_cast<uint32_t>(luaL_checknumber(L,2));
	if (entityType <= ENTITY_TYPE_INVALID )
	{
		_xerror("entityType %d is wrong", entityType);
		lua_pushnumber(L, INVALID_PROXY_ID);
		return 1;
	}

	size_t n;
	const char* data = luaL_checklstring(L, 3, &n);
	
	SESSIONID clientSession = static_cast<uint64_t>(luaL_checknumber(L, 4));

	std::string entityInfo(data, n);

	float speed = static_cast<float>(luaL_checknumber(L, 5));

	uint32_t viewRadius = static_cast<uint32_t>(luaL_checknumber(L, 6));

	ProxyID proxyID = GlobalProxyModule->CreateAOIProxy(entityID, entityType, entityInfo, clientSession, viewRadius, speed);
	lua_pushnumber(L, proxyID);
	return 1;
}


// 销毁一个AOIProxy，entity死亡或者下线之后会解除绑定
static int lua_destroy_aoi_proxy(lua_State *L)
{
	ProxyID pid = static_cast<ProxyID>(luaL_checknumber(L, 1));
	std::shared_ptr<AOIProxy> proxy = GlobalProxyModule->GetAOIProxy(pid);
	if (!proxy)
	{
		return 0;
	}

#ifdef _DEBUG
	std::shared_ptr<IScene> scene = proxy->GetScene();
	if (scene)
	{
		_xerror("proxy not in Scene" );
		//assert("false");
		return 0;
	}
#endif // _DEBUG

	// 销毁前确保已经离开场景
	proxy->LeaveScene();
	// 从全局proxy中去掉
	GlobalProxyModule->DestroyAOIProxy(pid);
	return 0;
}

// entity进入一个场景，会将AOIProxy加入到AOIScene中进行管理
static int lua_enter_scene(lua_State *L)
{
 	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	uint32_t sceneID = static_cast<uint32_t>(luaL_checknumber(L, 2));
	Point3D pos;
	pos.x = static_cast<float>(luaL_checknumber(L, 3));
	pos.y = static_cast<float>(luaL_checknumber(L, 4));
	pos.z = static_cast<float>(luaL_checknumber(L, 5));
	std::shared_ptr<AOIProxy> proxy = GlobalProxyModule->GetAOIProxy(proxyID);
	if (!proxy)
	{
		_xerror("Failed find proxy %d to enter scene %d", proxyID, sceneID);
		//assert(false);
		lua_pushboolean(L, false);
		return 1;
	}

	std::shared_ptr<IScene> scene = GlobalProxyModule->GetScene(sceneID);
	if (!scene)
	{
		_xerror("Failed find scene %d to enter", sceneID);
		//assert(false);
		lua_pushboolean(L, false);
		return 1;
	}
	bool ret = proxy->EnterScene(scene, pos);
	//bool ret = scene->OnEnter(proxy, pos);
	if (!ret)
	{
		_warn("Failed lua_enter_scene");
	}
	lua_pushboolean(L, ret);
	return 1;
}

// entity离开一个场景
static int lua_leave_scene(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	//uint32_t sceneID = static_cast<uint32_t>(luaL_checknumber(L, 2));
	std::shared_ptr<AOIProxy> proxy = GlobalProxyModule->GetAOIProxy(proxyID);
	if (!proxy)
	{
		_xerror("Failed find Proxy %d", proxyID);
		//assert(false);
		lua_pushboolean(L, false);
		return 1;
	}
	proxy->LeaveScene();
	lua_pushboolean(L, true);
	return 1;
}

// 设置AOI速度
static int lua_set_proxy_speed(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	float speed = static_cast<float>(luaL_checknumber(L, 2));
	IProxyModule* aoi = GlobalProxyModule;
	std::shared_ptr<AOIProxy> p = aoi->GetAOIProxy(proxyID);
	if (!p)
	{
		_warn("Wrong proxyid %d in lua_set_proxy_speed", proxyID);
		//assert(false);
		return 0;
	}
	p->SetSpeed(speed);
	return 0;
}

// 获取entity当前位置
static int lua_get_pos(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	IProxyModule* aoi = GlobalProxyModule;
	std::shared_ptr<AOIProxy> p = aoi->GetAOIProxy(proxyID);
	if (!p)
	{
		return 0;
	}
	if (p->EntityType() == ENTITY_TYPE_HERO && p->GetStatus() == ProxyStatusMove)
	{
		Point3D pos = p->GetPosition();
		uint64_t posTime = p->GetPositionTime();
		uint64_t now = GetNowTimeMille();
		if (posTime + 100 < now)
		{
			uint64_t delta = now - posTime;
			if (delta > 4000)
			{
				// 最多预测4s
				delta = 4000;
			}
			float rotate = p->GetDirection();
			auto deltaZ = (delta * (p->GetSpeed()) * sinf(rotate * Py_MATH_PI / 180)) / 100000;
			auto deltaX = (delta * (p->GetSpeed()) * cosf(rotate * Py_MATH_PI / 180)) / 100000;
			lua_pushnumber(L, pos.x + deltaX);
			lua_pushnumber(L, pos.y);
			lua_pushnumber(L, pos.z + deltaZ);
			return 3;
		}
	}
		Point3D pos = p->GetPosition();
		lua_pushnumber(L, pos.x);
		lua_pushnumber(L, pos.y);
		lua_pushnumber(L, pos.z);

	return 3;
}

// 设置entity当前位置
static int lua_set_pos(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	float x = static_cast<float>(luaL_checknumber(L, 2));
	float y = static_cast<float>(luaL_checknumber(L, 3));
	float z = static_cast<float>(luaL_checknumber(L, 4));
	IProxyModule* aoi = GlobalProxyModule;
	std::shared_ptr<AOIProxy> p = aoi->GetAOIProxy(proxyID);
	if (!p)
	{
		return 0;
	}
	
	Point3D a(x, y, z);
	p->ForcePostion(a);
	return 0;
}

// 获取entity当前朝向
static int lua_get_rotation(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	IProxyModule* aoi = GlobalProxyModule;
	std::shared_ptr<AOIProxy> p = aoi->GetAOIProxy(proxyID);
	if (p == nullptr)
	{
		return 0;
	}
	float rotation = p->GetDirection();
	lua_pushnumber(L, rotation);
	return 1;
}

// 设置entity当前朝向
static int lua_set_rotation(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	float rotation = static_cast<float>(luaL_checknumber(L, 2));
	IProxyModule* aoi = GlobalProxyModule;
	std::shared_ptr<AOIProxy> p = aoi->GetAOIProxy(proxyID);
	if (p == nullptr)
	{
		return 0;
	}
	p->SetDirection(rotation);
	p->BroadcastTurnDirectionMessage();
	return 0;
}

// 移动到某点
static int lua_move_to(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	float x = static_cast<float>(luaL_checknumber(L, 2));
	float y = static_cast<float>(luaL_checknumber(L, 3));
	float z = static_cast<float>(luaL_checknumber(L, 4));
	std::shared_ptr<AOIProxy> p = GlobalProxyModule->GetAOIProxy(proxyID);
	if (!p)
	{
		lua_pushboolean(L, false);
		return 1;
	}
	Point3D destPosition(x, y, z);
	Point3D outPosition;

	bool ret = p->WalkTo(destPosition, outPosition);
	if (!ret)
	{
		int a = 1;
	}
	lua_pushboolean(L, ret);
	return 1;
}

// 移动到某点
static int lua_move_to_directly(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	float x = static_cast<float>(luaL_checknumber(L, 2));
	float y = static_cast<float>(luaL_checknumber(L, 3));
	float z = static_cast<float>(luaL_checknumber(L, 4));
	std::shared_ptr<AOIProxy> p = GlobalProxyModule->GetAOIProxy(proxyID);
	if (!p)
	{
		lua_pushboolean(L, false);
		return 1;
	}
	Point3D destPosition(x, y, z);
	Point3D outPosition;

	p->MoveToDirectly(destPosition);
	lua_pushboolean(L, true);
	return 1;
}

static int lua_stop_move(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	IProxyModule* aoi = GlobalProxyModule;
	std::shared_ptr<AOIProxy> p = aoi->GetAOIProxy(proxyID);
	if (!p)
	{
		return 0;
	}

	p->StopMove(p->GetPosition(), p->GetDirection());
	return 0;
}

// 修改entity视野可见的数据
static int lua_update_entity_info(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));

	size_t n;
	const char* data = luaL_checklstring(L, 2, &n);

	std::string entityInfo(n, 0);
	for (size_t i = 0; i < n; i++)
	{
		entityInfo[i] = data[i];
	}
	IProxyModule* aoi = GlobalProxyModule;
	std::shared_ptr<AOIProxy> proxy = aoi->GetAOIProxy(proxyID);
	if (!proxy)
	{
		return 0;
	}
	proxy->UpdateEntityInfo(entityInfo);
	return 0;
}


// 向AOI视野内的对象广播信息
static int lua_broadcast_to_aoi(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	MESSAGEID msgID = static_cast<MESSAGEID>(luaL_checknumber(L, 2));
	size_t n;
	const char* data = luaL_checklstring(L, 3, &n);
	int me_flag = static_cast<MESSAGEID>(luaL_checknumber(L, 4));
	std::string param(data, n);

	SC_Lua_RunRequest reply;
	reply.set_opcode(msgID);
	reply.set_parameters(param);

	std::shared_ptr<AOIProxy> proxy = GlobalProxyModule->GetAOIProxy(proxyID);
	if (!proxy)
	{
		return 0;
	}
	proxy->BroadcastMessageToCareMe(SERVER_MESSAGE_OPCODE_LUA_MESSAGE, &reply);
	if (me_flag)
	{
		proxy->SendMessageToMe(SERVER_MESSAGE_OPCODE_LUA_MESSAGE, &reply);
	}
	return 0;
}


// 获取某点对应的navmesh上的点
static int lua_get_nearest_poly_of_point(lua_State *L)
{
	int sceneID = static_cast<int>(luaL_checknumber(L, 1));
	float x = static_cast<float>(luaL_checknumber(L, 2));
	float y = static_cast<float>(luaL_checknumber(L, 3));
	float z = static_cast<float>(luaL_checknumber(L, 4));
	std::shared_ptr<IScene> scene = GlobalProxyModule->GetScene(sceneID);
	if (!scene)
	{
		_debug("Failed find scene %d to enter", sceneID);
		//assert(false);
		lua_pushboolean(L, false);
		lua_pushnumber(L, x);
		lua_pushnumber(L, y);
		lua_pushnumber(L, z);
		return 4;
	}

	float poly[3] = {0,0,0};
	scene->GetNearestPoly(x,y,z,poly);
	if (poly[0] == 0 && poly[1] == 0 && poly[2] == 0)
	{
		lua_pushboolean(L, false);
		//return 1;
	}
	else
	{
		lua_pushboolean(L, true);
	}

	lua_pushnumber(L, poly[0]);
	lua_pushnumber(L, poly[1]);
	lua_pushnumber(L, poly[2]);
	return 4;
}


static int lua_set_session(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1)); 
	SESSIONID sid = static_cast<SESSIONID>(luaL_checknumber(L, 2));

	std::shared_ptr<AOIProxy> proxy = GlobalProxyModule->GetAOIProxy(proxyID);
	if (!proxy)
	{
		_xerror("Failed find proxy of pid %d", proxyID);
		lua_pushboolean(L, false);
		return 1;
	}
	proxy->SetSessionID(sid);
	lua_pushboolean(L, true);
	return 1;
}

static int lua_is_moving(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));

	std::shared_ptr<AOIProxy> proxy = GlobalProxyModule->GetAOIProxy(proxyID);
	if (!proxy)
	{
		_xerror("Failed find proxy of pid %d", proxyID);
		lua_pushboolean(L, false);
		return 1;
	}
	if (proxy->GetStatus() == ProxyStatusStand)
	{
		lua_pushboolean(L, false);
	}
	else
	{
		lua_pushboolean(L, true);
	}
	
	return 1;
}

static int lua_get_height(lua_State *L)
{
	int sceneID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	float x= static_cast<float>(luaL_checknumber(L, 2));
	float z = static_cast<float>(luaL_checknumber(L, 2));

	std::shared_ptr<IScene> scene = GlobalProxyModule->GetScene(sceneID);
	if (!scene)
	{
		lua_pushboolean(L, false);
		return 1;
	}
	float height;
	if (!scene->GetHeight(x, z, height))
	{
		lua_pushboolean(L, false);
		return 1;
	}

	lua_pushboolean(L, true);
	lua_pushnumber(L, height);

	return 2;
}

static int lua_get_entities_of_shape(lua_State *L)
{
	ProxyID proxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	std::shared_ptr<AOIProxy> proxy = GlobalProxyModule->GetAOIProxy(proxyID);
	if (!proxy)
	{
		_xerror("Failed find proxyid %d", proxyID);
		return 0;
	}

	int shapetype = static_cast<int>(luaL_checknumber(L, 2));
	float pos_x = static_cast<float>(luaL_checknumber(L, 2));
	float pos_z = static_cast<float>(luaL_checknumber(L, 3));
	float dir = static_cast<float>(luaL_checknumber(L, 4));
	float arg1 = static_cast<float>(luaL_checknumber(L, 5));
	float arg2 = static_cast<float>(luaL_checknumber(L, 6));

	neox::math3d::Point2F pos(pos_x, pos_z);
	neox::math3d::Point2F dire(tan(dir*Py_MATH_PI /180)*100, 100);
	neox::h12map::Shape *shape = neox::h12map::GenerateShape(shapetype, pos, dire, arg1, arg2);
	if (!shape)
	{
		_xerror("Failed Generate shape of shapeType %d", shapetype);
		return 0;
	}
	std::shared_ptr<IScene> scene = proxy->GetScene();
	if (!scene)
	{
		_xerror("Proxy %d not in scene ", proxyID);
		return 0;
	}

	ProxyIDSet out;
	scene->GetEntitiesInShape(shape, 0xffffffff, proxyID, &out);

	lua_newtable(L);
	int n = 1;
	for (auto it = out.begin(); it != out.end(); ++it)
	{
		lua_pushnumber(L, *it);
		lua_rawseti(L, -2, n++);
	}
	
	return 1;
}

static int lua_get_entities_of_aoi(lua_State *L)
{
	int sceneID = luaL_checknumber(L, 1);
	float pos_x = static_cast<float>(luaL_checknumber(L, 2));
	float pos_z = static_cast<float>(luaL_checknumber(L, 3));
	int radius = luaL_checknumber(L, 4);

	std::shared_ptr<IScene> scene = GlobalProxyModule->GetScene(sceneID);
	if (!scene)
	{
		_xerror("Scene %d not exist ", scene);
		return 0;
	}

	//ProxyIDSet out;
	//scene->ExportAOIProxy(Point3D(pos_x, 0, pos_z), radius, 0xffffffff, &out);
	//std::set<ENTITYID> entityset;
	//scene->GetAllAOIProxy(Point3D(pos_x, 0, pos_z), radius, 0xffffffff, entityset);
	//for (auto it = out.begin(); it != out.end(); ++it)
	//{
	//	AOIProxy* proxy = GlobalProxyModule->GetAOIProxy(*it);
	//	if (!proxy)
	//	{
	//		_warn("Failed find proxy in scene %d", sceneID);
	//		continue;
	//	}
	//	entityset.insert(proxy->EntityID());
	//}
	
	//lua_newtable(L);

	ProxyIDSet entityset;
	scene->ExportAOIProxy(Point3D(pos_x, 0, pos_z), radius, 0xffffffff, &entityset);

	lua_createtable(L, entityset.size(), 0);
	int n = 1;
	for (auto itt = entityset.begin(); itt != entityset.end(); ++itt)
	{
		//lua_pushstring(L, (*itt).c_str());
		lua_pushnumber(L, *itt);
		lua_rawseti(L, -2, n);
		n ++ ;
	}
	//_trace("The AOI count %d and Scene count %d", entityset.size(), scene->GetSceneProxyCount());
	return 1;
}

static int lua_suspend_dungeon(lua_State *L)
{
	int sceneID = static_cast<int>(luaL_checknumber(L, 1));

	std::shared_ptr<IScene> scene = GlobalProxyModule->GetScene(sceneID);
	if (!scene)
	{
		lua_pushboolean(L, false);
		return 1;
	}

	scene->SetSuspendState(true);
	lua_pushboolean(L, true);
	return 1;
}

static int lua_recover_dungeon(lua_State *L)
{
	int sceneID = static_cast<int>(luaL_checknumber(L, 1));

	std::shared_ptr<IScene> scene = GlobalProxyModule->GetScene(sceneID);
	if (!scene)
	{
		lua_pushboolean(L, false);
		return 1;
	}

	scene->SetSuspendState(false);
	lua_pushboolean(L, true);
	return 1;
}

static int lua_add_to_insight(lua_State *L)
{
	ProxyID meProxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	std::shared_ptr<AOIProxy> meProxy = GlobalProxyModule->GetAOIProxy(meProxyID);
	if (!meProxy)
	{
		_xerror("Failed find proxyid %d", meProxy);
		lua_pushboolean(L, false);
		return 1;
	}

	ProxyID otherProxyID = static_cast<ProxyID>(luaL_checknumber(L, 2));
	std::shared_ptr<AOIProxy> otherProxy = GlobalProxyModule->GetAOIProxy(otherProxyID);
	if (!otherProxy)
	{
		_xerror("Failed find proxyid %d", otherProxy);
		lua_pushboolean(L, false);
		return 1;
	}

	meProxy->AddToInsightEntities(otherProxyID);
	lua_pushboolean(L, true);
	return 1;
}

static int lua_remove_from_insight(lua_State *L)
{
	ProxyID meProxyID = static_cast<ProxyID>(luaL_checknumber(L, 1));
	std::shared_ptr<AOIProxy> meProxy = GlobalProxyModule->GetAOIProxy(meProxyID);
	if (!meProxy)
	{
		_xerror("Failed find proxyid %d", meProxy);
		lua_pushboolean(L, false);
		return 1;
	}

	ProxyID otherProxyID = static_cast<ProxyID>(luaL_checknumber(L, 2));
	std::shared_ptr<AOIProxy> otherProxy = GlobalProxyModule->GetAOIProxy(otherProxyID);
	if (!otherProxy)
	{
		_xerror("Failed find proxyid %d", otherProxy);
		lua_pushboolean(L, false);
		return 1;
	}

	meProxy->DeleteFromInsightEntities(otherProxyID);
	lua_pushboolean(L, true);
	return 1;
}

extern "C" void luaopen_proxyfunction(lua_State* L)
{
	lua_register(L, "_create_aoi_scene", lua_create_aoi_scene);
	lua_register(L, "_create_dungeon_scene", lua_create_dungeon_scene);
	lua_register(L, "_destroy_aoi_scene", lua_destroy_aoi_scene);

	lua_register(L, "_create_aoi_proxy", lua_create_aoi_proxy);
	lua_register(L, "_set_speed", lua_set_proxy_speed);
	lua_register(L, "_destroy_aoi_proxy", lua_destroy_aoi_proxy);
	lua_register(L, "_enter_aoi_scene", lua_enter_scene);
	lua_register(L, "_leave_aoi_scene", lua_leave_scene);
	lua_register(L, "_get_pos", lua_get_pos);
	lua_register(L, "_set_pos", lua_set_pos);
	lua_register(L, "_get_rotation", lua_get_rotation);
	lua_register(L, "_set_rotation", lua_set_rotation);
	lua_register(L, "_move_to", lua_move_to);
	lua_register(L, "_move_to_directly", lua_move_to_directly);
	lua_register(L, "_stop_move", lua_stop_move);
	lua_register(L, "_update_entity_info", lua_update_entity_info);
	lua_register(L, "_broadcast_to_aoi", lua_broadcast_to_aoi);
	lua_register(L, "_get_nearest_poly_of_point", lua_get_nearest_poly_of_point);
	lua_register(L, "_set_session", lua_set_session);
	lua_register(L, "_is_moving", lua_is_moving);
	lua_register(L, "_get_entities_of_shape", lua_get_entities_of_shape);
	lua_register(L, "_get_height", lua_get_height);
	lua_register(L, "_suspend_dungeon", lua_suspend_dungeon);
	lua_register(L, "_recover_dungeon", lua_recover_dungeon);
	lua_register(L, "_add_to_insight", lua_add_to_insight);
	lua_register(L, "_remove_from_insight", lua_remove_from_insight);
	lua_register(L, "_get_entities_in_aoi", lua_get_entities_of_aoi);
}
#endif // !_LUA_PROXY_FUNCTION_H_
