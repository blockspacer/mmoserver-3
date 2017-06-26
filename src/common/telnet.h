#ifndef __TELNET_H__
#define __TELNET_H__
#include <cstring>
#include <errno.h>
#include <stdio.h>
#include <signal.h>
#include <stdint.h>
#include <iostream>
#include <map>

#ifndef _MSC_VER
#include <netinet/in.h>
# ifdef _XOPEN_SOURCE_EXTENDED
#  include <arpa/inet.h>
# endif
#include <sys/socket.h>
#endif

#include <vector>
#include <functional>
#include <memory>
#include <list>
#include <vector>
#include <event2/bufferevent.h>
#include <event2/buffer.h>
#include <event2/listener.h>
#include <event2/util.h>
#include <event2/thread.h>
#include <event2/event_compat.h>
#include <assert.h>

#ifdef _MSC_VER
#include <windows.h>
#else
#include <unistd.h>
#endif
#include "common.h"
#include "SocketSession.h"
#include "INet.h"


class TelnetServer :public INet
{
public:
	TelnetServer();
	virtual ~TelnetServer() {};

public:
	virtual bool Tick();

	virtual int Initialization(std::string masterName, const unsigned int nMaxClient, const unsigned short nPort, const int nCpuCount = 4);
	virtual int Initialization(const unsigned int nMaxClient, const unsigned short nPort, const int nCpuCount = 4);
	virtual void Initialization(const char* strIP, const unsigned short nPort);

	virtual bool Final();

	virtual bool CloseSocketSession(const int sock);
	virtual bool AddSocketSession(const int sock, SocketSession* session);
	virtual SocketSession* GetSocketSession(const int sock);

	virtual bool IsServer();
	virtual bool Log(int severity, const char* msg);

	bool SendMsg(const char* msg, const DATA_LENGTH_TYPE dataLength, const int sock);
	std::string GetMasterName();

	template<typename BaseType>
	void RegisterConsoleHandler(BaseType* pBaseType, void (BaseType::*handleRecieve)(const int sock, const char* data, const DATA_LENGTH_TYPE dataLength))
	{
		m_consoleHandler = std::bind(handleRecieve, pBaseType, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3);
	}

	const char* GetPollName() { return ""; }

private:
	void ExecuteClose();
	bool CloseSocketAll();

	bool UnpackRecvData(SocketSession* session);

	int InitServerNet();

	void CloseSession(const int sock);

	static void listener_cb(struct evconnlistener* listener, evutil_socket_t fd, struct sockaddr* sa, int socklen, void* user_data);
	static void conn_readcb(struct bufferevent* bev, void* user_data);
	static void conn_writecb(struct bufferevent* bev, void* user_data);
	static void conn_eventcb(struct bufferevent* bev, short events, void* user_data);

private:
	std::map<int, SocketSession*> m_sessionManager;  
	std::vector<int> m_removedSession;              

	uint32_t m_maxConnect;
	std::string m_strIP;
	std::string m_masterName;
	int m_port;
	int m_cpuCount;
	bool m_isServer;           

	bool m_bWorking;       

	int64_t m_dwSendMsgTotal;         
	int64_t m_dwReceiveMsgTotal;       

	int64_t m_SendOneLoop;
	int64_t m_RecvOneLoop;

	struct event_base* m_eventBase;
	struct evconnlistener* m_eventListener;
	NET_RECEIVE_FUNCTOR m_consoleHandler;
};

#endif
