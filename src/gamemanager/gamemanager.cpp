#include "gamemanager.h"
#include <thread>

bool GameManager::Init(std::string pszConfigPath)
{
	if (!ServerConfigure::Instance()->Init(pszConfigPath))
	{
		assert(!"Failed Init ServerConfigure");
		return false;
	}

	std::shared_ptr<ServerHolder> config = ServerConfigure::Instance()->GetServerHolder(0, SERVER_TYPE_GAMEMANAGER);
	if (!config)
	{
		assert(!"Failed Get GameManager Configure");
		return false;
	}

	if (!m_logModule.Init(config->logFilePath, config->logLevel))
	{
		assert(!"Failed Init Log");
		return false;
	}
	SetLogListen(&m_logModule);
	_info("Init Log Success");

	if (!m_gamemanagerServerModule.Init(MAX_LIBEVENT_CONNECTION, config->listenPort))
	{
		_xerror("failed init gamemanager server net modules");
		return false;
	}
	_info("Init m_gamemanagerServerModule Success");
	
	m_IsWorking = true;
	return true;
}

bool GameManager::Tick()
{
	TimeMeter tm(30);

	tm.Stamp();
	m_gamemanagerServerModule.Tick();
	tm.Stamp("GameManagerServerModule network");

	CTimerMgr::Instance()->Tick();
	tm.Stamp("Timer work");

	tm.Check(MSG_MARK, "work");

	return true;
}

bool GameManager::Run()
{
	switch (m_serverState)
	{
	case SERVER_STATE_CREATE:
		return OnServerCreate();
		break;
	case SERVER_STATE_INIT:
		return OnServerStart();
		break;
	case SERVER_STATE_RUN:
		return Tick();
		break;
	case SERVER_STATE_STOP:
		return OnServerStop();
		break;
	case SERVER_STATE_FINISH:
		return OnServerClose();
		break;
	default:
		return false;
	}
	std::this_thread::sleep_for(std::chrono::milliseconds(1));
}

bool GameManager::OnServerCreate()
{
	SetServerState(SERVER_STATE_INIT);
	return true;
}

bool GameManager::OnServerStart()
{
	SetServerState(SERVER_STATE_RUN);
	return true;
}

bool GameManager::OnServerStop()
{
	SetServerState(SERVER_STATE_FINISH);
	return true;
}

bool GameManager::OnServerClose()
{
	m_IsWorking = false;
	return true;
}


ILogModule* GameManager::GetLogModule()
{
	return &m_logModule;
}

bool GameManager::IsWorking()
{
	return m_IsWorking;
}

int GameManager::GetServerState()
{
	return m_serverState;
}

void GameManager::SetServerState(int state)
{
	m_serverState = state;
}
