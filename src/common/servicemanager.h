#pragma once
#ifndef _SERVICE_MANAGER_H_
#define _SERVICE_MANAGER_H_

#include "common.h"
#include <map>

typedef int SERVICE_TYPE;

class ServiceManager
{
public:
	ServiceManager() {}
	~ServiceManager() {}

	void RegisterService(SERVICE_TYPE servicetype, SERVERID gameid);

	SERVERID GetServerID(SERVICE_TYPE servicetype);

	void UnregisterService(SERVICE_TYPE servicetype, SERVERID gameid);

private:
	std::map<SERVICE_TYPE, SERVERID> m_serverProxy;
};

#endif