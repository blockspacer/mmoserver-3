#include "BattleProxyModule.h"
#include "IGateServer.h"

bool BattleProxyModule::Init()
{
	if (!ProxyModule::Init())
	{
		return false;
	}
	return true;
}

void BattleProxyModule::SendMessageToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage * message)
{

	GlobalGateServerModule->SendMessageToClient(clientSessionID, messageID, message);
}
