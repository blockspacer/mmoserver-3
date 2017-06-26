#include "GameManagerClientModule.h"
#include "message/servermessage.pb.h"
#include "ServerConfigure.h"

bool GameManagerClientModule::Init(SERVERID masterServerID)
{
	m_masterServerID = masterServerID;

	if (!m_gamemanagerClient.Init())
	{
		_xerror("Failed Init GameClientNetModule");
		return false;
	}

	m_gamemanagerClient.AddReceiveCallBack(this, &GameManagerClientModule::OnMessage);
	m_gamemanagerClient.AddEventCallBack(this, &GameManagerClientModule::OnSocketEventOfGameManager);

	std::shared_ptr<ServerHolder> gamemanagerConfigure = ServerConfigure::Instance()->GetServerHolder(0, SERVER_TYPE_GAMEMANAGER);
	if (!gamemanagerConfigure)
	{
		_xerror("Failed Get gamemanagerConfigure");
		assert(false);
		return false;
	}

	ConnectData xServerData;
	xServerData.serverID = gamemanagerConfigure->serverID;
	xServerData.strIP = gamemanagerConfigure->connectIP;
	xServerData.nPort = gamemanagerConfigure->listenPort;
	xServerData.strName = gamemanagerConfigure->serverName;

	m_gamemanagerClient.AddServer(xServerData);
	SetGameManagerClient(this);
	return true;
}

bool GameManagerClientModule::Tick()
{
	uint64_t now = GetNowTimeSecond();
	m_gamemanagerClient.Tick();
	if (m_lastSendHeartbeatTime != 0 && m_lastSendHeartbeatTime + 10 < now)
	{
		KeepLive();
		m_lastSendHeartbeatTime = now;
	}
	if (m_lastRecvHeartbeatTime != 0 && (m_lastRecvHeartbeatTime + 20) < now)
	{
		_xerror("GameManagerLoseConnection");
	}
	return true;
}

void GameManagerClientModule::KeepLive()
{
	SendDataToGameManager(gamemanager::GAMEMANAGER_SERVICE_HEARTBEAT, nullptr, 0);
}

void GameManagerClientModule::OnSocketEventOfGameManager(const int sock, const NET_EVENT eEvent, INet * net)
{
	if (eEvent & NET_EVENT_EOF)
	{
		_xerror("GameManager Connect Close");
		OnGameManagerDisconnect();
	}
	else if (eEvent & NET_EVENT_ERROR)
	{
		_xerror("GameManager Connect Error");
		OnGameManagerDisconnect();
	}
	else if (eEvent & NET_EVENT_TIMEOUT)
	{
		_xerror("GameManager Connect Timeout");
		OnGameManagerDisconnect();
	}
	else  if (eEvent == NET_EVENT_CONNECTED)
	{
		_info("GameManager Connected");
		Register(net);
	}
}

void GameManagerClientModule::OnMessage(const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	//TODO 要么注册处理函数进来,要么提供一个基类的接口
	ServerMessageHead* head = (ServerMessageHead*)data;
	if (head->ServiceType == gamemanager::GAMEMANAGER_CLIENT_HEARTBEAT)
	{
		m_lastRecvHeartbeatTime = GetNowTimeSecond();
		return;
	}
	auto it = m_ServerMessageHandlers.find(head->ServiceType);
	if (it != m_ServerMessageHandlers.end())
	{
		SERVER_MESSAGE_HANDLER_PTR& ptr = it->second;
		SERVER_MESSAGE_HANDLER* functor = ptr.get();
		functor->operator()(head, sock, data + SERVER_MESSAGE_HEAD_LENGTH, dataLength - SERVER_MESSAGE_HEAD_LENGTH);
	}
	else
	{
		_info("Failed find handle of service %d", head->ServiceType);
	}
}

void GameManagerClientModule::SendMessageToGameManager(const uint16_t serviceType, IMessage * message)
{
	if (!message)
	{
		return;
	}
	uint16_t headLength = GetPackServerMessageHeadLength();
	if (!message->SerializeToArray(m_sendBuff + headLength, sizeof(m_sendBuff) - headLength))
	{
		_xerror("DBClientModule::SendMessageToDBProxy failed because %s", message->Utf8DebugString());
		return;
	}
	SendDataToGameManager(serviceType, m_sendBuff + headLength, message->ByteSize());
}

void GameManagerClientModule::SendDataToGameManager(const uint16_t serviceType, const char *data, const DATA_LENGTH_TYPE dataLength)
{
	std::shared_ptr<ServerHolder> gamemanager = ServerConfigure::Instance()->GetServerHolder(0, SERVER_TYPE_GAMEMANAGER);
	if (!gamemanager)
	{
		_xerror("Failed Find GameManager");
		assert(!"Failed Find GameManager");
		return;
	}
	int dstServerID = gamemanager->serverID;
	uint32_t headLength = PackServerMessageHead(dstServerID, serviceType, dataLength);
	if (dataLength + headLength > MAX_SENDBUF_LEN)
	{
		_xerror("DataLength %d overflow", dataLength);
		assert(false);
		return;
	}
	if (data && data != (m_sendBuff + headLength))
	{
		memcpy(m_sendBuff + headLength, data, dataLength);
	}

	m_gamemanagerClient.SendByServerID(dstServerID, m_sendBuff, dataLength + headLength);
}

void GameManagerClientModule::ForwardDataToGame(SERVERID dstServerID, const uint16_t serviceType, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	uint32_t headLength = PackServerMessageHead(dstServerID, serviceType, dataLength);
	if (dataLength + headLength > MAX_SENDBUF_LEN)
	{
		_xerror("DataLength %d overflow", dataLength);
		assert(false);
		return;
	}
	if (data && data != (m_sendBuff + headLength))
	{
		memcpy(m_sendBuff + headLength, data, dataLength);
	}

	std::shared_ptr<ServerHolder> gamemanager = ServerConfigure::Instance()->GetServerHolder(0, SERVER_TYPE_GAMEMANAGER);
	if (!gamemanager)
	{
		_xerror("Failed Find GameManager");
		assert(!"Failed Find GameManager");
		return;
	}
	m_gamemanagerClient.SendByServerID(gamemanager->serverID, m_sendBuff, dataLength + headLength);
}

bool GameManagerClientModule::IsReady()
{
	return m_isReady;
}

void GameManagerClientModule::CheckHeartbeat()
{
}


void GameManagerClientModule::Register(INet* net)
{
	NF_SHARE_PTR<ConnectData> serverData = m_gamemanagerClient.GetServerNetInfo(net);
	if (serverData)
	{
		GS_REGISTER_SERVER registerMessage;
		int serverType = ServerConfigure::Instance()->GetServerType(m_masterServerID);
		std::shared_ptr<ServerHolder> selfConfig = ServerConfigure::Instance()->GetServerHolder(m_masterServerID, serverType);
		if (!selfConfig)
		{
			_xerror("Wrong MasterID %d : No Configure Find", m_masterServerID);
			return;
		}

		registerMessage.set_serverid(selfConfig->serverID);
		registerMessage.set_servertype(selfConfig->serverType);
		registerMessage.set_port(selfConfig->listenPort);
		registerMessage.set_ip(selfConfig->listenIP);
		SendMessageToGameManager(gamemanager::GAMEMANAGER_SERVICE_REGISTER_SERVER, &registerMessage);
		_info("Register to GameManager");
		m_isReady = true;
	}
	else
	{
		_xerror("Failed find ServerInfo");
	}
}

uint32_t GameManagerClientModule::PackServerMessageHead(const int dstServerID, const int serviceType, const DATA_LENGTH_TYPE dataLength)
{
	ServerMessageHead* head = (ServerMessageHead*)(m_sendBuff + NET_HEAD_LENGTH);
	head->ServiceType = serviceType;
	head->DstServerID = dstServerID;
	head->SrcServerID = m_masterServerID;

	DATA_LENGTH_TYPE* pTotalLen = (DATA_LENGTH_TYPE*)m_sendBuff;
	*pTotalLen = SERVER_MESSAGE_HEAD_LENGTH + dataLength;
	// 消息流的长度包括包的长度以及包头长度
	return SERVER_MESSAGE_HEAD_LENGTH + NET_HEAD_LENGTH;
}

void GameManagerClientModule::OnGameManagerDisconnect()
{
	_xerror("GameManagerClientModule Lose Connection");
	m_lastRecvHeartbeatTime = 0;
	m_lastSendHeartbeatTime = 0;
}

GameManagerClientModule* gGameManagerClient;

void SetGameManagerClient(GameManagerClientModule* g)
{
	gGameManagerClient = g;
}

static int lua_send_message_to_gamemanager(lua_State *L)
{
	int GMClientID = static_cast<MESSAGEID>(luaL_checknumber(L, 1));
	size_t n = 0;
	const char* data = luaL_checklstring(L, 2, &n);

	std::string param(data, n);
	SC_Lua_RunRequest reply;
	reply.set_opcode(GMClientID);
	reply.set_parameters(param);

	GlobalGameManagerClient->SendMessageToGameManager(gamemanager::GAMEMANAGER_SERVICE_RUN_SCRIPT_REPLY, &reply);
	return 0;
}

extern "C" void luaopen_gamemanagerfunction(lua_State * L)
{
	lua_register(L, "_send_to_gamemanager", lua_send_message_to_gamemanager);
}
