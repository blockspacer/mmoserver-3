#ifndef __GAMECLIENT_MODULE_H__
#define __GAMECLIENT_MODULE_H__

// -------------------------------------------------------------------------
//    @FileName         :    GameClientModule.h
//    @Author           :    houontherun@gmail.com
//    @Date             :    2016-11-1
//    @Module           :    
//
// -------------------------------------------------------------------------


#include "ClientNetModule.h"
#include "ILogModule.h"
#include "message.h"
#include "IGateServer.h"

class GameClientModule : public IGameClientModule
{
public:
	GameClientModule();

	~GameClientModule();

	bool Init();
	bool Tick();
	void OnSocketEventOfGameServer(const int sock, const NET_EVENT eEvent, INet* net);
	void OnMessage(const int sock,  const char* data, const DATA_LENGTH_TYPE dataLength);

	void Register(INet* net);
	void OnAckEnterGame(const int sock, const int messageID, const char* data, const DATA_LENGTH_TYPE dataLength);
	bool IsReady();

	// IO Service
	void NotifyClientConnectionClose(const SESSIONID clientSession, const SERVERID gameid);
	void SendEntityMessage(SESSIONID sid, SERVERID gameid, ClientMessageHead* head, const char * data, const DATA_LENGTH_TYPE length);
	void SendMessageToGameServer(const int gameid, const int serviceType, IMessage* message);
	void SendDataToGameServer(const int gameid, const int serviceType, const char * data, const DATA_LENGTH_TYPE length, const SERVERID srcGameID = 0);
	void BroadcastDataToAllGame(const SERVERID srcID, const int messageType,  const char* data, const DATA_LENGTH_TYPE dataLength);

private:
	uint32_t PackServerMessageHead(const SERVERID srcServerID, const SERVERID dstServerID, const int serviceType, const DATA_LENGTH_TYPE messageLength);
	void GetAllValidGameServer(std::set<SERVERID>& outServers);

public:
	void OnBroadcastToClient(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength);
	void OnKickClientOffline(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength);
	void OnForwardMessage(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength);
	void OnBroadcastToGame(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength);
	void OnRegisterService(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength);
	void OnEntityMessage(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength);
	void OnGamePingMessage(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength);
	void OnGatePingReplyMessage(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength);
	void OnAvatarChangeGame(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength);

private:
	ClientNetModule m_gameClientManager;
	uint64_t m_lastSendHeartbeatTime;
	std::map<SERVERID, uint64_t> m_RecvHeartbeatTime;
	char m_sendBuff[MAX_SENDBUF_LEN];    
	int m_configServerCount;
	int m_connectedServerCount;
};

#endif