#pragma once
#include "common.h"
#include "ClientNetModule.h"
#include "message.h"
#include "ServerConfigure.h"
#include "message/LuaMessage.pb.h"
#include "message/servermessage.pb.h"

extern "C"
{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

typedef std::function<void(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength)> SERVER_MESSAGE_HANDLER;
typedef std::shared_ptr<SERVER_MESSAGE_HANDLER> SERVER_MESSAGE_HANDLER_PTR;

class GameManagerClientModule
{
public:
	GameManagerClientModule():  m_lastSendHeartbeatTime(0), m_lastRecvHeartbeatTime(0),m_isReady(false) {}
	~GameManagerClientModule() {}

	bool Init(SERVERID masterServerID);
	bool Tick();
	void KeepLive();
	void OnSocketEventOfGameManager(const int sock, const NET_EVENT event, INet* net);
	void OnMessage(const int sock, const char* data, const DATA_LENGTH_TYPE dataLength);
	void SendMessageToGameManager(const uint16_t serviceType, IMessage* message);
	void SendDataToGameManager(const uint16_t serviceType, const char *data, const DATA_LENGTH_TYPE dataLength);
	void ForwardDataToGame(SERVERID dstServerID, const uint16_t serviceType, const char *data, const DATA_LENGTH_TYPE dataLength);
	bool IsReady();
	void CheckHeartbeat();

	template <typename BaseType>
	bool RegisterServerMethodCallback(const MESSAGEID messageID, BaseType *pBase, void (BaseType::*handleGateMessage)(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength))
	{
		if (m_ServerMessageHandlers.find(messageID) != m_ServerMessageHandlers.end())
		{
			return false;
		}
		SERVER_MESSAGE_HANDLER functor = std::bind(handleGateMessage, pBase, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3, std::placeholders::_4);
		SERVER_MESSAGE_HANDLER_PTR functorPtr(new SERVER_MESSAGE_HANDLER(functor));

		m_ServerMessageHandlers[messageID] = functorPtr;
		return true;
	}

	
private:
	void Register(INet* net);
	uint32_t PackServerMessageHead(const int dstServerID, const int serviceType, const DATA_LENGTH_TYPE dataLength);
	void OnGameManagerDisconnect();

private:
	ClientNetModule    m_gamemanagerClient;
	SERVERID m_masterServerID;
	uint64_t m_lastSendHeartbeatTime;
	uint64_t m_lastRecvHeartbeatTime;
	char m_sendBuff[MAX_SENDBUF_LEN];
	std::map<MESSAGEID, SERVER_MESSAGE_HANDLER_PTR> m_ServerMessageHandlers;
	bool m_isReady;
};

extern GameManagerClientModule* gGameManagerClient;
void SetGameManagerClient(GameManagerClientModule* g);

#define GlobalGameManagerClient gGameManagerClient


extern "C" void luaopen_gamemanagerfunction(lua_State* L);
