#pragma once
#ifndef _FIGHT_SERVER_MODULE_H_
#define _FIGHT_SERVER_MODULE_H_

#include "BaseGateServerModule.h"
#include "IProxyModuel.h"
#include "GateLuaModule.h"

class FightServerModule :public BaseGateServerModule
{
public:
	FightServerModule() {}
	~FightServerModule() {}

	bool Init(uint32_t maxClients, int port);

	bool AfterInit();

	bool OnConnectionClose(int sock);

	// ÌßÍæ¼ÒÏÂÏß
	bool KickOff(SESSIONID sid);

	void ProcessClientMessage(SocketSession* session, const char * msg, const DATA_LENGTH_TYPE dataLength);

	void ProcessServiceMessage(SocketSession* session, const int serviceType, const char * msg, const DATA_LENGTH_TYPE dataLength);

	void OnGameServerMessage(ServerMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength);
	
	void OnServerStop();

	bool Tick();

	void OnAvatarChangeGame(SESSIONID sid, SERVERID gameid);

	//void OnConnectQuest(SocketSession* session, const char * data, const DATA_LENGTH_TYPE dataLength);

private:
	IProxyModule*   m_proxyModule;
	FightLuaModule  m_fightLuaModule;
};

#endif // !_FIGHT_SERVER_MODULE_H_