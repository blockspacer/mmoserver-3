#ifndef __I_GAMESERVER_H__
#define __I_GAMESERVER_H__

#include "IGameServerModule.h"
#include "Timer.h"
#include "IDBClientModule.h"
#include "IProxyModuel.h"
#include <string>
#include "ServerConfigure.h"

class GameLuaModule;

class IGameServer
{
  public:
    virtual ~IGameServer() {}

    virtual IGameServerModule *GetGameServerModule() = 0;

    virtual IDBClientModule *GetDBClientModule() = 0;

    virtual IProxyModule *GetAOIModule() = 0;

    virtual void SetServerState(int state) = 0;

    virtual std::string GetServerName() = 0;

	virtual SERVERID GetServerID() = 0;

    virtual GameLuaModule *GetGameLuaModuel() = 0;

	virtual std::string GetConfigPath() = 0;
};

extern IGameServer *g_pGameServer;

#define GlobalGameServer g_pGameServer
#define GlobalGameServerModule ((GlobalGameServer == NULL) ? NULL : GlobalGameServer->GetGameServerModule())
#define GlobalDBClientModule ((GlobalGameServer == NULL) ? NULL : GlobalGameServer->GetDBClientModule())
#endif
