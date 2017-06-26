#pragma once
#ifndef _SERVER_PROXY_H_
#define _SERVER_PROXY_H_
#include "common.h"
#include <map>
#include <string>
#include <memory>
#include <vector>
#include <set>

// 连到Server的另外Server
struct ServerProxy
{
	ServerProxy()
	{
		sid = 0;
		sock = 0;
		servertype = 0;
		serverip = "";
		serverport = 0;
		last_message_time = 0;
	}

	ServerProxy(SERVERID sid, int sock, int serverType, std::string ip, int port) :sid(sid), sock(sock), servertype(serverType), serverip(ip), serverport(port) 
	{
		last_message_time = 0;
	}

	SERVERID sid;
	int sock;
	int servertype;
	std::string serverip;
	int  serverport;
	int64_t last_message_time;
};

class ServerProxyManager
{
public:
	ServerProxyManager() {}
	~ServerProxyManager() {}

	void AddServerProxy(SERVERID sid, int sock, int serverType, std::string ip, int port);

	void AddServerProxy(std::shared_ptr<ServerProxy> serverProxy);

	void DeleteServerProxy(SERVERID sid);

	SERVERID GetServerID(int sock);

	std::shared_ptr<ServerProxy> GetServerProxy(SERVERID sid);

	int GetSock(SERVERID sid);

	int GetServerType(SERVERID sid);

	std::string GetServerIP(SERVERID sid);

	int GetServerPort(SERVERID sid);

	void GetAllServerOfType(int serverType, std::set<SERVERID> &outServeIDGroup);

	void UpdateMessageTime(SERVERID sid, int64_t now);

	void CheckServerConnect(int timeid);

private:
	std::map<SERVERID, std::shared_ptr<ServerProxy>>   m_serverProxys;
};

#endif // !_SERVER_PROXY_H_
