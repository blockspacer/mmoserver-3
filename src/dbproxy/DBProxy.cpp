#include "DBProxy.h"
#include "LogModule.h"
#include <thread>

bool DBProxy::Init(std::string configPath)
{
	if (!ServerConfigure::Instance()->Init(configPath))
	{
		_xerror("Failed Init ServerConfigure");
		assert(!"Failed Init ServerConfigure");
		return false;
	}

	m_serverID = ServerConfigure::Instance()->GetServerID(m_serverName);
	auto config = ServerConfigure::Instance()->GetServerHolder(m_serverID, SERVER_TYPE_DB);
	if (!config)
	{
		_xerror("Failed Find DBConfig");
		assert(!"Failed Find DBConfig");
		return false;
	}

	// 创建并初始化所有Module
	if (!m_logModule.Init(config->logFilePath, config->logLevel))
	{
		assert(false);
		return false;
	}
	SetLogListen(&m_logModule);

	if (!m_gamemanagerClient.Init(m_serverID))
	{
		_xerror("failed init GameManagerClient ");
		return false;
	}

	if (!m_dbServerModule.Init(8000, config->listenPort))
	{
		_xerror("failed init DB Server module");
		return false;
	}

	_info("DBProxy Init");
	m_IsWorking = true;
	m_serverState = SERVER_STATE_CREATE;
	return true;
}

bool DBProxy::Tick()
{
	uint64_t start = GetNowTimeMille();
	bool busy = m_dbServerModule.Tick();

	busy = CTimerMgr::Instance()->Tick();

	m_gamemanagerClient.Tick();
	uint64_t end = GetNowTimeMille();

	return true;
}

void DBProxy::Run()
{
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
		Tick();
		break;
	case SERVER_STATE_FINISH:
		OnServerClose();
		break;
	default:
		break;
	}
	std::this_thread::sleep_for(std::chrono::milliseconds(1));
	return;
}

int32_t DBProxy::GetServerID()
{
	return m_serverID;
}

void DBProxy::SetServerState(int s)
{
	m_serverState = s;
}

void DBProxy::InitClient()
{
	if (m_gamemanagerClient.IsReady())
	{
		_info("GameManagerClient is connected")
		SetServerState(SERVER_STATE_INIT);
	}
	else
	{
		m_gamemanagerClient.Tick();
		std::this_thread::sleep_for(std::chrono::milliseconds(10));
	}
}

void DBProxy::OnServerStart()
{
	SetServerState(SERVER_STATE_RUN);
}

void DBProxy::OnServerStop()
{
	SetServerState(SERVER_STATE_FINISH);
}

void DBProxy::OnServerClose()
{
	m_IsWorking = false;
}

bool DBProxy::IsWorking()
{
	return m_IsWorking;
}
