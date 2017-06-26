#ifndef __GATESERVER_MODULE_H__
#define __GATESERVER_MODULE_H__

// -------------------------------------------------------------------------
//    @FileName         :    GateServerModule.h
//    @Author           :    houontherun@gmail.com
//    @Date             :    2016-11-1
//    @Module           :    GateServer的服务端模块，负责处理客户端的连接
//
// -------------------------------------------------------------------------

#include "IGateServer.h"
#include "NetModule.h"
#include "message.h"
#include "IGateServerModule.h"
#include "BaseGateServerModule.h"


class GateServeModule :public BaseGateServerModule
{
public:
	GateServeModule() {}
	~GateServeModule() {}

	bool AfterInit();
	bool OnConnectionClose(int sock);
	void ProcessClientMessage(SocketSession* session, const char * data, const DATA_LENGTH_TYPE dataLength);
	void ProcessServiceMessage(SocketSession* session, const int serviceType, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnGameServerMessage(ServerMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnServerStop();
	void OnAvatarChangeGame(SESSIONID sid, SERVERID gameid);
	void OnAvatarInfo(ServerMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength);

private:
	//void OnConnectQuest(SocketSession* session, const char * data, const DATA_LENGTH_TYPE dataLength);
	bool CheckGameServerID(SERVERID gameServerID);
	SERVERID AssignGameServer(SESSIONID clientSession);

private:
	std::map<std::string, int> m_device2session;
};

#endif