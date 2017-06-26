#ifndef __I_GAMESERVER_H__
#define __I_GAMESERVER_H__

#include "ILuaModule.h"
#include "IDBServerModule.h"
#include "Timer.h"
#include "ServerConfigure.h"

class DBProxyConfig;

class IDBProxy
{
public:
	virtual ~IDBProxy() {}

	virtual IDBServerModule* GetDBServerModule() = 0;

	virtual int32_t  GetServerID() = 0;

	virtual void SetServerState(int s) = 0;
};

extern IDBProxy* g_pDBProxy;

#define GlobalDBProxy g_pDBProxy

#define GlobalDBServerModule   ((GlobalDBProxy == NULL) ? NULL : GlobalDBProxy->GetDBServerModule())
#define GlobalDBID             ((GlobalDBProxy == NULL) ? 0 : GlobalDBProxy->GetServerID())
#endif


