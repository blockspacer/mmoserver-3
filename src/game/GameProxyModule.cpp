#include "GameProxyModule.h"
#include "IGameServer.h"

void GameProxyModule::SendMessageToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage * message)
{
	GlobalGameServerModule->SendEntityMessage(clientSessionID, messageID, message);
}
