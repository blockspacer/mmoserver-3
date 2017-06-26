#ifndef __CLIENT_PROXY_H__
#define __CLIENT_PROXY_H__


#include "IProxy.h"
/* 玩家在逻辑进程对应的代理
*/
class ClientProxy: public BaseProxy, public IClientProxy
{
public:
	ClientProxy() {}
	~ClientProxy() {}

	virtual void SetSessionID(SESSIONID sid) = 0;

	virtual SESSIONID GetSessionID() = 0;

	virtual void SendMessageToMe(MESSAGEID messageID, IMessage* message) = 0;

private:
	CLIENTID　m_clientid;
	SERVERID  m_gateid;
	SESSIONID m_clientsession;
	SESSIONID m_gatesession;
};

#endif
