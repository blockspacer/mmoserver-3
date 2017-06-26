#ifndef __I_GAMESERVER_MODULE_H__
#define __I_GAMESERVER_MODULE_H__

#include "message.h"
#include "IProxyModuel.h"
#include <functional>
#include <map>

typedef std::function<void(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength)> TODO_GATE_MESSAGE_HANDLER;
typedef std::shared_ptr<TODO_GATE_MESSAGE_HANDLER> TODO_GATE_MESSAGE_HANDLER_PTR;

typedef std::function<void(const SESSIONID clientSessionID, const char *msg, const DATA_LENGTH_TYPE dataLength)> ENTITYT_MESSAGE_HANDLER;
typedef std::shared_ptr<ENTITYT_MESSAGE_HANDLER> ENTITYT_MESSAGE_HANDLER_PTR;

class IGameServerModule
{
  public:
    virtual ~IGameServerModule() {}

    virtual void SendMessageToServer(const SERVERID serverid, int serviceType, IMessage *message) = 0;
    virtual void SendData(const SERVERID serverid, int serviceType, const char *data, const DATA_LENGTH_TYPE dataLength) = 0;
    virtual uint32_t PackServerMessageHead(const SERVERID srcServerID, const SERVERID dstServerID, int serviceType, const DATA_LENGTH_TYPE messageLength) = 0;
    virtual void ForwardMessage(const SERVERID dstServerID, IMessage *message) = 0;
    virtual void BroadcastMessageToGate(int messageID, int country, IMessage* message) = 0;
    virtual void SendEntityMessage(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage *pMesage) = 0;
    virtual void SendMessageToFight(const SERVERID serverid, IMessage *message) = 0;

    virtual void OnDBReply(const char *msg, const DATA_LENGTH_TYPE dataLength) = 0;

    virtual void KickOffline(SESSIONID clientSession) = 0;

    virtual int GetSessionDeltaTime(const SESSIONID clientSessionID) = 0;

    virtual SERVERID GetFightServerID(int fightType) = 0;

    virtual std::string GetConnectedServerIP(SERVERID sid) = 0;

    virtual int GetConnectedServerPort(SERVERID sid) = 0;

    virtual bool RegisterService(int serviceType) = 0;

	virtual SERVERID GetGateIDBySession(SESSIONID sessionID) = 0;

    template <typename BaseType>
    bool RegisterEntityMethodCallback(const MESSAGEID messageID, BaseType *pBase, void (BaseType::*handleRecieve)(const SESSIONID clientSessionID, const char *msg, const DATA_LENGTH_TYPE dataLength))
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

    std::map<MESSAGEID, ENTITYT_MESSAGE_HANDLER_PTR> m_EntityMessageHandlers;

    ///////////////////////////// TODO //////////////////////////////////////
    template <typename BaseType>
    bool RegisterGateMethodCallback(const MESSAGEID opcode, BaseType *pBase, void (BaseType::*handleGateMessage)(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength))
    {
	if (m_gateMessageHandlers.find(opcode) != m_gateMessageHandlers.end())
	{
	    return false;
	}
	TODO_GATE_MESSAGE_HANDLER functor = std::bind(handleGateMessage, pBase, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3, std::placeholders::_4);
	TODO_GATE_MESSAGE_HANDLER_PTR functorPtr(new TODO_GATE_MESSAGE_HANDLER(functor));

	m_gateMessageHandlers[opcode] = functorPtr;
	return true;
    }
    std::map<MESSAGEID, TODO_GATE_MESSAGE_HANDLER_PTR> m_gateMessageHandlers;
};

#endif // !__I_GAMESERVER_MODULE_H__
