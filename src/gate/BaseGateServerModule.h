#pragma once
#ifndef _BASE_GATE_SERVER_MODULE_H_
#define _BASE_GATE_SERVER_MODULE_H_

#include "IGateServer.h"
#include "NetModule.h"
#include "message.h"
#include "IGateServerModule.h"

class SocketSession;


struct ClientPkgStatis
{
	uint64_t  lastRecvPkgTimeMillo;
	uint32_t  recvCount;

	ClientPkgStatis() :lastRecvPkgTimeMillo(0), recvCount(0) {}
};


class BaseGateServerModule : public IGateServerModule
{
public:
	BaseGateServerModule() { m_connectionCount = 0; }
	~BaseGateServerModule() {}

	bool Init(uint32_t maxClients, int port);
	bool Tick();
	bool OnNewConnection(int sock);
	void OnSocketClientEvent(const int sock, const NET_EVENT eEvent, INet* net);
	void OnMessage(const int sock, const char * data, const DATA_LENGTH_TYPE dataLength);

	bool KickOff(SESSIONID sid);
	
	// IO Service
	void SendMessageToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage* message);
	void SendDataToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, const char* data, const DATA_LENGTH_TYPE dataLength);
	void BroadcastDataToClient(EntityMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength);

protected:
	uint32_t PackClientMessageHead(const SESSIONID sessionID, const int nServerID, const MESSAGEID messageID, const DATA_LENGTH_TYPE dataLength);
	void SendData(const char* data, DATA_LENGTH_TYPE dataLength, const int sock);
	NetModule*  GetServerNetModule();
	void AddSession(SESSIONID sid, int sock);
	void DeleteSession(SESSIONID sid);

protected:

	SESSIONID GenerateSessionID();
	void RecycleSessionID(SESSIONID sid);
	int  GetClientSocketBySession(SESSIONID clientSession);
	bool CheckClientData(SESSIONID sid);
	char m_recvBuff[MAX_RECVBUF_LEN];    
	char m_sendBuff[MAX_SENDBUF_LEN];   
	void ShowDebugInfo(int a);

private:
	NetModule                                        m_netModule;
	std::map<SESSIONID, int32_t>                     m_session2socket;
	std::list<uint32_t>                              m_SessionIDPoll;                 
	std::map<SESSIONID, std::shared_ptr<ClientPkgStatis>>             m_clientStatisData;
	int m_connectionCount;
};


#endif