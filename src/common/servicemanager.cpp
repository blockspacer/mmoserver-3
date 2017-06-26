#include "servicemanager.h"

void ServiceManager::RegisterService(SERVICE_TYPE servicetype, SERVERID gameid)
{
	if (m_serverProxy.find(servicetype) != m_serverProxy.end())
	{
		_xerror("ServiceType %d from %d is already in server %d", servicetype, gameid, m_serverProxy.find(servicetype)->second);
	}
	m_serverProxy[servicetype] = gameid;
}

SERVERID ServiceManager::GetServerID(SERVICE_TYPE servicetype)
{
	auto it = m_serverProxy.find(servicetype);
	if (it == m_serverProxy.end())
	{
		return INVALID_SERVER_ID;
	}
	return it->second;
}

void ServiceManager::UnregisterService(SERVICE_TYPE servicetype, SERVERID gameid)
{
	m_serverProxy.erase(servicetype);
}
