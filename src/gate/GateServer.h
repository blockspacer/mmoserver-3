#ifndef _GATESERVER_H_
#define _GATESERVER_H_

#include <stdint.h>
#include <thread>
#include "LogModule.h"
#include "IGateServerModule.h"
#include "IGateServer.h"
#include "time.h"
#include "GateLuaModule.h"
#include "GameClientModule.h"
#include "IProxyModuel.h"
#include "Timer.h"
#include "redismodule.h"
#include "ServerConfigure.h"
#include "GameManagerClientModule.h"

class GateServer:public IGateServer
{
public:
	GateServer(std::string servername, int servertype);
	~GateServer();

	bool Init(std::string configPath);
	bool Run();
	bool Tick();
	bool InitClient();
	bool OnServerState();
	bool OnServerStop();
	bool OnServerClose();

	IGameClientModule* GetGameClientModule();
	SERVERID GetServerID();
	int GetServerType();
	IGateServerModule* GetGateServerModule();
	int GetServerState();
	void SetServerState(int state);
	std::string GetServerName();
	bool IsForbidNewConnection();
	void SetForbidNewConnection(bool isForbid);
	bool IsIgnoreClientMessage();
	void SetIgnoreClientMessage(bool isIgnore);
	bool IsWorking();

private:
	void OnUpdateGameServerInfo(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength);

private:
	std::string       m_serverName;
	int               m_serverType;
	SERVERID   m_serverID;
	int               m_serverState;
	uint32_t          m_idleCount;   //空闲的次数

	LogModule         m_logModule;
	IGateServerModule*   m_gateServerModule;
	GameClientModule  m_gameClient;
	bool m_gameClientReady;
	GameManagerClientModule m_gamemanagerClient;
	bool m_gamemanagerClientReady;

	bool m_forbidNewConnection;
	bool m_ignoreClientMessage;
	bool m_IsWorking;
	uint64_t  m_lastTickTime;
};

#endif