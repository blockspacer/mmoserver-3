#include "GameClientModule.h"
#include "message/servermessage.pb.h"
#include "GateLuaModule.h"
#include "ServerConfigure.h"
#include "message/LuaMessage.pb.h"

GameClientModule::GameClientModule() : m_configServerCount(0), m_connectedServerCount(0)
{
}

GameClientModule::~GameClientModule()
{

}

bool GameClientModule::Init()
{
	if (!m_gameClientManager.Init())
	{
		_xerror("Failed Init GameClientNetModule");
		return false;
	}

	m_gameClientManager.AddReceiveCallBack(this, &GameClientModule::OnMessage);

	m_gameClientManager.AddEventCallBack(this, &GameClientModule::OnSocketEventOfGameServer);

	std::set<SERVERID> allGame;
	ServerConfigure::Instance()->GetServersOfType(SERVER_TYPE_GAME, allGame);
	for (auto it = allGame.begin(); it != allGame.end(); ++it)
	{
		SERVERID gameid = *it;
		std::shared_ptr<ServerHolder> gameserver = ServerConfigure::Instance()->GetServerHolder(gameid, SERVER_TYPE_GAME);
		if (!gameserver)
		{
			_xerror("Failed Find GameServer");
			assert(!"Failed Find GameServer");
			return false;
		}
		ConnectData serverData;
		serverData.serverID = gameserver->serverID;
		serverData.strIP = gameserver->connectIP;
		serverData.nPort = gameserver->listenPort;
		serverData.strName = gameserver->serverName;

		m_gameClientManager.AddServer(serverData);
	}

	return true;
}

bool GameClientModule::Tick()
{
	if (GetNowTimeMille() - m_lastSendHeartbeatTime > 10000)
	{
		m_lastSendHeartbeatTime = GetNowTimeMille();
		BroadcastDataToAllGame(game::GAMESERVICE_HEARTBEAT, 0, nullptr, 0);
	}
	return m_gameClientManager.Tick();
}

void GameClientModule::OnSocketEventOfGameServer(const int sock, const NET_EVENT event, INet* net)
{
	if (event & NET_EVENT_EOF)
	{
		_xerror("GameClientModule Connect Close");
	}
	else if (event & NET_EVENT_ERROR)
	{
		_xerror("GameClientModule Connect Error");
	}
	else if (event & NET_EVENT_TIMEOUT)
	{
		_xerror("GameClientModule Connect Timeout");
	}
	else  if (event == NET_EVENT_CONNECTED)
	{
		_info("GameClientModule Connected");
		++m_connectedServerCount;
		Register(net);
	}
}

void GameClientModule::Register(INet* net)
{
	NF_SHARE_PTR<ConnectData> pServerData = m_gameClientManager.GetServerNetInfo(net);
	if (pServerData)
	{
		std::shared_ptr<ServerHolder> self = ServerConfigure::Instance()->GetServerHolder(GlobalGateServer->GetServerID(), GlobalGateServer->GetServerType());
		if (!self)
		{
			_xerror("Failed Find Self Config");
			//assert("Failed Find Self Config");
			return;
		}
		int dstGameID = pServerData->serverID;
		GS_REGISTER_SERVER registerMessage;
		registerMessage.set_serverid(GlobalGateServer->GetServerID());
		registerMessage.set_servertype(GlobalGateServer->GetServerType());
		registerMessage.set_port(self->listenPort);
		registerMessage.set_ip(self->connectIP);
		SendMessageToGameServer(dstGameID, game::GAMESERVICE_REGISTER_GATE, &registerMessage);
		_info("Register Gate2Game of GateID %d and GameID %d", GlobalGateServer->GetServerID(), dstGameID);
	}
	else
	{
		_xerror("Failed find ServerInfo of connected server");
	}
}

void GameClientModule::OnAckEnterGame(const int sock, const int nMsgID, const char* msg, const DATA_LENGTH_TYPE dataLength)
{

}

void GameClientModule::NotifyClientConnectionClose(const SESSIONID clientSession, const SERVERID gameid)
{
	GS_CLIENT_DISCONNECT message;
	message.set_sessionid(clientSession);
	SendMessageToGameServer(gameid, game::GAMESERVICE_NOTIFY_CLIENT_DISCONNECT, &message);
}

void GameClientModule::OnMessage(const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	ServerMessageHead* head = (ServerMessageHead*)data;
	uint16_t headLength = SERVER_MESSAGE_HEAD_LENGTH;

	switch (head->ServiceType)
	{
	case game::GAMECLIENT_BROADCAST_TO_CLIENT:
		OnBroadcastToClient(head, data + headLength, dataLength - headLength);
		break;
	case game::GAMECLIENT_NOTIFY_KICK_CLIENT:
		OnKickClientOffline(head, data + headLength, dataLength - headLength);
		break;
	case game::GAMECLIENT_FORWARD_MESSAGE:
		OnForwardMessage(head, data + headLength, dataLength - headLength);
		break;
	case game::GAMECLIENT_BROADCAST_TO_GAME:
		OnBroadcastToGame(head, data + headLength, dataLength - headLength);
		break;
	case game::GAMECLIENT_REGISTER_SERVICE:
		OnRegisterService(head, data + headLength, dataLength - headLength);
		break;
	case game::GAMECLIENT_ENTITY_MESSAGE:
		OnEntityMessage(head, data + headLength, dataLength - headLength);
		break;
	case game::GAMECLIENT_PING_GATE:
		OnGamePingMessage(head, data + headLength, dataLength - headLength);
		break;
	//case gate::GATESERVICE_AVATAR_INFO:
	//	OnAvatarInfo(head, data + headLength, dataLength - headLength);
	//	break;
	case SERVER_OPCODE_AVATAR_CHANGER_GAME:
		OnAvatarChangeGame(head, data + headLength, dataLength - headLength);
		break;
	default:
		GlobalGateServerModule->OnGameServerMessage(head, data + headLength, dataLength - headLength);
		break;
	}
}

uint32_t GameClientModule::PackServerMessageHead(const SERVERID srcServerID, const SERVERID dstServerID, const int serviceType, const DATA_LENGTH_TYPE messageLength)
{
	ServerMessageHead* head = (ServerMessageHead*)(m_sendBuff + NET_HEAD_LENGTH);
	head->SrcServerID = srcServerID;
	head->DstServerID = dstServerID;
	head->ServiceType = serviceType;

	DATA_LENGTH_TYPE* pTotalLen = (DATA_LENGTH_TYPE*)m_sendBuff;
	*pTotalLen = SERVER_MESSAGE_HEAD_LENGTH + messageLength;
	return SERVER_MESSAGE_HEAD_LENGTH + NET_HEAD_LENGTH;
}

void GameClientModule::GetAllValidGameServer(std::set<SERVERID>& outServers)
{
	auto servers = m_gameClientManager.GetServerList();
	NF_SHARE_PTR<ConnectData> pServer = servers.First();
	while (pServer)
	{
		SERVERID gameID = pServer->serverID;
		outServers.insert(gameID);
		pServer = servers.Next();
	}
}

void GameClientModule::SendEntityMessage(SESSIONID sid, SERVERID gameid, ClientMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength)
{
#ifdef _DEBUG
	switch (head->MessageID)
	{
	case  CLIENT_MESSAGE_LUA_MESSAGE:
	{
		CS_Lua_RunRequest message;
		if (!message.ParseFromArray(data, dataLength))
		{
			_warn("Failed Parse:SendEntityMessage sessionID %lld MessageID %d dataLength %d", sid, head->MessageID, dataLength);
		}
		else
		{
			_trace("SendEntityMessage sessionID %lld MessageID %d dataLength %d EntityLua Opcode %d", sid, head->MessageID, dataLength, message.opcode());
		}
	}
	break;
	case CLIENT_MESSAGE_OPCODE_MOVE :
	case CLIENT_MESSAGE_OPCODE_STOP_MOVE:
	case CLIENT_MESSAGE_FORCE_POSITION:
	case CLIENT_MESSAGE_OPCODE_TURN_DIRECTION:
	case CLIENT_MESSAGE_OPCODE_PING:
	case CLIENT_MESSAGE_OPCODE_PING_BACK:
		_trace("SendEntityMessage sessionID %lld MessageID %d dataLength %d", sid, head->MessageID, dataLength);
		break;
	default:
		_warn("Opcode Not Found: SendEntityMessage sessionID %lld MessageID %d dataLength %d", sid, head->MessageID, dataLength);
		break;
	}
#endif

	uint32_t headLength = NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH;
	uint32_t totalHeadLength = headLength + ENTITY_MESSAGE_HEAD_LENGTH;
	if (dataLength + totalHeadLength > MAX_SENDBUF_LEN)
	{
		_xerror("DataLength %d overflow", dataLength + totalHeadLength);
		return;
	}
	EntityMessageHead* entityMessageHead = (EntityMessageHead*)(m_sendBuff + headLength);
	entityMessageHead->MessageID = head->MessageID;
	entityMessageHead->ClientSessionID = sid;
	entityMessageHead->ClientID = 0;

	if (sizeof(m_sendBuff) < dataLength + totalHeadLength)
	{
		_xerror("DataSize %d Overflow", dataLength + headLength);
		return;
	}
	memcpy(m_sendBuff + totalHeadLength, data, dataLength);

	SendDataToGameServer(gameid, game::GAMESERVICE_ENTITY_MESSAGE, m_sendBuff + headLength, dataLength + ENTITY_MESSAGE_HEAD_LENGTH);
}

void GameClientModule::SendMessageToGameServer(const int gameid, const int serviceType, IMessage * message)
{
	if (!message)
	{
		return;
	}
	int headLength = NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH;
	if (!message->SerializeToArray(m_sendBuff + headLength, MAX_SENDBUF_LEN - headLength))
	{
		_xerror("Failed SerializeMessage: %s", message->Utf8DebugString().c_str());
		return;
	}
	SendDataToGameServer(gameid, serviceType, m_sendBuff + headLength, message->ByteSize());
}

void GameClientModule::SendDataToGameServer(const int gameid, const int serviceType, const char * data, const DATA_LENGTH_TYPE dataLength, const SERVERID srcGameID)
{
	int totalLength = dataLength + NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH;
	if (totalLength > MAX_SENDBUF_LEN)
	{
		_xerror("MessageLength %d overflow", totalLength);
		return;
	}	
	DATA_LENGTH_TYPE* packageLength = (DATA_LENGTH_TYPE*)m_sendBuff;
	*packageLength = totalLength- NET_HEAD_LENGTH;

	ServerMessageHead* serverMessageHead = (ServerMessageHead*)(m_sendBuff + NET_HEAD_LENGTH);
	serverMessageHead->DstServerID = gameid;
	if (srcGameID)
	{
		serverMessageHead->SrcServerID = srcGameID;
	}
	else
	{
		serverMessageHead->SrcServerID = GlobalGateServer->GetServerID();
	}
	serverMessageHead->ServiceType = serviceType;

	int headLength = NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH;
	if (data && data != (m_sendBuff + headLength))
	{
		if (sizeof(m_sendBuff) < dataLength + headLength)
		{
			_xerror("DataSize %d Overflow", dataLength + headLength);
			return;
		}
		memcpy(m_sendBuff + headLength, data, dataLength);
	}
	m_gameClientManager.SendByServerID(gameid, m_sendBuff, totalLength);
}


void GameClientModule::BroadcastDataToAllGame(const SERVERID srcID, const int messageType, const char* data, const DATA_LENGTH_TYPE dataLength)
{

	uint32_t headLength = PackServerMessageHead(srcID, ANY_SERVER_ID, messageType, dataLength);
	if (data)
	{
		if (sizeof(m_sendBuff) < dataLength + headLength)
		{
			_xerror("DataSize %d Overflow", dataLength + headLength);
			return;
		}
		memcpy(m_sendBuff + headLength, data, dataLength);
	}
	m_gameClientManager.SendToAllServer(m_sendBuff, dataLength + headLength);
}

bool GameClientModule::IsReady()
{
	//return m_configServerCount == m_connectedServerCount;
	return true;
}

void GameClientModule::OnBroadcastToClient(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength)
{
	EntityMessageHead* entityHead = (EntityMessageHead*)data;
	GlobalGateServerModule->BroadcastDataToClient(entityHead, data + ENTITY_MESSAGE_HEAD_LENGTH, dataLength - ENTITY_MESSAGE_HEAD_LENGTH);
}

void GameClientModule::OnKickClientOffline(ServerMessageHead * head, const char * data, DATA_LENGTH_TYPE dataLength)
{
	SG_KICK_CLIENT message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse Protobuf Message");
		return;
	}
	SESSIONID sid = message.sessionid();
	GlobalGateServerModule->KickOff(sid);
}

void GameClientModule::OnForwardMessage(ServerMessageHead * head, const char * data, DATA_LENGTH_TYPE dataLength)
{
	SendDataToGameServer(head->DstServerID, game::GAMESERVICE_FORWARD_MESSAGE, data, dataLength, head->SrcServerID);
}

void GameClientModule::OnBroadcastToGame(ServerMessageHead * head, const char * data, DATA_LENGTH_TYPE dataLength)
{
	BroadcastDataToAllGame(head->SrcServerID, game::GAMESERVICE_FORWARD_MESSAGE, data, dataLength);
}

void GameClientModule::OnRegisterService(ServerMessageHead * head, const char * data, DATA_LENGTH_TYPE dataLength)
{

}

void GameClientModule::OnEntityMessage(ServerMessageHead * head, const char * data, DATA_LENGTH_TYPE dataLength)
{
	EntityMessageHead* entityHead = (EntityMessageHead*)data;
	try
	{
		GlobalGateServerModule->SendDataToClient(entityHead->ClientSessionID, entityHead->MessageID, data + ENTITY_MESSAGE_HEAD_LENGTH, dataLength - ENTITY_MESSAGE_HEAD_LENGTH);
	}
	catch (const MyException& e)
	{
		_xerror("Error Happen: %s", e.GetMsg().c_str());
		NotifyClientConnectionClose(entityHead->ClientSessionID, head->SrcServerID);
	}
}

void GameClientModule::OnGamePingMessage(ServerMessageHead * head, const char * data, DATA_LENGTH_TYPE dataLength)
{
	TestPing message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse TestPing");
		return;
	}
	TestPingReply reply;
	reply.set_serverid(GlobalGateServer->GetServerID());
	reply.set_time(message.time());
	SendMessageToGameServer(message.serverid(), game::GAMESERVICE_PING_GATE_REPLY, &message);
}

void GameClientModule::OnGatePingReplyMessage(ServerMessageHead * head, const char * data, DATA_LENGTH_TYPE dataLength)
{
	TestPingReply message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse TestPingReply");
		return;
	}
	uint64_t latency = GetNowTimeMille() - message.time();
	_info("The latency with game %d is %llu", message.serverid(), latency);
}

void GameClientModule::OnAvatarChangeGame(ServerMessageHead* head, const char* data, DATA_LENGTH_TYPE dataLength)
{
	AvatarChangeGame message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse AvatarChangeGame");
		return;
	}

	GlobalGateServerModule->OnAvatarChangeGame(message.sessionid(), message.gameid());
}
