#pragma once

#include "NetModule.h"
#include "message.h"
#include "serverproxy.h"

class GameManagerServerModule
{
public:
	GameManagerServerModule() {}
	~GameManagerServerModule() {}

	bool Init(uint32_t maxClient, int port);
	bool Tick();
	void OnMessage(const int sock, const char * message, const DATA_LENGTH_TYPE messageLength);
	void OnSocketEvent(const int sock, const NET_EVENT eEvent, INet* net);
	void SendMessageToServer(const SERVERID dstServerID, const uint16_t serviceType, IMessage* message);
	void SendDataToServer(const SERVERID dstServerID, const uint16_t serviceType, const char* data, const DATA_LENGTH_TYPE dataLength);
	void SendDataToServer(const SERVERID srcServerID, const SERVERID dstServerID, const uint16_t serviceType, const char* data, const DATA_LENGTH_TYPE dataLength);
	void SendDataToGMClient(const SERVERID dstServerID, const uint16_t serviceType, const char* data, const DATA_LENGTH_TYPE dataLength);
	void BroadcastMessageToGate(const uint16_t serviceType, IMessage* message);
	void BroadcastMessageToFight(const uint16_t serviceType, IMessage* message);
	void BroadcastMessageToGame(const uint16_t serviceType, IMessage* message);
	void BroadcastMessageToDB(const uint16_t serviceType, IMessage* message);
	void BroadcastMessage(const int serverType, const uint16_t serviceType, IMessage* message);

private:
	void OnServerDisconnect(const int sock);
	void OnServerConnected(const int sock);
	void OnServerRegister(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnHeartbeat(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnGameServerRegister(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnGateServerRegister(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnDBServerRegister(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnRunScript(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnRunScriptReply(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnLuaMessage(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnGateControlMessage(ServerMessageHead * head, int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnGameControlMessage(ServerMessageHead * head, int sock, const char * data, const DATA_LENGTH_TYPE dataLength);
	void OnForwardGameMessage(ServerMessageHead * head, int sock, const char * data, const DATA_LENGTH_TYPE dataLength);

private:
	uint32_t PackServerMessageHead(const SERVERID srcServerID, const SERVERID dstServerID, int serviceType, const DATA_LENGTH_TYPE messageLength);

private:
	NetModule m_netModule;
	char m_sendBuff[MAX_SENDBUF_LEN];    // 发送数据缓存
	uint32_t m_tickGameServerMessageCount;        // 每帧处理的消息
	uint32_t m_totalGameServerMessageCount;       // 总的处理消息
	ServerProxyManager  m_serverManager;
	std::map<int, int> m_GMClientSock;
};