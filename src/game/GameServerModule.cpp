#include "GameServerModule.h"
#include "NetModule.h"
#include "IGameServer.h"
#include "message/LuaMessage.pb.h"
#include "message/dbmongo.pb.h"
#include "message/FightMessage.pb.h"
#include "message/servermessage.pb.h"
#include "GameLuaModule.h"
#include "SocketSession.h"
#include "GameManagerClientModule.h"

GameServerModule::GameServerModule():m_tickGameServerMessageCount(0), m_totalGameServerMessageCount(0)
{
	
}

GameServerModule::~GameServerModule()
{
}

bool GameServerModule::Init(uint32_t maxClient, int port)
{
	if (!m_netModule.InitAsServer(maxClient, port))
	{
		_xerror("Failed Init m_netModule of GameServerModule");
		return false;
	}

	m_netModule.AddReceiveCallBack(this, &GameServerModule::OnMessage);

	m_netModule.AddEventCallBack(this, &GameServerModule::OnSocketEvent);


	if (!RegisterGateMethodCallback(game::GAMESERVICE_HEARTBEAT, this, &GameServerModule::OnGateHeartBeat))
	{
		return false;
	}

	if (!RegisterGateMethodCallback(game::GAMESERVICE_ENTITY_MESSAGE, this, &GameServerModule::OnEntityMessage))
	{
		return false;
	}

	if (!RegisterGateMethodCallback(game::GAMESERVICE_REGISTER_GATE, this, &GameServerModule::OnGateRegister))
	{
		return false;
	}

	if (!RegisterGateMethodCallback(game::GAMESERVICE_NOTIFY_CLIENT_DISCONNECT, this, &GameServerModule::OnEntityDisconnect))
	{
		return false;
	}

	if (!RegisterGateMethodCallback(game::GAMESERVICE_FORWARD_MESSAGE, this, &GameServerModule::OnTranspondMessage))
	{
		return false;
	}

	if (!RegisterGateMethodCallback(game::GAMESERVICE_FIGHT_MESSAGE, this, &GameServerModule::OnFightServerMessage))
	{
		return false;
	}
	if (!RegisterGateMethodCallback(game::GAMESERVICE_TEST_CONNECTION, this, &GameServerModule::OnTestConnection))
	{
		return false;
	}
	if (!RegisterGateMethodCallback(game::GAMESERVICE_PING_GAME, this, &GameServerModule::OnPingGameMessage))
	{
		return false;
	}
	if (!RegisterGateMethodCallback(game::GAMESERVICE_PING_GATE_REPLY, this, &GameServerModule::OnPingGameMessage))
	{
		return false;
	}
	//if (!RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_CONNECT_REQUEST, this, &GameServerModule::OnConnectServerQuest))
	//{
	//	return false;
	//}
	return true;
}


void GameServerModule::OnSocketEvent(const int sock, const NET_EVENT event, INet* net)
{
	if (event & NET_EVENT_EOF)
	{
		_info("Connection closed");
		OnServerDisconnect(sock);
	}
	else if (event & NET_EVENT_ERROR)
	{
		_info("Got an error on the connection");
		OnServerDisconnect(sock);
	}
	else if (event & NET_EVENT_TIMEOUT)
	{
		_info("read timeout");
		OnServerDisconnect(sock);
	}
	else  if (event == NET_EVENT_CONNECTED)
	{
		_info("connectioned success");
		OnServerConnected(sock);
	}
}

void GameServerModule::OnServerDisconnect(const int sock)
{
	SERVERID serverid = m_serverManager.GetServerID(sock);
	if (serverid == INVALID_SERVER_ID)
	{
		_xerror("OnServerDisconnect failed find serverid SHOULD NERVER HAPPEN");
		return;
	}

	int serverType = m_serverManager.GetServerType(serverid);
	OnServerDisconnect(serverType, serverid);
	m_serverManager.DeleteServerProxy(serverid);
}

void GameServerModule::OnServerConnected(const int sock)
{

}


int GameServerModule::GetRandomGateID()
{
	std::set<SERVERID> allGate;
	m_serverManager.GetAllServerOfType(SERVER_TYPE_GATE, allGate);
	if (allGate.empty())
	{
		return INVALID_SERVER_ID;
	}
	return *(allGate.begin());
}

std::string GameServerModule::GetConnectedServerIP(SERVERID sid)
{
	return m_serverManager.GetServerIP(sid);
}

int GameServerModule::GetConnectedServerPort(SERVERID sid)
{
	return m_serverManager.GetServerPort(sid);
}

void GameServerModule::OnGateHeartBeat(ServerMessageHead* head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	m_serverManager.UpdateMessageTime(head->SrcServerID, GetNowTimeSecond());
}


void GameServerModule::OnEntityMessage(ServerMessageHead* head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	EntityMessageHead* entityHead = (EntityMessageHead*)(data);
	auto it = m_EntityMessageHandlers.find(entityHead->MessageID);
	if (it != m_EntityMessageHandlers.end())
	{
		ENTITYT_MESSAGE_HANDLER_PTR& ptr = it->second;
		ENTITYT_MESSAGE_HANDLER* functor = ptr.get();
		functor->operator()(entityHead->ClientSessionID, data + ENTITY_MESSAGE_HEAD_LENGTH, dataLength - ENTITY_MESSAGE_HEAD_LENGTH);
	}
}

void GameServerModule::OnGateRegister(ServerMessageHead* head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	GS_REGISTER_SERVER request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("failed ParseFromArray GS_REGISTER_SERVER");
		return;
	}
	SERVERID gateid = request.serverid();
	int oldSock = m_serverManager.GetSock(gateid);
	if (oldSock != INVALID_SOCKET_ID && oldSock == sock)
	{
		_xerror("The register gateid %d is exist", gateid);
		m_netModule.CloseSession(oldSock);
	}
	SocketSession*  session = m_netModule.GetNet()->GetSocketSession(sock);
	if (!session)
	{
		_xerror("fml, why the session is none");
		return;
	}
	m_serverManager.AddServerProxy(gateid, sock, request.servertype(), request.ip(), request.port());
	_info("ServerID %d and ServerType %d Register", gateid, request.servertype());
	
	CLuaParam input[4];
	input[0] = request.servertype();
	input[1] = gateid;
	input[2] = request.ip();
	input[3] = request.port();
	LuaModule::Instance()->RunFunction("OnServerConnect", input, 4, nullptr, 0);

	return;
}

void GameServerModule::OnEntityDisconnect(ServerMessageHead* head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	GS_CLIENT_DISCONNECT request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("failed ParseFromArray GS_REGISTER_SERVER");
		return;
	}

	SESSIONID clientSessionID = request.sessionid();
	//_info("client session in game %ull will close", clientSessionID);

	CLuaParam input[1];
	input[0] = clientSessionID;

	if (!LuaModule::Instance()->RunFunction("OnPlayerLogOut", input, 1, NULL, 0))
	{
		_xerror("CLuaModule::OnPlayerLogOut Failed");
	}
}

void GameServerModule::OnTranspondMessage(ServerMessageHead* head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	CS_Lua_RunRequest request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse OnTranspondMessage");
		return;
	}

	CLuaParam input[3];
	input[0] = head->SrcServerID;
	input[1] = request.opcode();
	input[2] = request.parameters();

	if (!LuaModule::Instance()->RunFunction("OnTranspondMessage", input, 3, NULL, 0))
	{
		_xerror("Failed OnTranspondMessage");
	}
}

void GameServerModule::OnFightServerMessage(ServerMessageHead* head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	CS_Lua_RunRequest request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("request ParseFromArray error");
		return;
	}

	CLuaParam input[3];
	input[0] = head->SrcServerID;
	input[1] = request.opcode();
	input[2] = request.parameters();

	if (!LuaModule::Instance()->RunFunction("OnFightToGameMessage", input, 3, nullptr, 0))
	{
		_xerror("OnFightToGameMessage Error");
	}
}

void GameServerModule::OnTestConnection(ServerMessageHead *head, const int sock, const char *msg, const DATA_LENGTH_TYPE dataLength)
{
	_xerror("TestConnection From Server %d", head->SrcServerID);
	printf("TestConnection From Server %d", head->SrcServerID);
}

void GameServerModule::OnPingGameMessage(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength)
{
	TestPing message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse TestPing");
		return;
	}
	TestPingReply reply;
	reply.set_serverid(GlobalGameServer->GetServerID());
	reply.set_time(message.time());
	SendMessageToServer(message.serverid(), game::GAMECLIENT_PING_GAME_REPLY, &message);
}

void GameServerModule::OnPingGateReplyMessage(ServerMessageHead *head, const int sock, const char *data, const DATA_LENGTH_TYPE dataLength)
{
	TestPingReply message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse TestPingReply");
		return;
	}
	uint64_t latency = GetNowTimeMille() - message.time();
	_info("The latency with gate %d is %llu", message.serverid(), latency);
}

//void GameServerModule::OnConnectServerQuest(const SESSIONID clientSessionID, const char * data, const DATA_LENGTH_TYPE dataLength)
//{
//	ConnectServerRequest message;
//	if (!message.ParseFromArray(data, dataLength))
//	{
//		_xerror("Failed Parse ConnectServerRequest");
//		return;
//	}
//	int connectType = message.type();
//	if (connectType == ConnectServerRequest::NEW_CONNECTION)
//	{
//		//TODO new connection success
//		std::string deviceID = message.deviceid();
//		std::string entityID = message.entityid();
//		std::string verifyMessage = message.authmsg();
//
//		CLuaParam input[2];
//		input[0] = clientSessionID;
//		input[1] = deviceID;
//
//		LuaModule::Instance()->RunFunction("OnNewConnection", input, 2, nullptr, 0);
//	}
//
//	else if (connectType == ConnectServerRequest::RE_CONNECTION)
//	{
//		//TODO reconnection
//		if (message.has_entityid() && message.has_authmsg())
//		{
//			std::string deviceID = message.deviceid();
//			std::string entityID = message.entityid();
//			std::string verifyMessage = message.authmsg();
//
//			CLuaParam input[4];
//			input[0] = clientSessionID;
//			input[1] = deviceID;
//			input[2] = entityID;
//			input[3] = verifyMessage;
//
//			LuaModule::Instance()->RunFunction("OnReConnection", input, 4, nullptr, 0);
//		}
//	}
//}

void GameServerModule::OnMessage(const int sock, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	
	//++ m_tickGameServerMessageCount;
	//++ m_totalGameServerMessageCount;
	ServerMessageHead* head = (ServerMessageHead*)message;
	auto it = m_gateMessageHandlers.find(head->ServiceType);
	if (it != m_gateMessageHandlers.end())
	{
		TODO_GATE_MESSAGE_HANDLER_PTR& ptr = it->second;
		TODO_GATE_MESSAGE_HANDLER* functor = ptr.get();
		functor->operator()(head, sock, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
	}
	else
	{
		_info("Failed find handle of service %d", head->ServiceType);
	}
}

void GameServerModule::OnServerDisconnect(const int serverType, const SERVERID serverid)
{
	CLuaParam input[2];
	input[0] = serverType;
	input[1] = serverid;

	LuaModule::Instance()->RunFunction("OnServerDisconnect", input, 2, NULL, 0);
}



int GameServerModule::GetSessionDeltaTime(const SESSIONID clientSessionID)
{
	auto it = m_clientSessionInfo.find(clientSessionID);
	if (it != m_clientSessionInfo.end())
	{
		return it->second.DeltaTime;
	}

	return 0;
}

bool GameServerModule::RegisterService(int serviceType)
{
	SG_REGISTER_SERVICE message;
	message.set_serverid(GlobalGameServer->GetServerID());
	message.set_servicetype(serviceType);
	BroadcastMessageToGate(0,0, &message);
	return false;
}

void GameServerModule::KickOffline(SESSIONID clientSessionID)
{
	SG_KICK_CLIENT message;
	message.set_sessionid(clientSessionID);
	SERVERID gateid = GetGateIDBySession(clientSessionID);
	SendMessageToServer(gateid, game::GAMECLIENT_NOTIFY_KICK_CLIENT, &message);
}

void GameServerModule::SendEntityMessage(const SESSIONID clientSessionID, const MESSAGEID messageID, IMessage * message)
{
	if (!message)
	{
		return;
	}
	EntityMessageHead* head = (EntityMessageHead*)(m_sendBuff + NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH);
	head->ClientID = 0;
	head->ClientSessionID = clientSessionID;
	head->MessageID = messageID;

	int headLength = NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH + ENTITY_MESSAGE_HEAD_LENGTH;
	if (!message->SerializeToArray(m_sendBuff + headLength, MAX_SENDBUF_LEN - headLength))
	{
		_xerror("GameServerModule::SerializeToArray failed messageID is %d reason is %s��%s", messageID, message->Utf8DebugString());
		return;
	}

	SERVERID gateid = GetGateIDBySession(clientSessionID);

	SendData(gateid, game::GAMECLIENT_ENTITY_MESSAGE, m_sendBuff + NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH, message->ByteSize() + ENTITY_MESSAGE_HEAD_LENGTH);
}

void GameServerModule::SendMessageToFight(const SERVERID serverid, IMessage * message)
{
	if (!message)
	{
		return;
	}

	SendMessageToServer(serverid, game::GAMECLIENT_FIGHT_MESSAGE, message);
}

void GameServerModule::SendMessageToServer(const SERVERID serverid, int serviceType, IMessage* message)
{
	if (message == nullptr)
	{
		return;
	}
	if (!message->SerializeToArray(GetSendBuffBody(), GetSendBuffBodyLength()))
	{
		_xerror("Failed Serialize %d reason is %s", serviceType, message->Utf8DebugString().c_str());
		return;
	}

	SendData(serverid, serviceType, GetSendBuffBody(), message->ByteSize());
}

void GameServerModule::SendData(const SERVERID serverid, int serviceType, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	uint16_t headLength = PackServerMessageHead(GlobalGameServer->GetServerID(), serverid, serviceType, dataLength);
	if (dataLength + headLength > MAX_SENDBUF_LEN)
	{
		_xerror("SendData %d overflow", dataLength);
		return;
	}

	if (m_sendBuff != data && data != nullptr)
	{
		memcpy(GetSendBuffBody(), data, dataLength);
	}
	SERVERID dstServerID = serverid;
	if (serviceType == game::GAMECLIENT_FORWARD_MESSAGE)
	{
		dstServerID = GetRandomGateID();
		if (dstServerID == INVALID_SERVER_ID)
		{
			GlobalGameManagerClient->ForwardDataToGame(serverid, gamemanager::GAMEMANAGER_SERVICE_FORWARD_GAME_MESSAGE, data, dataLength);
			return;
		}
	}
	SendDataToGateWithHead(dstServerID, dataLength + headLength);
}

uint32_t GameServerModule::PackServerMessageHead(const SERVERID srcServerID, const SERVERID dstServerID, int serviceType, const DATA_LENGTH_TYPE messageLength)
{
	ServerMessageHead* head = (ServerMessageHead*)(m_sendBuff + NET_HEAD_LENGTH);
	head->SrcServerID = srcServerID;
	head->DstServerID = dstServerID;
	head->ServiceType = serviceType;

	DATA_LENGTH_TYPE* pTotalLen = (DATA_LENGTH_TYPE*)m_sendBuff;
	*pTotalLen = SERVER_MESSAGE_HEAD_LENGTH + messageLength;

	return SERVER_MESSAGE_HEAD_LENGTH + NET_HEAD_LENGTH;
}

SERVERID GameServerModule::GetFightServerID(int fightType)
{
	std::set<SERVERID> allfight;
	m_serverManager.GetAllServerOfType(SERVER_TYPE_FIGHT, allfight);
	if (allfight.empty())
	{
		return INVALID_SERVER_ID;
	}
	return *(allfight.begin());
}

char* GameServerModule::GetSendBuffBody()
{
	return m_sendBuff + GetPackServerMessageHeadLength();
}

int GameServerModule::GetSendBuffBodyLength()
{
	return sizeof(m_sendBuff) - GetPackServerMessageHeadLength();
}

void GameServerModule::ForwardMessage(const SERVERID dstServerID, IMessage * message)
{
	if (!message)
	{
		return;
	}

	SendMessageToServer(dstServerID, game::GAMECLIENT_FORWARD_MESSAGE, message);
}


void GameServerModule::BroadcastMessageToGate(int messageID, int country, IMessage* message)
{
	EntityMessageHead* head = (EntityMessageHead*)(m_sendBuff + NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH);
	head->ClientID = 0;
	head->ClientSessionID = country;
	head->MessageID = messageID;

	int headLength = NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH + ENTITY_MESSAGE_HEAD_LENGTH;
	if (!message->SerializeToArray(m_sendBuff + headLength, MAX_SENDBUF_LEN - headLength))
	{
		_xerror("GameServerModule::SerializeToArray failed messageID is %d reason is %s", messageID, message->Utf8DebugString().c_str());
		return;
	}

	std::set<SERVERID> allGate;
	m_serverManager.GetAllServerOfType(SERVER_TYPE_GATE, allGate);
	for (auto it = allGate.begin(); it != allGate.end(); ++it)
	{
		SendData(*it, game::GAMECLIENT_BROADCAST_TO_CLIENT, m_sendBuff + NET_HEAD_LENGTH + SERVER_MESSAGE_HEAD_LENGTH, message->ByteSize() + ENTITY_MESSAGE_HEAD_LENGTH);
		//SendMessageToServer(*it, game::GAMECLIENT_BROADCAST_TO_CLIENT, message);
	}
}

void GameServerModule::OnDBReply(const char * message, const DATA_LENGTH_TYPE messageLength)
{
	ServerMessageHead *pHead = (ServerMessageHead*)message;
	switch (pHead->ServiceType)
	{
	case dbproxy::DBCLIENT_FIND_ONE_DOC_REPLY:
		ProcessDBFindOneReply(message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case dbproxy::DBCLIENT_INSERT_DOC_REPLY:
		ProcessDBInsertReply(message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case dbproxy::DBCLIENT_UPDATE_DOC_REPLY:
		ProcessDBUpdateReply(message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case dbproxy::DBCLIENT_FIND_N_DOC_REPLY:
		ProcessDBFindNReply(message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case dbproxy::DBCLIENT_FIND_AND_MODIFY_DOC_REPLY:
		ProcessDBFindAndModifyReply(message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case dbproxy::DBCLIENT_TEST_ECHO_BACK:
		_info("TEST_ECHO_BACK");
		break;
	default:
		break;
	}
}

void GameServerModule::ProcessDBUpdateReply(const char * message, const DATA_LENGTH_TYPE messageLength)
{
	UpdateDocReply reply;
	if (!reply.ParseFromArray(message, messageLength))
	{
		_xerror("CLuaModule::OnDBReply request ParseFromArray error");
		return;
	}
	CLuaParam input[2];
	input[0] = reply.callback_id();
	input[1] = reply.status();


	LuaModule::Instance()->RunFunction("DBUpdateReply", input, 2, nullptr, 0);
}

void GameServerModule::ProcessDBFindOneReply(const char * message, const DATA_LENGTH_TYPE messageLength)
{
	FindDocReply reply;
	if (!reply.ParseFromArray(message, messageLength))
	{
		_xerror("CLuaModule::OnDBReply request ParseFromArray error");
		return;
	}
	CLuaParam input[3];
	input[0] = reply.callback_id();
	input[1] = reply.status();
	input[2] = reply.docs()[0];
	LuaModule::Instance()->RunFunction("DBFindOneReply", input, 3, nullptr, 0);
}

void GameServerModule::ProcessDBInsertReply(const char * message, const DATA_LENGTH_TYPE messageLength)
{
	InsertDocReply reply;
	if (!reply.ParseFromArray(message, messageLength))
	{
		_xerror("CLuaModule::OnDBReply request ParseFromArray error");
		return;
	}
	CLuaParam input[2];
	input[0] = reply.callback_id();
	input[1] = reply.status();

	LuaModule::Instance()->RunFunction("DBInsertReply", input, 2, nullptr, 0);
}

void GameServerModule::ProcessDBFindNReply(const char * message, const DATA_LENGTH_TYPE messageLength)
{
	FindDocReply reply;
	if (!reply.ParseFromArray(message, messageLength))
	{
		_xerror("CLuaModule::OnDBReply request ParseFromArray error");
		return;
	}
	//CLuaParam input[3];
	//input[0] = reply.callback_id();
	//input[1] = reply.status();
	//input[2] = reply.docs().size();
	//LuaModule::Instance()->RunFunction("DBFindOneReply", input, 3, nullptr, 0);
	//////////////////////////////// Test //////////////////////////////////
	lua_State* L = LuaModule::Instance()->GetLuaState();
	int top = lua_gettop(L);

	lua_getglobal(L, "DBFindNReply");
	if (!lua_isfunction(L, -1))
	{
		_xerror("Failed call DBFindNReply function because of failed find function");
		lua_settop(L, top);
		return;
	}
	lua_pushnumber(L, reply.callback_id());
	lua_pushboolean(L, reply.status());
	lua_newtable(L);
	int i = 1;
	for (auto it = reply.docs().begin(); it != reply.docs().end(); ++it, ++i) {
		lua_pushnumber(L, i);
		//lua_pushstring(L, it->c_str());
		lua_pushlstring(L, it->c_str(), it->size());
		lua_settable(L, -3);
	}
	int ret = lua_pcallwithtraceback(L, 3, 0);
	if (ret)
	{
		const char* pszErrInfor = lua_tostring(L, -1);
		_xerror("Failed call ProcessDBFindNReply and reason is %s", pszErrInfor);
		lua_settop(L, top);
	}
}

void GameServerModule::ProcessDBFindAndModifyReply(const char * message, const DATA_LENGTH_TYPE messageLength)
{
	FindAndModifyDocReply reply;
	if (!reply.ParseFromArray(message, messageLength))
	{
		_xerror("CLuaModule::OnDBReply request ParseFromArray error");
		return;
	}
	CLuaParam input[3];
	input[0] = reply.callback_id();
	input[1] = reply.status();
	input[2] = reply.doc();
	LuaModule::Instance()->RunFunction("DBFindAndModifyReply", input, 3, nullptr, 0);
}


void GameServerModule::SendDataToGateWithHead(const SERVERID gateid, const DATA_LENGTH_TYPE dataLength)
{
	int sock = m_serverManager.GetSock(gateid);
	if (sock == INVALID_SOCKET_ID)
	{
		_warn("Failed get socket of gateid %d", gateid);
		return;
	}
	m_netModule.SendData(m_sendBuff, dataLength, sock);
}


SERVERID GameServerModule::GetGateIDBySession(SESSIONID sessionID)
{
	SERVERID gateid = static_cast<SERVERID>(sessionID & 0xffff0000);
	gateid = gateid >> 16;
	return gateid;
}


bool GameServerModule::Tick()
{
	m_tickGameServerMessageCount = 0;
	m_netModule.Tick();

	return m_tickGameServerMessageCount > 10;
}

