#ifndef _ROBOT_LUA_FUNCTION_H_
#define _ROBOT_LUA_FUNCTION_H_

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}
#include "robotmanager.h"
#include "bson.h"
#include "message/servermessage.pb.h"
#include "message/LuaMessage.pb.h"


// forward_message
static int lua_robot_send_message_to_game(lua_State *L)
{
	int  robotID = static_cast<int>(luaL_checknumber(L, 1));
	MESSAGEID msgID = static_cast<MESSAGEID>(luaL_checknumber(L, 2));
	size_t n = 0;
	const char* data = luaL_checklstring(L, 3, &n);

	std::string param(data, n);
	SC_Lua_RunRequest reply;
	reply.set_opcode(msgID);
	reply.set_parameters(param);

	GlobalRobotManager->SendMessageToServer(robotID, CLIENT_MESSAGE_LUA_MESSAGE, &reply);
	return 0;
}

static int lua_set_client_state(lua_State *L)
{
	int robotID = static_cast<int>(luaL_checknumber(L, 1));
	int status = static_cast<int>(luaL_checknumber(L, 2));
	GlobalRobotManager->SetClientStatus(robotID, status);
	return 0;
}

static int lua_get_path(lua_State *L)
{
	int nResourceId = static_cast<int>(luaL_checknumber(L, 1));
	float cx = static_cast<float>(luaL_checknumber(L, 2));
	float cy = static_cast<float>(luaL_checknumber(L, 3));
	float cz = static_cast<float>(luaL_checknumber(L, 4));
	float tx = static_cast<float>(luaL_checknumber(L, 5));
	float ty = static_cast<float>(luaL_checknumber(L, 6));
	float tz = static_cast<float>(luaL_checknumber(L, 7));
	std::vector<float> path;
	GlobalRobotManager->GetPath(nResourceId, cx, cy, cz, tx, ty, tz, path);	
	if (path.size() > 0)
	{
		lua_pushboolean(L,true);
		lua_createtable(L, path.size(),0);
		int i = 1;
		for (std::vector<float>::const_iterator it = path.begin(); it != path.end(); ++it)
		{
			lua_pushnumber(L, *it);
			lua_rawseti(L, -2,i);
			i++;
		}
		return 2;
	}
	else
	{
		lua_pushboolean(L, false);
		return 1;
	}
}

static int lua_init_scene_detour(lua_State *L)
{
	std::vector<int> scenes;
	//ÕýË÷Òý
	int top_index = lua_gettop(L);
	//³õÊ¼key
	lua_pushnil(L);
	while (lua_next(L,top_index))
	{
		scenes.push_back(lua_tointeger(L, -1));
		lua_pop(L, 1);
	}
	GlobalRobotManager->InitScenesDetour(scenes);
	return 0;
}

static int lua_robot_move(lua_State *L)
{
	int nRobotId = luaL_checknumber(L, 1);
	uint32_t nSceneId = luaL_checknumber(L, 2);
	size_t n;
	const char* cEntityId = luaL_checklstring(L, 3,&n);
	std::string strEntityId(cEntityId, n);
	float x = luaL_checknumber(L, 4);
	float y = luaL_checknumber(L, 5);
	float z = luaL_checknumber(L, 6);
	float orientation = luaL_checknumber(L, 7);
	float speed = luaL_checknumber(L,7);
	GlobalRobotManager->RobotMove(nRobotId,nSceneId, cEntityId, x, y, z, orientation, speed);
	return 0;
}

static int lua_sync_time(lua_State *L)
{
	int nRobotId = luaL_checknumber(L, 1);
	GlobalRobotManager->SyncTime(nRobotId);
	return 0;
}

static int lua_send_ping_message(lua_State *L)
{
	int nRobotId = luaL_checknumber(L, 1);
	GlobalRobotManager->SendPingMessage(nRobotId, GetNowTimeMille());
	return 0;
}

static int lua_send_ping_back_message(lua_State *L)
{
	int nRobotId = luaL_checknumber(L, 1);
	long lServerTime = luaL_checknumber(L, 2);
	long lClientTime = luaL_checknumber(L, 3);
	GlobalRobotManager->SendPingBackMessage(nRobotId, lServerTime, lClientTime);
	return 0;
}

static int lua_get_server_time(lua_State *L)
{
	int nRobotId = luaL_checknumber(L, 1);
	lua_pushnumber(L,GlobalRobotManager->GetServerTime(nRobotId));
	return 1;
}

extern "C" void luaopen_robotfunction(lua_State* L)
{
	lua_register(L, "_robot_send_message_to_game", lua_robot_send_message_to_game);
	lua_register(L, "_set_client_state", lua_set_client_state);
	lua_register(L, "objectid", lobjectid);
	lua_register(L, "_get_path", lua_get_path);
	lua_register(L, "_init_scene_detour", lua_init_scene_detour);
	lua_register(L, "_robot_move", lua_robot_move);
	lua_register(L, "_sync_time", lua_sync_time);
	lua_register(L, "_send_ping_message", lua_send_ping_message);
	lua_register(L, "_send_ping_back_message", lua_send_ping_back_message);
	lua_register(L, "_get_server_time", lua_get_server_time);
}

#endif
