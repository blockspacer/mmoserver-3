#ifndef _GAMESERVER_MODULE_H_
#define _GAMESERVER_MODULE_H_

#include "IGameServer.h"
#include "NetModule.h"
#include "message.h"
#include "AOIModule.h"
#include "serverproxy.h"

typedef std::map<CLIENTID, ClientProxy> MapClients;
typedef std::map<SERVERID, int> MapGates;

class GameServerModule : public IGameServerModule
{
  public:
    GameServerModule();

    ~GameServerModule();

    bool Init(uint32_t maxClient, int port);
    bool Tick();
    void OnMessage(const int sock, const char *message, const DATA_LENGTH_TYPE messageLength);
    void OnSocketEvent(const int sock, const NET_EVENT eEvent, INet *net);

    ///////////////////// IOService /////////////////////
    void SendMessageToServer(const SERVERID serverid, int serviceType, IMessage *message);
    void SendData(const SERVERID serverid, int serviceType, const char *data, const DATA_LENGTH_TYPE dataLength);
    uint32_t PackServerMessageHead(const SERVERID srcServerID, const SERVERID dstServerID, int serviceType, const DATA_LENGTH_TYPE messageLength);
    void ForwardMessage(const SERVERID dstServerID, IMessage *message);
	void BroadcastMessageToGate(int messageID, int country, IMessage* message);
    void SendEntityMessage(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage *message);
    void SendMessageToFight(const SERVERID serverid, IMessage *message);

	///////////////////// API ///////////////////////
    SERVERID GetFightServerID(int fightType);

    void OnDBReply(const char *msg, const DATA_LENGTH_TYPE dataLength);

    void ProcessDBUpdateReply(const char *message, const DATA_LENGTH_TYPE messageLength);
    void ProcessDBFindOneReply(const char *message, const DATA_LENGTH_TYPE messageLength);
    void ProcessDBInsertReply(const char *message, const DATA_LENGTH_TYPE messageLength);
    void ProcessDBFindNReply(const char *message, const DATA_LENGTH_TYPE messageLength);
    void ProcessDBFindAndModifyReply(const char *message, const DATA_LENGTH_TYPE messageLength);

    void KickOffline(SESSIONID clientSession);

  private:
    SERVERID GetGateIDBySession(SESSIONID sessionID);
    void OnServerDisconnect(const int sock);
    void OnServerConnected(const int sock);

  private:
    // 将缓存中组好包的数据发给Gate
    void SendDataToGateWithHead(const SERVERID gateid, const DATA_LENGTH_TYPE messageLength);
    char *GetSendBuffBody();
	int GetSendBuffBodyLength();


  public:
    bool RegisterService(int serviceType);

  private:

    void OnServerDisconnect(const int serverType, const SERVERID serverid);

    int GetSessionDeltaTime(const SESSIONID clientSessionID);

    // 随机分配一个在连接状态的gateid
    int GetRandomGateID();

    std::string GetConnectedServerIP(SERVERID sid);

    int GetConnectedServerPort(SERVERID sid);

  public:
    void OnGateHeartBeat(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength);
    void OnEntityMessage(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength);
    void OnGateRegister(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength);
    void OnEntityDisconnect(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength);
    void OnTranspondMessage(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength);
    void OnFightServerMessage(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength);
	void OnTestConnection(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength);
	void OnPingGameMessage(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength);
	void OnPingGateReplyMessage(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength);
	//void OnConnectServerQuest(const SESSIONID clientSessionID, const char * message, const DATA_LENGTH_TYPE messageLength);

  private:
    NetModule m_netModule;
    char m_sendBuff[MAX_SENDBUF_LEN]; // 发送数据缓存
    std::map<SESSIONID, ClientSessionInfo> m_clientSessionInfo;
    uint32_t m_tickGameServerMessageCount;  // 每帧处理的消息
    uint32_t m_totalGameServerMessageCount; // 总的处理消息
    ServerProxyManager m_serverManager;
};

#endif
