#include "GateLuaModule.h"
#include "GateLuaFunction.h"
#include <assert.h>
#include "luaproxyfunction.h"
//#include "luaredis.h"

FightLuaModule::FightLuaModule()
{
}

FightLuaModule::~FightLuaModule()
{

}


bool FightLuaModule::Init(std::string luaPath)
{
	if (!LuaModule::Instance()->Init(luaPath))
	{
		return false;
	}
	RegisterFunction();

	if (!LuaModule::Instance()->LoadFile(luaPath.c_str()))
	{
		return false;
	}

	return true;
}

bool FightLuaModule::AfterInit()
{
	CLuaParam input[1];
	input[0] = GlobalGateServer->GetServerName();
	if (!LuaModule::Instance()->RunFunction("OnFightServerStart", input, 1, nullptr, 0))
	{
		return false;
	}
	return true;
}

bool FightLuaModule::RegisterFunction()
{
	luaopen_proxyfunction(LuaModule::Instance()->GetLuaState());
	luaopen_fightfunc(LuaModule::Instance()->GetLuaState());
	//luaopen_redisfunction(LuaModule::Instance()->GetLuaState());
	if (!GlobalGateServerModule->RegisterEntityMethodCallback(CLIENT_MESSAGE_LUA_MESSAGE, this, &FightLuaModule::OnClientLuaMessage))
	{
		return false;
	}

	return true;
}



void FightLuaModule::OnClientLuaMessage(const SESSIONID clientSessionID, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	CS_Lua_RunRequest request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("request ParseFromArray error");
		return;
	}

	CLuaParam input[3];
	input[0] = clientSessionID;
	input[1] = request.opcode();
	input[2] = request.parameters();

	if (!LuaModule::Instance()->RunFunction("OnFightEntityMessage", input, 3, NULL, 0))
	{
		_xerror("RunFunction Error of clientSessionID %llu and MessageID %d", clientSessionID, request.opcode());
	}
}

void FightLuaModule::OnGameServerLuaMessage(const SERVERID gameid, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	CS_Lua_RunRequest request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("request ParseFromArray error");
		return;
	}

	CLuaParam input[3];
	input[0] = gameid;
	input[1] = request.opcode();
	input[2] = request.parameters();

	if (!LuaModule::Instance()->RunFunction("OnGameToFightMessage", input, 3, NULL, 0))
	{
		_xerror("OnGameToFightMessage Error");
	}
}

