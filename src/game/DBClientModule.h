#ifndef __DBCLIENT_MODULE_H__
#define __DBCLIENT_MODULE_H__

// -------------------------------------------------------------------------
//    @FileName         :    DBClientModule.h
//    @Author           :    houontherun@gmail.com
//    @Date             :    2016-11-1
//    @Module           :    
//
// -------------------------------------------------------------------------

#include "ClientNetModule.h"
#include "ILogModule.h"
#include "message.h"
#include "IGameServer.h"
#include "IDBClientModule.h"

class DBClientModule : public IDBClientModule
{
 public:
    DBClientModule();
    ~DBClientModule();
    bool Init();
    bool Tick();
    void OnSocketEventOfDBProxy(const int sock, const NET_EVENT event, INet *net);
    void Register(INet *net);
    void OnMessage(const int sock, const char *data, const DATA_LENGTH_TYPE dataLength);
	bool IsReady();

	///////////////////// IO Service //////////////
    void SendDataToDBProxy(const int dstServerID, const int serviceType, const char *data, const DATA_LENGTH_TYPE dataLength);
    void SendMessageToDBProxy(const int dstServerID, const int serviceType, IMessage *message);
    void SendDataToDBProxyWithHead(const int dstServerID, const char *data, const DATA_LENGTH_TYPE dataLength);

private:
    uint32_t PackServerMessageHead(const int dstServerID, const int serviceType, const DATA_LENGTH_TYPE dataLength);
	void TestDBMessage();

private:
    ClientNetModule m_DBClient;
    char m_sendBuff[MAX_SENDBUF_LEN]; // 发送数据缓存
    SERVERID m_DBID;
    bool m_connected;

	int m_tickCount;
	int m_tickMessageCount;
	int m_tickMessageLength;
	int m_totalMessageCount;
};

#endif