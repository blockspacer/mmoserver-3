// GateServer.cpp : 定义控制台应用程序的入口点。
//

#include "GateServer.h"
#include "GameClientModule.h"
#include "BattleProxyModule.h"
#include "FightServerModule.h"
#include "GateServerModule.h"
#include "BaseGateServerModule.h"
#include "timemeter.h"


GateServer::GateServer(std::string servername, int servertype) :m_serverName(servername), m_serverType(servertype), m_serverState(SERVER_STATE_CREATE)
{
	m_gameClientReady = false;
	m_gamemanagerClientReady = false;
	m_forbidNewConnection = false;
	m_ignoreClientMessage = false;
	m_IsWorking = true;
}


GateServer::~GateServer()
{
	
}

bool GateServer::Init(std::string pszConfigPath)
{
	if (!ServerConfigure::Instance()->Init(pszConfigPath))
	{
		assert(false);
		return false;
	}
	m_serverID =  ServerConfigure::Instance()->GetServerID(m_serverName);
	if (m_serverID == INVALID_SERVER_ID)
	{
		_xerror("Failed Find ServerID of ServerName %s", m_serverName.c_str());
		return false;
	}
	std::shared_ptr<ServerHolder> self = ServerConfigure::Instance()->GetServerHolder(m_serverID, m_serverType);
	if (!self)
	{
		_xerror("Failed Find self Config");
		return false;
	}

	if (!m_logModule.Init(self->logFilePath, self->logLevel))
	{
		assert(false);
		return false;
	}
	SetLogListen(&m_logModule);
	_info( "Init LogModule Success");

	if (m_serverType == SERVER_TYPE_GATE)
	{
		m_gateServerModule = new GateServeModule();
	}
	else if (m_serverType == SERVER_TYPE_FIGHT)
	{
		m_gateServerModule = new FightServerModule();
	}
	else
	{
		return false;
	}

	if (!m_gateServerModule || !m_gateServerModule->Init(8000, self->listenPort))
	{
		_xerror("Failed Init GateServerModule");
		assert(false);
		return false;
	}

	if (!m_gameClient.Init())
	{
		_xerror("Failed init game client of gate");
		assert(false);
		return false;
	}

	if (!m_gamemanagerClient.Init(m_serverID))
	{
		_xerror("Failed init game manager client of gate");
		assert(false);
		return false;
	}

	if (!m_gamemanagerClient.RegisterServerMethodCallback(gamemanager::GAMEMANAGER_CLIENT_RUN_SCRIPT, this, &GateServer::OnUpdateGameServerInfo))
	{
		_xerror("Failed Register OnRunScript %d", gamemanager::GAMEMANAGER_CLIENT_RUN_SCRIPT);
		return false;
	}

	return true;
}


bool GateServer::Run()
{
	switch (m_serverState)
	{
	case SERVER_STATE_CREATE:
		return InitClient();
		break;
	case SERVER_STATE_INIT:
		return OnServerState();
		break;
	case SERVER_STATE_RUN:
		return Tick();
		break;
	case SERVER_STATE_STOP:
		return OnServerStop();
		break;
	case SERVER_STATE_STOPING:
		return Tick();
		break;
	case SERVER_STATE_FINISH:
		Tick();
		return OnServerClose();
		break;
	default:
		return false;
	}
	std::this_thread::sleep_for(std::chrono::milliseconds(1));
}

bool GateServer::Tick()
{
	TimeMeter tm(10);

	tm.Stamp();
	bool busy = m_gateServerModule->Tick();
	tm.Stamp("Server");

	busy = m_gameClient.Tick();
	tm.Stamp("Game");

	busy = CTimerMgr::Instance()->Tick();
	tm.Stamp("Timer");
	
	m_gamemanagerClient.Tick();
	tm.Stamp("GM");

	tm.Check(MSG_MARK, "gate");

	return true;
}

bool GateServer::InitClient()
{
	if (m_gameClient.IsReady())
	{
		m_gameClientReady = true;
	}
	else 
	{
		m_gameClient.Tick();
	}
	
	if (m_gamemanagerClient.IsReady())
	{
		m_gamemanagerClientReady = true;
	}
	else
	{
		m_gamemanagerClient.Tick();
	}

	if (m_gameClientReady && m_gamemanagerClientReady)
	{
		SetServerState(SERVER_STATE_INIT);
		return true;
	}
	std::this_thread::sleep_for(std::chrono::milliseconds(500));
	return true;
}

bool GateServer::OnServerState()
{
	m_gateServerModule->AfterInit();
	SetServerState(SERVER_STATE_RUN);
	return true;
}

bool GateServer::OnServerStop()
{
	m_gateServerModule->OnServerStop();
	return true;
}

bool GateServer::OnServerClose()
{
	m_IsWorking = false;
	return true;
}

IGameClientModule* GateServer::GetGameClientModule()
{
	return &m_gameClient;	
}

SERVERID GateServer::GetServerID()
{
	return m_serverID;
}

int GateServer::GetServerType()
{
	return m_serverType;
}

IGateServerModule* GateServer::GetGateServerModule()
{
	return m_gateServerModule;
}

int GateServer::GetServerState()
{
	return m_serverState;
}

void GateServer::SetServerState(int state)
{
	if (m_serverState < state)
	{
		m_serverState = state;
	}
}

std::string GateServer::GetServerName()
{
	return m_serverName;
}

bool GateServer::IsForbidNewConnection()
{
	return m_forbidNewConnection;
}

void GateServer::SetForbidNewConnection(bool isForbid)
{
	m_forbidNewConnection = isForbid;
}

bool GateServer::IsIgnoreClientMessage()
{
	return m_ignoreClientMessage;
}

void GateServer::SetIgnoreClientMessage(bool isIgnore)
{
	m_ignoreClientMessage = isIgnore;
}

bool GateServer::IsWorking()
{
	return m_IsWorking;
}

void GateServer::OnUpdateGameServerInfo(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength)
{
	//GameServerInfos message;
	//if (!message.ParseFromArray(data, dataLength))
	//{
	//	_xerror("Failed Parse GameServerInfos");
	//	return;
	//}
	//for (auto it = message.gameservers().begin(); it != message.gameservers().end(); ++it) {
	//	SERVERID gameid = it->sid();
	//	ConnectData xServerData;
	//	m_gameClientManager.AddServer(xServerData);
	//}
}
