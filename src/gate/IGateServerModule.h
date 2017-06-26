#ifndef __I_GATESERVER_MODULE_H__
#define __I_GATESERVER_MODULE_H__
// -------------------------------------------------------------------------
//    @FileName         :    IGateServerModule.h
//    @Author           :    houontherun@gmail.com
//    @Date             :    2016-11-1
//    @Module           :    �ӿ��ļ�
//
// -------------------------------------------------------------------------

#include "common.h"
#include <functional>
#include "message.h"
#include <map>
#include "NetModule.h"

typedef std::function<void(const SESSIONID clientSessionID, const char * data, const DATA_LENGTH_TYPE dataLength)> ENTITYT_MESSAGE_HANDLER;
typedef std::shared_ptr<ENTITYT_MESSAGE_HANDLER> ENTITYT_MESSAGE_HANDLER_PTR;

class IGateServerModule
{
public:
	virtual ~IGateServerModule() {}

	virtual bool Init(uint32_t maxClients, int port) = 0;
	virtual bool AfterInit() = 0;
	virtual bool Tick() = 0;

	virtual bool OnNewConnection(int sock) = 0;

	virtual bool OnConnectionClose(int sock) = 0;

	virtual bool KickOff(SESSIONID sid) = 0;

	virtual void OnSocketClientEvent(const int sock, const NET_EVENT eEvent, INet* net) = 0;

	virtual void OnMessage(const int sock, const char * data, const DATA_LENGTH_TYPE dataLength) = 0;

	virtual void ProcessClientMessage(SocketSession* session, const char * data, const DATA_LENGTH_TYPE dataLength) = 0;

	virtual void OnGameServerMessage(ServerMessageHead* head, const char * data, const DATA_LENGTH_TYPE length) = 0;

	virtual void ProcessServiceMessage(SocketSession* session, const int serviceType, const char * data, const DATA_LENGTH_TYPE dataLength) = 0;

	virtual uint32_t PackClientMessageHead(const SESSIONID sessionID, const int serverID, const MESSAGEID messageID, const DATA_LENGTH_TYPE dataLength) = 0;

	virtual void SendMessageToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage* message) = 0;

	virtual void SendDataToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, const char* data, const DATA_LENGTH_TYPE dataLength) = 0;

	virtual void BroadcastDataToClient(EntityMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength) = 0;

	virtual void OnServerStop() = 0;

	virtual void OnAvatarChangeGame(SESSIONID sid, SERVERID gameid) = 0;

	template<typename BaseType>
	bool RegisterEntityMethodCallback(const MESSAGEID messageID, BaseType* pBase, void (BaseType::*handleRecieve)(const SESSIONID clientSessionID, const char * msg, const DATA_LENGTH_TYPE dataLength))
	{
		if (m_EntityMessageHandlers.find(messageID) != m_EntityMessageHandlers.end())
		{
			return false;
		}
		ENTITYT_MESSAGE_HANDLER functor = std::bind(handleRecieve, pBase, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3);
		ENTITYT_MESSAGE_HANDLER_PTR ptr(new ENTITYT_MESSAGE_HANDLER(functor));

		m_EntityMessageHandlers[messageID] = ptr;
		return true;
	}

	std::map<MESSAGEID, ENTITYT_MESSAGE_HANDLER_PTR>       m_EntityMessageHandlers;
};


#endif // !__I_GATESERVER_MODULE_H__



