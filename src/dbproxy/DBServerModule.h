#ifndef _DBSERVER_MODULE_H_
#define _DBSERVER_MODULE_H_

#include "IDBServerModule.h"
#include "NetModule.h"
#include "message.h"
#include "MongoModule.h"

typedef std::map<SERVERID, int>              MapServer;



class DBServerModule :public IDBServerModule
{
public:

	DBServerModule();

	~DBServerModule();

	bool Init(uint32_t maxClient, int port);

	bool Tick();

	void OnMessage(const int sock, const char * message, const DATA_LENGTH_TYPE messageLength);

	void OnSocketEvent(const int sock, const NET_EVENT eEvent, INet* net);

	void OnClientDisconnect(const int nAddress);

	void OnClientConnected(const int nAddress);

	uint32_t PackServerMessageHead(const SERVERID dstServerID, const int serviceType, const DATA_LENGTH_TYPE messageLength);

	void SendResultBack(const SERVERID serverID, const uint16_t messageID, IMessage* message);

	void SendResultBack(const SERVERID serverID, const uint16_t messageID, const char* data, const DATA_LENGTH_TYPE dataLength);

private:
	void SendDataWithHead(const SERVERID serverID, const DATA_LENGTH_TYPE dataLength);

	void SendData(const char* data, DATA_LENGTH_TYPE dataLength, const int sock)
	{
		m_netModule.SendData(data, dataLength, sock);
	}

private:
	void OnServerDisconnect(const SERVERID gateid);

private:   
	NetModule      m_netModule;
	MapServer      m_servers;                                 
	char		   m_sendBuff[MAX_SENDBUF_LEN];              
	MongoModule    m_mongo;

	int m_tickCount;
	int m_tickMessageCount;
	int m_tickMessageLength;
	int m_totalMessageCount;
};

#endif

