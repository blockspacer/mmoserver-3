#ifndef __DBPROXY_H__
#define __DBPROXY_H__

#include "ILogModule.h"
#include "IDBProxy.h"
#include "DBServerModule.h"
#include "DBLuaModule.h"
#include "GameManagerClientModule.h"

class DBProxy :public IDBProxy
{
public:
	DBProxy(std::string servername) : m_serverName(servername) {}
	~DBProxy() {};

	bool Init(std::string pszConfigPath);

	bool Tick();

	void Run();

	int32_t  GetServerID();

	void SetServerState(int s);

	void InitClient();

	void OnServerStart();

	void OnServerStop();

	void OnServerClose();

	bool IsWorking();

	ILogModule* GetLogModule() {
		return &m_logModule;
	}

	IDBServerModule* GetDBServerModule() {
		return &m_dbServerModule;
	}

private:
	SERVERID m_serverID;
	std::string m_serverName;
	uint32_t m_idleCount;
	LogModule m_logModule;
	DBServerModule m_dbServerModule; //负责listen and accept 链接
	GameManagerClientModule m_gamemanagerClient;
	int m_serverState;
	bool m_IsWorking; 
};

#endif
