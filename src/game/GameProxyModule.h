#pragma once
#ifndef _GAME_PROXY_MODULE_H_
#define _GAME_PROXY_MODULE_H_

#include "AOIModule.h"

class GameProxyModule :public ProxyModule
{
public:
	void SendMessageToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage * pMessage);

};

#endif