#include "GameLuaModule.h"

#include "GameLuaFunction.h"

#include "DBLuaFunction.h"
#include "luaproxyfunction.h"
#include "GameManagerClientModule.h"



GameLuaModule::GameLuaModule():m_nTimerID(0)
{
}


GameLuaModule::~GameLuaModule()
{

}

bool GameLuaModule::Init(std::string luaPath)
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

	//CTimerMgr::Instance()->CreateTimer(0, this, &GameLuaModule::Tick, 300, 300);
	return true;
}

bool GameLuaModule::RegisterFunction()
{
	luaopen_gamefunction(LuaModule::Instance()->GetLuaState());

	luaopen_proxyfunction(LuaModule::Instance()->GetLuaState());

	luaopen_dbfunc(LuaModule::Instance()->GetLuaState());

	luaopen_gamemanagerfunction(LuaModule::Instance()->GetLuaState());

	if (!GlobalGameServerModule->RegisterEntityMethodCallback(CLIENT_MESSAGE_LUA_MESSAGE, this, &GameLuaModule::OnEntityLuaMessage))
	{
		return false;
	}
	return true;
}

//初始化成功之后需要处理的一些事情
bool GameLuaModule::AfterInit()
{	
	CLuaParam input[2];
	input[0] = GlobalGameServer->GetServerName();
	input[1] = GlobalGameServer->GetConfigPath();
	if (!LuaModule::Instance()->RunFunction("OnServerStart", input, 2, nullptr, 0))
	{
		return false;
	}
	return true;
}

void GameLuaModule::Tick(int tid)
{
	LuaModule::Instance()->RunFunction("Tick", nullptr, 0, nullptr, 0);
}

void GameLuaModule::OnEntityLuaMessage(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength)
{
		CS_Lua_RunRequest request;
		if (!request.ParseFromArray(message, messageLength))
		{
			_xerror("CLuaModule::OnPlayerRequest request ParseFromArray error");
			return;
		}

		CLuaParam input[3];
		input[0] = clientSessionID;
		input[1] = request.opcode();
		input[2] = request.parameters();

		if (!LuaModule::Instance()->RunFunction("OnClientMessage", input, 3, NULL, 0))
		{
			_xerror("Failed OnClientMessage of ClientSessionID %llu and MessageID %d", clientSessionID, request.opcode());
		}
}

int32_t GameLuaModule::GenerateTimerID()
{
	return ++m_nTimerID;
}



