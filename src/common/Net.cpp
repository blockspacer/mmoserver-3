// -------------------------------------------------------------------------
//    @FileName         :    Net.cpp
//    @Author           :    hou(houontherun@gmail.com)
//    @Date             :    2016-7-15
//    @Module           :    
//    @Desc             :     
// -------------------------------------------------------------------------
#ifndef _LINUX
#pragma  comment(lib,"libevent.lib")
#pragma  comment(lib,"libevent_core.lib")
#endif

#include "Net.h"
#include "SocketSession.h"
#include <string.h>
#include "message.h"

#ifdef _MSC_VER
#include <WS2tcpip.h>
#include <winsock2.h>
#pragma  comment(lib,"Ws2_32.lib")
#endif

#include "event2/bufferevent_struct.h"
#include "event2/event.h"

/* TODO */
void Net::conn_writecb(struct bufferevent* bev, void* user_data)
{	
	//  struct evbuffer *output = bufferevent_get_output(bev);
	SocketSession* session = (SocketSession*)user_data;
	Net* net = (Net*)session->GetNet();
	net->m_sendCountTick++;
	net->m_sendMessageTotalCount++;
}

void Net::conn_eventcb(struct bufferevent* bev, short events, void* user_data)
{
	SocketSession* session = (SocketSession*)user_data;
	Net* net = (Net*)session->GetNet();

	if (events & BEV_EVENT_CONNECTED)
	{
		//must to set it's state before the "EventCB" functional be called[maybe user will send msg in the callback function]
		net->m_bWorking = true;
	}
	else
	{
		if (!net->m_isServer)
		{
			net->m_bWorking = false;
		}
	}

	if (net->m_eventCallBack)
	{
		net->m_eventCallBack(session->GetSock(), NET_EVENT(events), net);
	}

	if (events & BEV_EVENT_CONNECTED)
	{
		//evbuffer_expand doesn't work, max is 
		//struct evbuffer* input = bufferevent_get_input(bev);
		//struct evbuffer* output = bufferevent_get_output(bev);
		//evbuffer_expand(input, 1024 * 1024 * 2);
		//evbuffer_expand(output, 1024 * 1024 * 2);
	}
	else
	{
		net->CloseSocketSession(session->GetSock());
	}
}

void Net::listener_cb(struct evconnlistener* listener, evutil_socket_t fd, struct sockaddr* sa, int socklen, void* user_data)
{
	Net* net = (Net*)user_data;
	bool isClose = net->CloseSocketSession(static_cast<const int>(fd));
	if (isClose)
	{
		return;
	}

	if (net->m_sessionManager.size() >= net->m_maxConnect)
	{
		_xerror("Connection %d Too Much", net->m_sessionManager.size());
		return;
	}

	struct event_base* base = net->m_eventBase;

	struct bufferevent* bev = bufferevent_socket_new(base, fd, BEV_OPT_CLOSE_ON_FREE);
	if (!bev)
	{
		_xerror("Failed bufferevent_socket_new");
		fprintf(stderr, "Error constructing bufferevent!");
		return;
	}

	struct sockaddr_in* pSin = (sockaddr_in*)sa;

	SocketSession* session = new SocketSession(net, static_cast<int32_t>(fd), *pSin, bev);
	session->GetNet()->AddSocketSession(static_cast<int>(fd), session);

	bufferevent_setcb(bev, conn_readcb, conn_writecb, conn_eventcb, (void*)session);

	bufferevent_enable(bev, EV_READ | EV_WRITE);

	conn_eventcb(bev, BEV_EVENT_CONNECTED, (void*)session);
}

void Net::conn_readcb(struct bufferevent* bev, void* user_data)
{
	SocketSession* session = (SocketSession*)user_data;
	if (!session)
	{
		return;
	}

	Net* net = (Net*)session->GetNet();
	if (!net)
	{
		return;
	}

	if (session->NeedRemove())
	{
		return;
	}

	struct evbuffer* input = bufferevent_get_input(bev);
	if (!input)
	{
		return;
	}

	size_t len = evbuffer_get_length(input);
	net->m_recvCountTick ++;
	net->m_recvLengthTick += len;
	net->m_receiveMessageTotalCount++;
	net->m_receiveMessageTotalBytes += len;

	char* dataBuffer = new char[len];

	if (evbuffer_remove(input, dataBuffer, len) > 0)
	{
		session->AddBuff(dataBuffer, len);
	}

	delete[] dataBuffer;

	while (1)
	{
		// true - a complete package
		// false - package not complete
		if (!net->UnpackRecvData(session))
		{
			break;
		}
	}
}

// true -- busy
bool Net::Tick()
{
	m_tickCount++;
	m_sendCountTick = 0;
	m_sendLengthTick = 0;
	m_recvCountTick = 0;
	m_recvLengthTick = 0;

	ExecuteClose();
	
	if (!m_eventBase)
	{
		_xerror("event_base is null");
		return false;
	}
	//  @return 0 if successful, -1 if an error occurred, or 1 if we exited because
	//	no events were pending or active.
	// event_base_dispatch
	// 一次最多只读4096个字节，繁忙是不会
	m_sendCountTick = 0;
	m_recvCountTick = 0;
	int ret = event_base_loop(m_eventBase, EVLOOP_ONCE | EVLOOP_NONBLOCK);
	if (ret == 0)
	{
		if (m_recvCountTick)
		{
			//busy
			return true;
		}
	}
	else if (ret == 1)
	{
		return false;
	}
	else
	{
		_warn("error in event_base_loop");
		return false;
	}

	return false;
}


void Net::Initialization(const char* strIP, const unsigned short nPort)
{
	m_strIP = strIP;
	m_port = nPort;

	InitClientNet();
}

int Net::Initialization(const unsigned int nMaxClient, const unsigned short nPort, const int nCpuCount)
{
	m_maxConnect = nMaxClient;
	m_port = nPort;
	m_cpuCount = nCpuCount;

	return InitServerNet();
}

bool Net::Final()
{

	CloseSocketAll();

	if (m_eventListener)
	{
		evconnlistener_free(m_eventListener);
		m_eventListener = NULL;
	}

	if (!m_isServer)
	{
		if (m_eventBase)
		{
			event_base_free(m_eventBase);
			m_eventBase = NULL;
		}
	}

	return true;
}


bool Net::SendMsg(const char* data, const uint32_t dataLength, const int sock)
{
	if (dataLength <= 0)
	{
		return false;
	}

	std::map<int, SocketSession*>::iterator it = m_sessionManager.find(sock);
	if (it != m_sessionManager.end())
	{
		SocketSession* session = (SocketSession*)it->second;
		if (session)
		{
			//bufferevent* bev = session->GetBuffEvent();
			//if (bev != nullptr)
			//{
			//	bufferevent_write(bev, data, dataLength);
			//	m_sendCountTick++;
			//	m_sendMessageTotalCount++;
			//	m_sendMessageTotalBytes += dataLength;
			//	return true;
			//}
			session->SendData(data, dataLength);
			m_sendMessageTotalBytes += dataLength;
			m_sendLengthTick += dataLength;
		}
	}
	else
	{
		_xerror("Failed find session of socket %d in Net::SendMsg",sock);

	}

	return false;
}


bool Net::CloseSocketSession(const int sock)
{
	if (!m_isServer)
	{
		_info("ClientNetModule: Will CloseSocketSession of sock %d", sock);
	}
	std::map<int, SocketSession*>::iterator it = m_sessionManager.find(sock);
	if (it != m_sessionManager.end())
	{
		SocketSession* session = it->second;
		if (!m_isServer)
		{
			_info("ClientNetModule: CloseSocketSession of sock %d address is %s %d real sock is %d", 
				sock, session->GetIP().c_str(), session->GetPort(), session->GetSock());
		}
		session->SetNeedRemove(true);
		m_removedSession.push_back(sock);

		return true;
	}

	return false;
}


bool Net::UnpackRecvData(SocketSession* session)
{
	size_t recvLen = session->GetBuffLen();
	DATA_LENGTH_TYPE dataLength = 0;

	if (recvLen >= sizeof(DATA_LENGTH_TYPE))
	{
		dataLength = *((DATA_LENGTH_TYPE*)session->GetBuff());
		if (dataLength > MAX_RECVBUF_LEN) {
			_xerror("The message length %d overflow", dataLength);
			CloseSocketSession(session->GetSock());
			return false;
		}
		if (recvLen - sizeof(DATA_LENGTH_TYPE) >= dataLength)
		{
			if (m_recvCallBack)
			{
				m_recvCallBack(session->GetSock(), session->GetBuff() + sizeof(DATA_LENGTH_TYPE), dataLength);
				m_recvCountTick++;
				m_receiveMessageTotalCount++;
			}
			session->RemoveBuff(0, dataLength + sizeof(DATA_LENGTH_TYPE));
			UnpackRecvData(session); 
		}
		else 
		{
			return false;
		}
	}
	return false;
}


bool Net::AddSocketSession(const int sock, SocketSession* session)
{
	if (!m_isServer)
	{
		_info("ClientModule Connection Establish sock %d and ip %s and port %d and real sock is %d", 
				sock, session->GetIP().c_str(), session->GetPort(), session->GetSock());
	}

	return m_sessionManager.insert(std::map<int, SocketSession*>::value_type(sock, session)).second;
}

int Net::InitClientNet()
{
	std::string strIP = m_strIP;
	int nPort = m_port;

	struct sockaddr_in addr;
	struct bufferevent* bev = NULL;

#ifdef _MSC_VER
	WSADATA wsa_data;
	WSAStartup(0x0201, &wsa_data);
#endif

	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_port = htons(nPort);

	if (inet_pton(AF_INET, strIP.c_str(), &addr.sin_addr) <= 0)
	{
		printf("inet_pton");
		return -1;
	}

	m_eventBase = event_base_new();
	if (m_eventBase == NULL)
	{
		printf("event_base_new ");
		return -1;
	}

	bev = bufferevent_socket_new(m_eventBase, -1, BEV_OPT_CLOSE_ON_FREE);
	if (bev == NULL)
	{
		printf("bufferevent_socket_new ");
		return -1;
	}

	int bRet = bufferevent_socket_connect(bev, (struct sockaddr*)&addr, sizeof(addr));
	if (0 != bRet)
	{
		//int nError = GetLastError();
		printf("bufferevent_socket_connect error");
		return -1;
	}

	int32_t sockfd = static_cast<int32_t>(bufferevent_getfd(bev));
	SocketSession* session = new SocketSession(this, sockfd, addr, bev);
	if (!AddSocketSession(0, session))
	{
		//assert(0);
		return -1;
	}

	m_isServer = false;

	bufferevent_setcb(bev, conn_readcb, conn_writecb, conn_eventcb, (void*)session);
	bufferevent_enable(bev, EV_READ | EV_WRITE);

	event_set_log_callback(&Net::log_cb);
	//event_base_loop(base, EVLOOP_ONCE|EVLOOP_NONBLOCK);
	const char* pollname = event_base_get_method(m_eventBase);
	_info("The ClientPollName is %s", pollname);
	return sockfd;
}

int Net::InitServerNet()
{
	//int nMaxClient = m_maxConnect;
	int nCpuCount = 1;
	int nPort = m_port;

	struct sockaddr_in sin;

#ifdef _MSC_VER
	WSADATA wsa_data;
	WSAStartup(0x0201, &wsa_data);

#endif

	struct event_config* cfg = event_config_new();

#ifdef _MSC_VER
	m_eventBase = event_base_new_with_config(cfg);

#else

	//event_config_avoid_method(cfg, "epoll");
	if (event_config_set_flag(cfg, EVENT_BASE_FLAG_EPOLL_USE_CHANGELIST) < 0)
	{
		return -1;
	}

	if (event_config_set_num_cpus_hint(cfg, nCpuCount) < 0)
	{
		return -1;
	}

	m_eventBase = event_base_new_with_config(cfg);//event_base_new()

#endif
	event_config_free(cfg);

	//////////////////////////////////////////////////////////////////////////

	if (!m_eventBase)
	{
		fprintf(stderr, "Could not initialize libevent!\n");
		_xerror("Could not initialize libevent!");
		Final();

		return -1;
	}

	memset(&sin, 0, sizeof(sin));
	sin.sin_family = AF_INET;
	sin.sin_port = htons(nPort);

	_info("server started with %d\n", nPort);

	m_eventListener = evconnlistener_new_bind(m_eventBase, listener_cb, (void*)this,
		LEV_OPT_REUSEABLE | LEV_OPT_CLOSE_ON_FREE, -1,
		(struct sockaddr*)&sin,
		sizeof(sin));

	if (!m_eventListener)
	{
		fprintf(stderr, "Could not create a listener!\n");
		Final();

		return -1;
	}

	m_isServer = true;

	event_set_log_callback(&Net::log_cb);
	const char* pollname = event_base_get_method(m_eventBase);
	_info("The PollName is %s", pollname);
	return m_maxConnect;
}

const char* Net::GetPollName()
{
	const char* pollname = event_base_get_method(m_eventBase);
	_info("The PollName is %s", pollname);
	return pollname;
}

bool Net::CloseSocketAll()
{
	for (auto it = m_sessionManager.begin(); it != m_sessionManager.end(); ++it)
	{
		int sock = it->first;
		m_removedSession.push_back(sock);
	}

	ExecuteClose();

	m_sessionManager.clear();

	return true;
}

SocketSession* Net::GetSocketSession(const int sock)
{
	std::map<int, SocketSession*>::iterator it = m_sessionManager.find(sock);
	if (it != m_sessionManager.end())
	{
		return it->second;
	}

	return NULL;
}

void Net::CloseSession(const int sock)
{
	std::map<int, SocketSession*>::iterator it = m_sessionManager.find(sock);
	if (it != m_sessionManager.end())
	{
		SocketSession* session = it->second;

		struct bufferevent* bev = session->GetBuffEvent();

		bufferevent_free(bev);

		m_sessionManager.erase(it);

		delete session;
		session = NULL;
	}
}

void Net::ExecuteClose()
{
	for (uint32_t i = 0; i < m_removedSession.size(); ++i)
	{
		int sock = m_removedSession[i];
		CloseSession(sock);
	}

	m_removedSession.clear();
}

void Net::log_cb(int severity, const char* msg)
{

}

bool Net::IsServer()
{
	return m_isServer;
}

bool Net::Log(int severity, const char* msg)
{
	log_cb(severity, msg);
	return true;
}

