#pragma once
#ifndef _BATTLE_PROXY_MODULE_H_
#define _BATTLE_PROXY_MODULE_H_

#include "AOIModule.h"

class BattleProxyModule :public ProxyModule
{
public:
	bool Init();

	void SendMessageToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage * message);

};



#endif