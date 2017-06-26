#include "telnet.h"
#include "LuaModule.h"

bool TelnetServer::UnpackRecvData(SocketSession* session)
{
	size_t recvLen = session->GetBuffLen();

	std::string a(session->GetBuff(), recvLen);
	_info("Telnet string is %s\n", session->GetBuff());
	char* enter = nullptr;
	int enterLength = 0;
#ifdef _LUNUX
	enter = "\n";
	enterLength = 1;
#else
	enter = "\r\n";
	enterLength = 2;
#endif // _LUNUX
	int end_pos = a.find(enter);
	_trace("Telnet string end %d", end_pos);
	if (end_pos != -1)
	{
		if (a.find("cmd_") == 0)
		{
			// console_commnad
			if (m_consoleHandler)
			{
				m_consoleHandler(session->GetSock(), session->GetBuff(), end_pos);
				SendMsg(m_masterName.c_str(), m_masterName.length(), session->GetSock());
				SendMsg("     Console Command OK\n", sizeof("     OK\n"), session->GetSock());
			}
		}
		else
		{
			std::string err;
			if (LuaModule::Instance()->RunMemory(session->GetBuff(), end_pos + enterLength, err))
			{
				SendMsg(m_masterName.c_str(), m_masterName.length(), session->GetSock());
				SendMsg("     Run LuaScript OK\n", sizeof("     OK\n"), session->GetSock());
			}
			else
			{
				SendMsg(err.c_str(), err.length(), session->GetSock());
				SendMsg("\n", sizeof("\n"), session->GetSock());
			}
		}

		session->RemoveBuff(0, end_pos + enterLength);
	}
	return false;
}

int TelnetServer::InitServerNet()
{
	int cpuCount = m_cpuCount;
	int port = m_port;

	struct sockaddr_in sin;

#ifdef _MSC_VER
	WSADATA wsa_data;
	WSAStartup(0x0201, &wsa_data);

#endif
	//////////////////////////////////////////////////////////////////////////

	struct event_config* cfg = event_config_new();

#ifdef _MSC_VER

	m_eventBase = event_base_new_with_config(cfg);

#else

	//event_config_avoid_method(cfg, "epoll");
	if (event_config_set_flag(cfg, EVENT_BASE_FLAG_EPOLL_USE_CHANGELIST) < 0)
	{
		//ʹ��EPOLL
		return -1;
	}

	if (event_config_set_num_cpus_hint(cfg, cpuCount) < 0)
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
		Final();

		return -1;
	}

	memset(&sin, 0, sizeof(sin));
	sin.sin_family = AF_INET;
	sin.sin_port = htons(port);

	printf("server started with %d\n", port);

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

	return m_maxConnect;
}

void TelnetServer::CloseSession(const int sock)
{
}

void TelnetServer::listener_cb(struct evconnlistener* listener, evutil_socket_t fd, struct sockaddr* sa, int socklen, void* user_data)
{
	TelnetServer* net = (TelnetServer*)user_data;
	bool bClose = net->CloseSocketSession(static_cast<const int>(fd));
	if (bClose)
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

	SocketSession* pSession = new SocketSession(dynamic_cast<INet*>(net), static_cast<int32_t>(fd), *pSin, bev);
	pSession->GetNet()->AddSocketSession(static_cast<int>(fd), pSession);

	bufferevent_setcb(bev, conn_readcb, conn_writecb, conn_eventcb, (void*)pSession);
	bufferevent_enable(bev, EV_READ | EV_WRITE);

	std::string welcome("Welcome to ");
	welcome += net->GetMasterName();
	welcome +="\n";
	net->SendMsg(welcome.c_str(), welcome.length(), fd);
	conn_eventcb(bev, BEV_EVENT_CONNECTED, (void*)pSession);
}



void TelnetServer::conn_readcb(struct bufferevent* bev, void* user_data)
{
	SocketSession* pSession = (SocketSession*)user_data;
	if (!pSession)
	{
		return;
	}

	TelnetServer* net = (TelnetServer*)pSession->GetNet();
	if (!net)
	{
		return;
	}

	if (pSession->NeedRemove())
	{
		return;
	}

	struct evbuffer* input = bufferevent_get_input(bev);
	if (!input)
	{
		return;
	}

	size_t len = evbuffer_get_length(input);

	char* strMsg = new char[len];

	if (evbuffer_remove(input, strMsg, len) > 0)
	{
		pSession->AddBuff(strMsg, len);
	}

	delete[] strMsg;

	while (1)
	{
		// true - a complete package
		// false - package not complete
		if (!net->UnpackRecvData(pSession))
		{
			break;
		}
	}
}

void TelnetServer::conn_writecb(bufferevent * bev, void * user_data)
{
}

void TelnetServer::conn_eventcb(struct bufferevent* bev, short events, void* user_data)
{
	SocketSession* pSession = (SocketSession*)user_data;
	TelnetServer* net = (TelnetServer*)pSession->GetNet();

	if (events & BEV_EVENT_CONNECTED)
	{
		net->m_bWorking = true;
	}
	else
	{
		if (!net->m_isServer)
		{
			net->m_bWorking = false;
		}
	}

	if (events & BEV_EVENT_CONNECTED)
	{
		//printf("%d Connection successed\n", pObject->GetFd());/*XXX win32*/
	}
	else
	{
		net->CloseSocketSession(pSession->GetSock());
	}
}

TelnetServer::TelnetServer()
{
	m_eventBase = NULL;
	m_eventListener = NULL;
	m_strIP = "";
	m_port = 0;
	m_cpuCount = 0;
	m_isServer = false;
}

bool TelnetServer::Tick()
{
	ExecuteClose();

	if (!m_eventBase)
	{
		_xerror("event_base is null");
		return false;
	}

	event_base_loop(m_eventBase, EVLOOP_ONCE | EVLOOP_NONBLOCK);
	return true;
}

int TelnetServer::Initialization(std::string masterName, const unsigned int nMaxClient, const unsigned short nPort, const int nCpuCount /*= 4*/)
{
	m_masterName = masterName;
	m_maxConnect = nMaxClient;
	m_port = nPort;
	m_cpuCount = nCpuCount;

	return InitServerNet();
}

void TelnetServer::Initialization(const char * strIP, const unsigned short nPort)
{
}

int TelnetServer::Initialization(const unsigned int nMaxClient, const unsigned short nPort, const int nCpuCount /*= 4*/)
{
	return 0;
}

bool TelnetServer::Final()
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

bool TelnetServer::CloseSocketSession(const int sock)
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

bool TelnetServer::AddSocketSession(const int sock, SocketSession * session)
{
	if (!m_isServer)
	{
		_info("ClientModule Connection Establish sock %d and ip %s and port %d and real sock is %d",
			sock, session->GetIP(), session->GetPort(), session->GetSock());
	}

	return m_sessionManager.insert(std::map<int, SocketSession*>::value_type(sock, session)).second;
}

SocketSession * TelnetServer::GetSocketSession(const int sock)
{
	std::map<int, SocketSession*>::iterator it = m_sessionManager.find(sock);
	if (it != m_sessionManager.end())
	{
		return it->second;
	}

	return nullptr;
}

bool TelnetServer::IsServer()
{
	return true;
}

bool TelnetServer::Log(int severity, const char * msg)
{
	return false;
}

bool TelnetServer::SendMsg(const char* data, const DATA_LENGTH_TYPE datatLength, const int sock)
{
	if (datatLength <= 0)
	{
		return false;
	}

	std::map<int, SocketSession*>::iterator it = m_sessionManager.find(sock);
	if (it != m_sessionManager.end())
	{
		SocketSession* pSession = (SocketSession*)it->second;
		if (pSession)
		{
			bufferevent* bev = pSession->GetBuffEvent();
			if (NULL != bev)
			{
				bufferevent_write(bev, data, datatLength);
				m_SendOneLoop++;
				m_dwSendMsgTotal++;
				return true;
			}
		}
	}
	else
	{
		_xerror("Failed find session of socket %d in Net::SendMsg", sock);
	}

	return false;
}

std::string TelnetServer::GetMasterName()
{
	return m_masterName;
}

void TelnetServer::ExecuteClose()
{
	for (uint32_t i = 0; i < m_removedSession.size(); ++i)
	{
		int sock = m_removedSession[i];
		CloseSession(sock);
	}

	m_removedSession.clear();
}

bool TelnetServer::CloseSocketAll()
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
