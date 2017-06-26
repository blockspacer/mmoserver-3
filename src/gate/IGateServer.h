#ifndef __I_GATESERVER_H__
#define __I_GATESERVER_H__

#include "IGameClientModule.h"
#include "IGateServerModule.h"
#include <string>
#include "Timer.h"

class FightLuaModule;

class IGateServer
{
public:
	virtual ~IGateServer() {}

	virtual IGameClientModule* GetGameClientModule() = 0;

	virtual SERVERID GetServerID() = 0;

	virtual int GetServerType() = 0;

	virtual std::string GetServerName() = 0;

	virtual IGateServerModule* GetGateServerModule() = 0;

	virtual void SetServerState(int state) = 0;

	virtual bool IsForbidNewConnection() = 0;

	virtual void SetForbidNewConnection(bool isForbid) = 0;

	virtual bool IsIgnoreClientMessage() = 0;

	virtual void SetIgnoreClientMessage(bool isIgnore) = 0;

	virtual bool IsWorking() = 0;
};

extern IGateServer* g_pGateServer;

#define GlobalGateServer                       g_pGateServer
#define GlobalGameClientModule                 ((GlobalGateServer == NULL) ? NULL : GlobalGateServer->GetGameClientModule())
#define GlobalGateServerModule                 ((GlobalGateServer == NULL) ? NULL : GlobalGateServer->GetGateServerModule())




#endif