#ifndef __GATE_LUA_FUNCTION_H__
#define __GATE_LUA_FUNCTION_H__

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}
#include "IGateServer.h"
#include "bson.h"
#include <string>
#include "message/LuaMessage.pb.h"

static int lua_get_server_id(lua_State *L)
{
	SERVERID serverID = GlobalGateServer->GetServerID();
	lua_pushnumber(L, serverID);
	return 1;
}


// send_message
static int lua_send_message_to_client(lua_State *L)
{
	SESSIONID clientSessionID = static_cast<SESSIONID>(luaL_checknumber(L, 1));
	MESSAGEID msgID = static_cast<MESSAGEID>(luaL_checknumber(L, 2));
	size_t n = 0;
	const char* data = luaL_checklstring(L, 3, &n);

	if (n == 0 || n > 8012)
	{
		_warn("The message to send %d is not satisfiable", n);
		return 0;
	}

	std::string param(data, n);

	SC_Lua_RunRequest reply;
	reply.set_opcode(msgID);
	reply.set_parameters(param);

	std::string data1;
	reply.SerializeToString(&data1);

	GlobalGateServerModule->SendDataToClient(clientSessionID, SERVER_MESSAGE_OPCODE_LUA_MESSAGE, data1.c_str(), data1.length());
	return 0;
}

// send_message
static int lua_send_message_to_game(lua_State *L)
{
	SERVERID serverid = static_cast<SERVERID>(luaL_checknumber(L, 1));
	MESSAGEID msgID = static_cast<MESSAGEID>(luaL_checknumber(L, 2));
	size_t n = 0;
	const char* data = luaL_checklstring(L, 3, &n);

	if (n == 0 || n > 8012)
	{
		_warn("The message to send %d is not satisfiable", n);
		return 0;
	}

	std::string param(data, n);

	SC_Lua_RunRequest reply;
	reply.set_opcode(msgID);
	reply.set_parameters(param);

	std::string data1;
	reply.SerializeToString(&data1);

	GlobalGameClientModule->SendDataToGameServer(serverid, game::GAMESERVICE_FIGHT_MESSAGE, data1.c_str(), data1.length());
	return 0;
}

static int lua_fight_ready_close(lua_State *L)
{
	_info("FightServer Lua Ready Close");
	GlobalGateServer->SetServerState(SERVER_STATE_FINISH);
	return 0;
}

extern "C" void luaopen_fightfunc(lua_State* L)
{
	lua_register(L, "_send_to_client", lua_send_message_to_client);
	lua_register(L, "_send_to_game", lua_send_message_to_game);

	lua_register(L, "objectid", lobjectid);
	lua_register(L, "_bson_encode", lencode);
	lua_register(L, "_bson_decode", ldecode);

	lua_register(L, "_get_serverid", lua_get_server_id);
	lua_register(L, "_fight_ready_close", lua_fight_ready_close);
}








#endif