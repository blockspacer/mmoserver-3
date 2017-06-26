#include "serverproxy.h"

void ServerProxyManager::AddServerProxy(SERVERID sid, int sock, int serverType, std::string ip, int port)
{
	std::shared_ptr<ServerProxy> serverProxy = std::make_shared<ServerProxy>(sid, sock, serverType, ip, port);
	AddServerProxy(serverProxy);
}

void ServerProxyManager::AddServerProxy(std::shared_ptr<ServerProxy> serverProxy)
{
	m_serverProxys[serverProxy->sid] = serverProxy;
}

void ServerProxyManager::DeleteServerProxy(SERVERID sid)
{
	m_serverProxys.erase(sid);
}

SERVERID ServerProxyManager::GetServerID(int sock)
{
	for (auto it = m_serverProxys.begin(); it != m_serverProxys.end(); ++it)
	{
		if (it->second->sock == sock)
		{
			return it->first;
		}
	}
	return INVALID_SERVER_ID;
}

std::shared_ptr<ServerProxy> ServerProxyManager::GetServerProxy(SERVERID sid)
{
	auto it = m_serverProxys.find(sid);
	if (it != m_serverProxys.end())
	{
		return it->second;
	}
	else
	{
		return std::make_shared<ServerProxy>();
	}
}

int ServerProxyManager::GetSock(SERVERID sid)
{
	std::shared_ptr<ServerProxy> p = GetServerProxy(sid);
	if (p == nullptr)
	{
		return INVALID_SOCKET_ID;
	}
	return p->sock;
}

int ServerProxyManager::GetServerType(SERVERID sid)
{
	std::shared_ptr<ServerProxy> p = GetServerProxy(sid);
	if (p == nullptr)
	{
		return -1;
	}
	return p->servertype;
}

std::string ServerProxyManager::GetServerIP(SERVERID sid)
{
	std::shared_ptr<ServerProxy> p = GetServerProxy(sid);
	if (p == nullptr)
	{
		return "";
	}
	return p->serverip;
}

int ServerProxyManager::GetServerPort(SERVERID sid)
{
	std::shared_ptr<ServerProxy> p = GetServerProxy(sid);
	if (p == nullptr)
	{
		return 0;
	}
	return p->serverport;
}

void ServerProxyManager::GetAllServerOfType(int serverType, std::set<SERVERID>& outServeIDGroup)
{
	for (auto it = m_serverProxys.begin(); it != m_serverProxys.end(); ++it)
	{
		if (it->second->servertype == serverType)
		{
			outServeIDGroup.insert(it->first);
		}
	}
}

void ServerProxyManager::UpdateMessageTime(SERVERID sid, int64_t now)
{
	std::shared_ptr<ServerProxy> p = GetServerProxy(sid);
	if (p == nullptr)
	{
		_xerror("Failed find server of serverID %d SHOULD NERVER HAPPEN", sid);
		return;
	}
	p->last_message_time = now;
}

void ServerProxyManager::CheckServerConnect(int timeid)
{
	int64_t now = GetNowTimeSecond();
	// 如果某个进程100s没有发送信息过来，那么任务这个进程有问题
	for (auto it = m_serverProxys.begin(); it != m_serverProxys.end(); ++it)
	{
		std::shared_ptr<ServerProxy> proxy = it->second;
		if (now - proxy->last_message_time > 100)
		{
			_xerror("Server %d has no message maybe lose connection or drop endless loop", proxy->sid);
		}
	}
}


