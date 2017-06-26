#ifndef _GAME_LUA_FUNCTION_H_
#define _GAME_LUA_FUNCTION_H_

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

#include "IGameServer.h"
#include "bson.h"
#include "message/servermessage.pb.h"
#include "message/LuaMessage.pb.h"

static int lua_get_server_id(lua_State *L)
{
	SERVERID serverID = GlobalGameServer->GetServerID();
	lua_pushnumber(L, serverID);
	return 1;
}

static int lua_kick_user_offline(lua_State *L)
{
	SESSIONID clientSessionID = static_cast<SESSIONID>(luaL_checknumber(L, 1));

	IGameServerModule* pModule = GlobalGameServerModule;
	if (!pModule)
	{
		_xerror("GlobalGameServerModule is Null");
		return -1;
	}

	pModule->KickOffline(clientSessionID);
	return 0;
}


// send_message
static int lua_send_client_message(lua_State *L)
{
	SESSIONID clientSessionID = static_cast<SESSIONID>(luaL_checknumber(L, 1));
	MESSAGEID msgID = static_cast<MESSAGEID>(luaL_checknumber(L, 2));
	size_t n = 0;
	const char* data = luaL_checklstring(L, 3, &n);

	std::string param(data, n);

	SC_Lua_RunRequest reply;
	reply.set_opcode(msgID);
	reply.set_parameters(param);

	GlobalGameServerModule->SendEntityMessage(clientSessionID, SERVER_MESSAGE_OPCODE_LUA_MESSAGE, &reply);
	return 0;
}

// send_message
static int lua_send_message_to_fight(lua_State *L)
{
	SERVERID serverid = static_cast<SERVERID>(luaL_checknumber(L, 1));
	MESSAGEID msgID = static_cast<MESSAGEID>(luaL_checknumber(L, 2));
	size_t n = 0;
	const char* data = luaL_checklstring(L, 3, &n);

	std::string param(data, n);

	SC_Lua_RunRequest reply;
	reply.set_opcode(msgID);
	reply.set_parameters(param);

	GlobalGameServerModule->SendMessageToFight(serverid, &reply);
	return 0;
}


// send_message
static int lua_broadcast_message(lua_State *L)
{
	MESSAGEID msgID = static_cast<MESSAGEID>(luaL_checknumber(L, 1));
	size_t n = 0;
	const char* data = luaL_checklstring(L, 2, &n);
	std::string param(data, n);

	int country = static_cast<MESSAGEID>(luaL_checknumber(L, 3));

	SC_Lua_RunRequest reply;
	reply.set_opcode(msgID);
	reply.set_parameters(param);

	GlobalGameServerModule->BroadcastMessageToGate(SERVER_MESSAGE_OPCODE_LUA_MESSAGE, country, &reply);
	return 0;
}

// forward_message
static int lua_forward_message_to_game(lua_State *L)
{
	SERVERID  dstServerID = static_cast<SERVERID>(luaL_checknumber(L, 1));
	MESSAGEID msgID = static_cast<MESSAGEID>(luaL_checknumber(L, 2));
	size_t n = 0;
	const char* data = luaL_checklstring(L, 3, &n);
	
	std::string param(data, n);
	SC_Lua_RunRequest reply;
	reply.set_opcode(msgID);
	reply.set_parameters(param);

	GlobalGameServerModule->ForwardMessage(dstServerID, &reply);
	return 0;
}

static int lua_get_fight_serverid(lua_State *L)
{
	int fightType = static_cast<ProxyID>(luaL_checknumber(L, 1));
	SERVERID fid = GlobalGameServerModule->GetFightServerID(fightType);
	if (fid == INVALID_SERVER_ID)
	{
		return 0;
	}
	std::string addr = GlobalGameServerModule->GetConnectedServerIP(fid);
	int port = GlobalGameServerModule->GetConnectedServerPort(fid);
	lua_pushnumber(L, fid);
	lua_pushstring(L, addr.c_str());
	lua_pushnumber(L, port);
	return 3;
}

static int lua_get_table(lua_State *L)
{
	lua_newtable(L);                // lua_newtable create a table and push it to stack
	lua_pushnumber(L, 1); //key
	lua_pushnumber(L, 10); //value
	lua_settable(L, -3); //set value of key
	lua_pushnumber(L, 2);
	lua_pushnumber(L, 20);
	lua_settable(L, -3);
	lua_pushnumber(L, 3);
	lua_pushnumber(L, 30);
	lua_settable(L, -3);
	//lua_setfield(L, -2, "1");
	//lua_pushnumber(L, 0.2);
	//lua_setfield(L, -2, "2");
	//lua_pushnumber(L, 0.3);
	//lua_setfield(L, -2, "3");
	return 1;
}

static int lua_register_service(lua_State *L)
{
	int serviceType = static_cast<int>(luaL_checknumber(L, 1));

	GlobalGameServerModule->RegisterService(serviceType);

	return 0;
}

static int lua_avatar_change_game(lua_State *L)
{
	SESSIONID clientSessionID = static_cast<SESSIONID>(luaL_checknumber(L, 1));

	AvatarChangeGame message;
	message.set_sessionid(clientSessionID);
	message.set_gameid(GlobalGameServer->GetServerID());

	SERVERID gateid = GlobalGameServerModule->GetGateIDBySession(clientSessionID);
	GlobalGameServerModule->SendMessageToServer(gateid, SERVER_OPCODE_AVATAR_CHANGER_GAME, &message);

	return 0;
}

static int lua_avatar_info(lua_State *L)
{
	SESSIONID clientSessionID = static_cast<SESSIONID>(luaL_checknumber(L, 1));
	size_t n = 0;
	const char* data = luaL_checklstring(L, 2, &n);
	std::string entityID(data, n);
	int country = luaL_checknumber(L, 3);
	//int state = luaL_checknumber(L, 4);

	AvatarInfo message;
	message.set_sessionid(clientSessionID);
	message.set_avatarid(entityID);
	message.set_level(country); //TODO 暂时当阵营的字段
	message.set_state(0);

	SERVERID gateid = GlobalGameServerModule->GetGateIDBySession(clientSessionID);
	GlobalGameServerModule->SendMessageToServer(gateid, gate::GATESERVICE_AVATAR_INFO, &message);

	return 0;
}

//static int lua_reconnection_result(lua_State *L)
//{
//	SESSIONID clientSessionID = static_cast<SESSIONID>(luaL_checknumber(L, 1));
//	int ret = luaL_checknumber(L, 2);
//
//	ConnectServerReply message;
//	if (ret)
//	{
//		message.set_type(ConnectServerReply_ReplyType_RECONNECT_SUCCEEDED);
//	}
//	else
//	{
//		message.set_type(ConnectServerReply_ReplyType_RECONNECT_FAILED);
//	}
//	GlobalGameServerModule->SendEntityMessage(clientSessionID, SERVER_MESSAGE_OPCODE_CONNECT_REPLY, &message);
//
//	return 0;
//}

static int lua_user_save_finish(lua_State *L)
{
	_info("UserAllSaved");
	GlobalDBClientModule->SendMessageToDBProxy(0, dbproxy::DBSERVICE_CLOSE_SERVER, nullptr);
	GlobalGameServer->SetServerState(SERVER_STATE_FINISH);
	return 0;
}

extern "C" void luaopen_gamefunction(lua_State* L)
{
	lua_register(L, "_send_to_client", lua_send_client_message);
	lua_register(L, "_send_to_fight", lua_send_message_to_fight);
	lua_register(L, "_forward_message_to_game", lua_forward_message_to_game);
	lua_register(L, "_broadcast_message", lua_broadcast_message);
	lua_register(L, "objectid", lobjectid);
	lua_register(L, "_bson_encode", lencode);
	lua_register(L, "_bson_decode", ldecode);
	lua_register(L, "_kickoffline", lua_kick_user_offline);
	lua_register(L, "_get_serverid", lua_get_server_id);
	lua_register(L, "_get_table", lua_get_table);
	lua_register(L, "_get_fight_id", lua_get_fight_serverid);
	lua_register(L, "_register_service", lua_register_service);
	lua_register(L, "_lua_ready_close", lua_user_save_finish);
	lua_register(L, "_avatar_change_game", lua_avatar_change_game);
	lua_register(L, "_notify_avatar_info", lua_avatar_info);
}

#endif