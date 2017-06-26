#ifndef __NET_H__
#define __NET_H__

#include "INet.h"

#pragma pack(push, 1)


class Net : public INet
{
public:
	Net()
	{
		m_eventBase = NULL;
		m_eventListener = NULL;

		m_strIP = "";
		m_port = 0;
		m_cpuCount = 0;
		m_isServer = false;
	}

	template<typename BaseType>
	Net(BaseType* pBaseType, void (BaseType::*handleRecieve)(const uint32_t, const char*, const uint32_t), void (BaseType::*handleEvent)(const uint32_t, const NET_EVENT, INet*))
	{
		m_eventBase = NULL;
		m_eventListener = NULL;

		m_recvCallBack = std::bind(handleRecieve, pBaseType, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3);
		m_eventCallBack = std::bind(handleEvent, pBaseType, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3);
		m_strIP = "";
		m_port = 0;
		m_cpuCount = 0;
		m_isServer = false;
	}

	virtual ~Net() {};

public:
	virtual bool Tick();

	virtual void Initialization(const char* strIP, const unsigned short nPort);
	
	virtual int Initialization(const unsigned int nMaxClient, const unsigned short nPort, const int nCpuCount = 4);

	virtual bool Final();

	virtual bool CloseSocketSession(const int nSockIndex);
	virtual bool AddSocketSession(const int nSockIndex, SocketSession* pObject);
	virtual SocketSession* GetSocketSession(const int nSockIndex);

	virtual bool IsServer();
	virtual bool Log(int severity, const char* msg);

	bool SendMsg(const char* data, const uint32_t dataLength, const int sock);

	const char* GetPollName();

private:
	void ExecuteClose();
	bool CloseSocketAll();

	bool UnpackRecvData(SocketSession* session);


	int InitClientNet();
	int InitServerNet();

	void CloseSession(const int nSockIndex);

	static void listener_cb(struct evconnlistener* listener, evutil_socket_t fd, struct sockaddr* sa, int socklen, void* user_data);
	static void conn_readcb(struct bufferevent* bev, void* user_data);
	static void conn_writecb(struct bufferevent* bev, void* user_data);
	static void conn_eventcb(struct bufferevent* bev, short events, void* user_data);
	static void log_cb(int severity, const char* msg);


private:
	std::map<int, SocketSession*> m_sessionManager;  
	std::vector<int> m_removedSession;               

	uint32_t m_maxConnect;
	std::string m_strIP;
	int m_port;
	int m_cpuCount;
	bool m_isServer;           

	bool m_bWorking;         

	struct event_base* m_eventBase;
	struct evconnlistener* m_eventListener;

	NET_RECEIVE_FUNCTOR m_recvCallBack;
	NET_EVENT_FUNCTOR m_eventCallBack;
};

#pragma pack(pop)

#endif
