#include "GameServer.h"
#include "LogModule.h"
#include <thread>
#include "timemeter.h"
#include "message/servermessage.pb.h"
#include "message/LuaMessage.pb.h"
#include "GameManagerClientModule.h"

bool GameServer::Init(std::string configPath)
{
	m_configPath = configPath;
	m_now = GetNowTimeMille();

	if (!ServerConfigure::Instance()->Init(m_configPath))
	{
		_xerror("Failed Init ServerConfig");
		return false;
	}
	m_serverID = ServerConfigure::Instance()->GetServerID(m_serverName);
	if (!m_serverID)
	{
		_xerror("Failed find serverID of serverName %s", m_serverName.c_str());
		return false;
	}
	auto config = ServerConfigure::Instance()->GetServerHolder(m_serverID, SERVER_TYPE_GAME);
	if (!config)
	{
		_xerror("Failed find Config of serverName %s", m_serverName.c_str());
		return false;
	}

	// 创建并初始化所有Module
	if (!m_logModule.Init(config->logFilePath, config->logLevel))
	{
		assert(false);
		return false;
	}
	SetLogListen(&m_logModule);

	if (!m_gameServerModule.Init(8000, config->listenPort))
	{
		_xerror("failed init game server net modules");
		return false;
	}

	if (!m_telnet.Initialization(m_serverName, 100, config->consolePort))
	{
		_xerror("Failed Init Telnet");
		return false;
	}
	m_telnet.RegisterConsoleHandler(this, &GameServer::ConsoleHandler);

	if (!m_gamemanagerClient.Init(m_serverID))
	{
		_xerror("failed init gamemanager client");
		return false;
	}

	if (!m_gamemanagerClient.RegisterServerMethodCallback(gamemanager::GAMEMANAGER_CLIENT_RUN_SCRIPT, this, &GameServer::OnRunScript))
	{
		_xerror("Failed Register OnRunScript %d", gamemanager::GAMEMANAGER_CLIENT_RUN_SCRIPT);
		return false;
	}

	if (!m_gamemanagerClient.RegisterServerMethodCallback(gamemanager::GAMEMANAGER_CLIENT_ALL_GAME_INFO, this, &GameServer::OnUpdateGameServerInfo))
	{
		_xerror("Failed Register OnUpdateGameServerInfo %d", gamemanager::GAMEMANAGER_CLIENT_ALL_GAME_INFO);
		return false;
	}

	if (!m_gamemanagerClient.RegisterServerMethodCallback(gamemanager::GAMEMANAGER_CLIENT_FORWARD_GAME_MESSAGE, &m_gameServerModule, &GameServerModule::OnTranspondMessage))
	{
		_xerror("Failed Register OnUpdateGameServerInfo %d", gamemanager::GAMEMANAGER_CLIENT_FORWARD_GAME_MESSAGE);
		return false;
	}
	
	if (!m_dbClientModule.Init())
	{
		_xerror("failed init db client net modules");
		return false;
	}

	if (!InitAOIModule())
	{
		return false;
	}


	if (!m_gameLuaModule.Init(config->luaPath))
	{
		assert(false);
		return false;
	}	

	_info("GameServer Init success");

	m_IsWorking = true;
	return true;
}

std::string GameServer::GetConfigPath()
{
	return m_configPath;
}

bool GameServer::CheckServerStart()
{
	return false;
}



bool GameServer::Tick()
{
	// 超过10ms运行时间的记录下来
	TimeMeter tm(25);

	tm.Stamp();
	m_gameServerModule.Tick();
	tm.Stamp("Server");

	m_dbClientModule.Tick();
	tm.Stamp("DB");

	m_gamemanagerClient.Tick();
	tm.Stamp("GM");

	m_AOIModule.Tick(0);
	tm.Stamp("AOI");

	CTimerMgr::Instance()->Tick();
	tm.Stamp("Timer");

	m_telnet.Tick();
	tm.Stamp("Telnet");

	tm.Check(MSG_MARK, "game");

	uint64_t endTime = GetNowTimeMille();

	uint64_t timerTime = CTimerMgr::Instance()->GetLatestTimerTime();

	//if (timerTime > endTime && (timerTime - endTime) < 7)
	//{
	//	// 到最近定时器出发不足10ms的
	//	std::this_thread::sleep_for(std::chrono::milliseconds(5));
	//}
	//else
	//{
	//	// 最多睡10ms
	//	std::this_thread::sleep_for(std::chrono::milliseconds(10));
	//}
	
	return true;
}

bool GameServer::InitClient()
{
	if (!m_gamemanagerClient.IsReady())
	{
		m_gamemanagerClient.Tick();
	}

	if (!m_dbClientModule.IsReady())
	{
		m_dbClientModule.Tick();
	}
	
	if (m_dbClientModule.IsReady() && m_gamemanagerClient.IsReady())
	{
		_info("DBClient and GameManagerClient is connected")
		SetServerState(SERVER_STATE_INIT);
	}
	else
	{
		std::this_thread::sleep_for(std::chrono::milliseconds(50));
	}
	
	return true;
}

bool GameServer::OnServerStart()
{
	if (!m_gameLuaModule.AfterInit())
	{
		_xerror("Failed GameLuaModule AfterInit");
		assert(false);
		OnServerStop();
		return false;
	}
	SetServerState(SERVER_STATE_RUN);
	return true;
}

bool GameServer::Run()
{
	uint64_t start = GetNowTimeMille();
	switch (m_serverState)
	{
	case SERVER_STATE_CREATE:
		InitClient();
		break;
	case SERVER_STATE_INIT:
		OnServerStart();
		break;
	case SERVER_STATE_RUN:
		Tick();
		break;
	case SERVER_STATE_STOP:
		OnServerStop();
		break;
	case SERVER_STATE_STOPING:
		_warn("SERVER_STATE_STOPING Tick");
		Tick();
		break;
	case SERVER_STATE_FINISH:
		// Tick for send before message
		_warn("SERVER_STATE_FINISH Tick");
		Tick();
		Tick();
		OnServerClose();
		break;
	default:
		break;
	}

	std::this_thread::sleep_for(std::chrono::milliseconds(1));
	return true;
}

bool GameServer::OnServerStop()
{
	if (!LuaModule::Instance()->RunFunction("OnServerStop", nullptr, 0, nullptr, 0))
	{
		_xerror("Failed Call OnServerStop");
		SetServerState(SERVER_STATE_FINISH);
		return false;
	}
	SetServerState(SERVER_STATE_STOPING);
	return true;
}

bool GameServer::OnServerClose()
{
	_info("Server Close");
	m_IsWorking = false;
	return true;
}

ILogModule * GameServer::GetLogModule()
{
	return &m_logModule;
}

IGameServerModule * GameServer::GetGameServerModule()
{
	return &m_gameServerModule;
}

IDBClientModule * GameServer::GetDBClientModule()
{
	return &m_dbClientModule;
}

IProxyModule * GameServer::GetAOIModule()
{
	return &m_AOIModule;
}

int GameServer::GetServerState()
{
	return m_serverState;
}

void GameServer::SetServerState(int state)
{
	if (m_serverState < state)
	{
		_info("GameServer State from  %d to %d ", m_serverState, state);
		m_serverState = state;
	}
}

bool GameServer::InitAOIModule()
{
	if (!m_AOIModule.Init())
	{
		_xerror("Failed Init ProxyModule");
		return false;
	}

	if (!GlobalGameServerModule->RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_MOVE, dynamic_cast<ProxyModule*>(&m_AOIModule), &ProxyModule::EntityMove))
	{
		return false;
	}
	if (!GlobalGameServerModule->RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_STOP_MOVE, dynamic_cast<ProxyModule*>(&m_AOIModule), &ProxyModule::EntityStopMove))
	{
		return false;
	}
	if (!GlobalGameServerModule->RegisterEntityMethodCallback(CLIENT_MESSAGE_FORCE_POSITION, dynamic_cast<ProxyModule*>(&m_AOIModule), &ProxyModule::EntityForceMove))
	{
		return false;
	}
	if (!GlobalGameServerModule->RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_TURN_DIRECTION, dynamic_cast<ProxyModule*>(&m_AOIModule), &ProxyModule::EntityTurnDirection))
	{
		return false;
	}
	if (!GlobalGameServerModule->RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_PING, dynamic_cast<ProxyModule*>(&m_AOIModule), &ProxyModule::ProcessPing))
	{
		return false;
	}
	if (!GlobalGameServerModule->RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_PING_BACK, dynamic_cast<ProxyModule*>(&m_AOIModule), &ProxyModule::ProcessPingBack))
	{
		return false;
	}

	SetGlobalProxyModuel(&m_AOIModule);
	return true;
}

std::string GameServer::GetServerName()
{
	return m_serverName;
}

GameLuaModule * GameServer::GetGameLuaModuel()
{
	return &m_gameLuaModule;
}

SERVERID GameServer::GetServerID()
{
	return m_serverID;
}

bool GameServer::IsWorking()
{
	return m_IsWorking;
}

void GameServer::ConsoleHandler(const int sock, const char* data, const DATA_LENGTH_TYPE dataLength)
{
	std::string command(data, dataLength);
	if (command == "cmd_test")
	{
		_info("Test cmd_test");
	}
	if (command == "cmd_test_gate_connection")
	{
		_info("cmd_test_gate_connection");
		TestPing message;
		message.set_time(GetNowTimeMille());
		m_gameServerModule.BroadcastMessageToGate(game::GAMECLIENT_PING_GATE, 0, &message);
	}
	if (command == "cmd_test_db_connection")
	{
		_info("cmd_test_db_connection");

	}
	if (command == "cmd_test_gamemanager_connection")
	{
		_info("cmd_test_gamemanager_connection");

	}
	else
	{
		_xerror("Unknown Command %s",data);
	}
}

void GameServer::OnRunScript(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength)
{
	LUA_SCRIPT message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse LUA_SCRIPT");
		return;
	}

	std::string err;
	if (!LuaModule::Instance()->RunMemory(message.script_content().c_str(), message.script_content().length(), err))
	{
		_xerror("Failed RunMemory %s", message.script_content().c_str());
		return;
	}
}

//void GameServer::OnRunGMLuaMessage(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
//{
//	GMMessageHead* gmhead = (GMMessageHead*)data;
//
//	CS_Lua_RunRequest message;
//	if (!message.ParseFromArray(data + GM_MESSAGE_HEAD_LENGTH, dataLength - GM_MESSAGE_HEAD_LENGTH))
//	{
//		_xerror("Failed Parse CS_Lua_RunRequest");
//		return;
//	}
//
//	CLuaParam input[3];
//	input[0] = gmhead->AdminSock;
//	input[1] = message.opcode();
//	input[2] = message.parameters();
//
//	// bool ret,  string json
//	CLuaParam output[2];
//
//	if (!LuaModule::Instance()->RunFunction("OnGMMessage", input, 3, output, 2))
//	{
//		_xerror("Failed RunFunction MessageID %d", message.opcode());
//		return;
//	}
//}

void GameServer::OnUpdateGameServerInfo(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength)
{
	GameServerInfos message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse GameServerInfos");
		return;
	}

	//if (message.gameservers().size() == 1)
	//{
	//	if (message.gameservers().begin()->sid() == m_serverID)
	//	{
	//		_debug("return me");
	//		return;
	//	}
	//}

	lua_State* L = LuaModule::Instance()->GetLuaState();
	int top = lua_gettop(L);

	lua_getglobal(L, "OnUpdateGameServerInfo");
	if (!lua_isfunction(L, -1))
	{
		_xerror("Failed call OnUpdateGameServerInfo function because of failed find function");
		lua_settop(L, top);
		return;
	}

	lua_newtable(L);
	int i = 1;
	for (auto it = message.gameservers().begin(); it != message.gameservers().end(); ++it, ++i) {
		SERVERID gameid = it->sid();
		lua_pushnumber(L, i);
		{
			lua_newtable(L);
			lua_pushstring(L, "gameid");
			lua_pushnumber(L, gameid);
			lua_settable(L, -3);
			lua_pushstring(L, "type");
			lua_pushnumber(L, 0);
			lua_settable(L, -3);
		}
		lua_settable(L, -3);
	}

	int ret = lua_pcallwithtraceback(L, 1, 0);
	if (ret)
	{
		const char* pszErrInfor = lua_tostring(L, -1);
		_xerror("Failed call OnUpdateGameServerInfo and reason is %s", pszErrInfor);
		lua_settop(L, top);
	}
}
