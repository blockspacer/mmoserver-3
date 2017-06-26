#pragma once
#ifndef _CLIENT_MANAGER_H_
#define _CLIENT_MANAGER_H_
#include "common.h"

struct ClientSessionInfo
{
	SESSIONID   sessionID;
	int         DeltaTime;
	int         Latency;

	ClientSessionInfo()
	{
		memset(this, 0, sizeof(*this));
	}
};

class ClientManager
{
public:
	ClientManager() {}
	~ClientManager() {}

	void AddClient(SESSIONID sid);
private:
	std::map<SESSIONID, ClientSessionInfo>                m_clientSessionInfo;
};

#endif