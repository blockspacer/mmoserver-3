#include "BaseGateServerModule.h"
#include "message.h"
#include "message/LuaMessage.pb.h"
#include "SocketSession.h"


bool BaseGateServerModule::Init(uint32_t maxClients, int port)
{
	if (!m_netModule.InitAsServer(maxClients, port))
	{
		assert(false);
		return false;
	}

	auto a = m_netModule.GetNet()->GetPollName();

	m_netModule.AddReceiveCallBack(this, &BaseGateServerModule::OnMessage);
	m_netModule.AddEventCallBack(this, &BaseGateServerModule::OnSocketClientEvent);

	for (uint32_t i = 1; i < maxClients * 5; ++i)
	{
		m_SessionIDPoll.push_back(i);
	}

	CTimerMgr::Instance()->CreateTimer(0, this, &BaseGateServerModule::ShowDebugInfo, 3000, 3000);
	return true;
}

void BaseGateServerModule::OnMessage(const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	if (GlobalGateServer->IsIgnoreClientMessage())
	{
		_info("Server Ignore Client Message");
		return;
	}

	if (data == NULL || dataLength < sizeof(ClientMessageHead))
	{
		return;
	}
	if (dataLength > MAX_RECVBUF_LEN)
	{
		_warn("ClientDataLength %d overflow", dataLength);
		return;
	}

	memcpy(m_recvBuff, data, dataLength);

	// Decode
	m_recvBuff[dataLength - 1] ^= 0x3A;
	for (int i = dataLength - 2; i >= 0; --i)
	{
		m_recvBuff[i] ^= m_recvBuff[i + 1];
	}

	SocketSession* session = m_netModule.GetNet()->GetSocketSession(sock);
	if (!session)
	{
		_xerror("Failed get session");
		return;
	}
	SESSIONID sessionID = session->GetSessionID();
	if (!CheckClientData(sessionID))
	{
		_xerror("Failed CheckClientData sessionid %llu and will kick off user", sessionID);
		KickOff(sessionID);
		return;
	}

	if (true)
	{
		ProcessClientMessage(session, m_recvBuff, dataLength);
	}
	else if (false)
	{
		int serviceType = 0;
		ProcessServiceMessage(session, serviceType, m_recvBuff, dataLength);
	}
	
}

uint32_t BaseGateServerModule::PackClientMessageHead(const SESSIONID sessionID, const int serverID, const MESSAGEID messageID, const DATA_LENGTH_TYPE dataLength)
{
	ClientMessageHead* messageHead = (ClientMessageHead*)(m_sendBuff + NET_HEAD_LENGTH);
	messageHead->MessageID = messageID;
	messageHead->ServiceType = 0;
	DATA_LENGTH_TYPE* totalLen = (DATA_LENGTH_TYPE*)m_sendBuff;
	*totalLen = dataLength + CLIENT_MESSAGE_HEAD_LENGTH;
	return CLIENT_MESSAGE_HEAD_LENGTH + NET_HEAD_LENGTH;
}

SESSIONID BaseGateServerModule::GenerateSessionID()
{
	if (m_SessionIDPoll.empty())
	{
		_xerror("The sessionIDPoll is empty");
		return 0;
	}
	uint64_t sid = m_SessionIDPoll.front();
	m_SessionIDPoll.pop_front();

	uint64_t  tmp = (GetNowTimeSecond()%400597);
	tmp = tmp << 32;
	tmp = tmp + ((GlobalGateServer->GetServerID() & 0xffff)<< 16);
	tmp = tmp + (sid & 0xffff);
	return  tmp;
}

void BaseGateServerModule::RecycleSessionID(SESSIONID sid)
{
	uint32_t id = static_cast<uint32_t>(sid & 0xffff);
	m_SessionIDPoll.push_back(id);
}

int BaseGateServerModule::GetClientSocketBySession(SESSIONID clientSession)
{
	auto it = m_session2socket.find(clientSession);
	if (it == m_session2socket.end())
	{
		return INVALID_SOCKET_ID;
	}
	return it->second;
}

bool BaseGateServerModule::CheckClientData(SESSIONID sid)
{
	auto it = m_clientStatisData.find(sid);
	if (it == m_clientStatisData.end())
	{
		std::shared_ptr<ClientPkgStatis> clientStatisPtr(new ClientPkgStatis);
		m_clientStatisData[sid] = clientStatisPtr;
	}

	it = m_clientStatisData.find(sid);
	std::shared_ptr<ClientPkgStatis> tmp = it->second;
	ClientPkgStatis* tmpclient = tmp.get();
	uint64_t now = GetNowTimeMille();
	if ((now - tmpclient->lastRecvPkgTimeMillo) < 50)
	{
		tmpclient->recvCount++;
	}
	else
	{
		tmpclient->recvCount = 0;
	}

	tmpclient->lastRecvPkgTimeMillo = now;

	if (tmpclient->recvCount > 100)
	{
		return false;
	}
	return true;
}

void BaseGateServerModule::ShowDebugInfo(int a)
{
	_debug("%d Client Connection In Server", m_connectionCount);
}

void BaseGateServerModule::OnSocketClientEvent(const int sock, const NET_EVENT eEvent, INet* net)
{
	if (eEvent & NET_EVENT_EOF)
	{
		_info("Connection Close");
		OnConnectionClose(sock);
		m_connectionCount--;
	}
	else if (eEvent & NET_EVENT_ERROR)
	{
		_info("Connection Error");
		OnConnectionClose(sock);
		m_connectionCount--;
	}
	else if (eEvent & NET_EVENT_TIMEOUT)
	{
		_info("Connection Timeout");
		OnConnectionClose(sock);
		m_connectionCount--;
	}
	else  if (eEvent == NET_EVENT_CONNECTED)
	{
		_info("Connection Connected");
		OnNewConnection(sock);
		m_connectionCount++;
	}
}

bool BaseGateServerModule::OnNewConnection(int sock)
{
	if (GlobalGateServer->IsForbidNewConnection())
	{
		_xerror("Server forbid new connection, close this connection");
		m_netModule.GetNet()->CloseSocketSession(sock);
		return true;
	}

	// manager session and sock
	SESSIONID  clientSessionID = GenerateSessionID();
	SocketSession*  session = m_netModule.GetNet()->GetSocketSession(sock);
	if (!session)
	{
		_xerror("The session of socket %d is null", sock);
		return false;
	}
	session->SetSessionID(clientSessionID);

	AddSession(clientSessionID, sock);
	return true;
}

void BaseGateServerModule::SendMessageToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage* message)
{
	std::string data;
	if (!message->SerializeToString(&data))
	{
		_xerror("SerializeToArray failed messageID is %d reason is %s", messageID, message->Utf8DebugString().c_str());
		return;
	}

	try
	{
		SendDataToClient(clientSessionID,  messageID, data.c_str(), message->ByteSize());
	}
	catch (const MyException& e)
	{
		_xerror(e.GetMsg().c_str());
	}
}

void BaseGateServerModule::SendDataToClient(const SESSIONID clientSessionID, const MESSAGEID messageID, const char * data, const DATA_LENGTH_TYPE dataLength)
{
#ifdef _DEBUG
	switch (messageID)
	{

	case  SERVER_MESSAGE_OPCODE_LUA_MESSAGE:
	{
		SC_Lua_RunRequest message;
		if (!message.ParseFromArray(data, dataLength))
		{
			_warn("Failed Parse:SendDataToClient sessionID %lld MessageID %d dataLength %d", clientSessionID, messageID, dataLength);
		}
		else
		{
			_trace("SendDataToClient sessionID %lld MessageID %d dataLength %d EntityLua Opcode %d", clientSessionID, messageID, dataLength, message.opcode());
		}
	}
		break;
	case  SERVER_MESSAGE_OPCODE_MOVE:
		_info("aa");
	case  SERVER_MESSAGE_OPCODE_STOP_MOVE:
	case  SERVER_MESSAGE_FORCE_POSITION:
	case  SERVER_MESSAGE_OPCODE_TURN_DIRECTION:
	case  SERVER_MESSAGE_OPCODE_CREATE_ENTITY:
	case  SERVER_MESSAGE_OPCODE_DESTROY_ENTITY:
	case  SERVER_MESSAGE_OPCODE_PING_BACK:
		_trace("SendDataToClient sessionID %lld MessageID %d dataLength %d", clientSessionID, messageID, dataLength);
		break;
	default:
		_warn("Opcode Not Found: SendDataToClient sessionID %lld MessageID %d dataLength %d", clientSessionID, messageID, dataLength);
		break;
	}
#endif
	uint32_t headLength = PackClientMessageHead(clientSessionID, 0, messageID, dataLength);
	if (sizeof(m_sendBuff) < dataLength + headLength)
	{
		_xerror("DataSize %d Overflow", dataLength + headLength);
		return;
	}
	memcpy(m_sendBuff + headLength, data, dataLength);

	int sock = GetClientSocketBySession(clientSessionID);
	if (sock == INVALID_SOCKET_ID)
	{
		_trace("Failed find socket of clientSessionID %lld", clientSessionID);
		return;
	}

	m_netModule.SendData(m_sendBuff, dataLength + headLength, sock);
}

void BaseGateServerModule::BroadcastDataToClient(EntityMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	// TODO ³óÂªµÄ´úÂë
	int country = head->ClientSessionID;
	uint32_t headLength = PackClientMessageHead(0, 0, head->MessageID, dataLength);
	if (sizeof(m_sendBuff) < dataLength + headLength)
	{
		_xerror("DataSize %d Overflow", dataLength + headLength);
		return;
	}
	memcpy(m_sendBuff + headLength, data, dataLength);

	for (auto it = m_session2socket.begin(); it != m_session2socket.end(); ++it)
	{
		int sock = it->second;
		SocketSession* session = m_netModule.GetNet()->GetSocketSession(sock);
		if (session == nullptr)
		{
			continue;
		}
		if (country != 0 && country != session->GetCountry())
		{
			continue;
		}
		session->SendData(m_sendBuff, dataLength + headLength);
		//m_netModule.SendData(m_sendBuff, dataLength + headLength, sock);
	}
}


bool BaseGateServerModule::KickOff(SESSIONID clientSessionID)
{
	int sock = GetClientSocketBySession(clientSessionID);
	if (sock == INVALID_SOCKET_ID)
	{
		_xerror("KickOff Failed find sock of clientSession %llu", clientSessionID);
		return false;
	}
	OnConnectionClose(sock);
	return m_netModule.CloseSession(sock);
}

void BaseGateServerModule::SendData(const char* data, DATA_LENGTH_TYPE dataLength, const int sock)
{
	m_netModule.SendData(data, dataLength, sock);
}

NetModule * BaseGateServerModule::GetServerNetModule()
{
	return &m_netModule;
}

void BaseGateServerModule::AddSession(SESSIONID clientSessionID, int sock)
{
	if (m_session2socket.find(clientSessionID) != m_session2socket.end())
	{
		_warn("clientSessionID already exist");
	}
	m_session2socket[clientSessionID] = sock;
}

void BaseGateServerModule::DeleteSession(SESSIONID sid)
{
	m_session2socket.erase(sid);
}


bool BaseGateServerModule::Tick()
{
	m_netModule.Tick();
	CTimerMgr::Instance()->Tick();
	return true;
}
