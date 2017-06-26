#include "gamemanager_servermodule.h"
#include "message/LuaMessage.pb.h"
#include "message/servermessage.pb.h"
#include "SocketSession.h"

bool GameManagerServerModule::Init(uint32_t maxClient, int port)
{
	if (!m_netModule.InitAsServer(maxClient, port))
	{
		_xerror("Failed Init m_netModule of GameServerModule");
		return false;
	}

	// 注册数据处理函数
	m_netModule.AddReceiveCallBack(this, &GameManagerServerModule::OnMessage);
	m_netModule.AddEventCallBack(this, &GameManagerServerModule::OnSocketEvent);
	return true;
}

bool GameManagerServerModule::Tick()
{
	m_netModule.Tick();
	return true;
}

void GameManagerServerModule::OnMessage(const int sock, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	ServerMessageHead* head = (ServerMessageHead*)message;
	switch (head->ServiceType)
	{
	case gamemanager::GAMEMANAGER_SERVICE_REGISTER_SERVER:
		OnServerRegister(head, sock, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case gamemanager::GAMEMANAGER_SERVICE_HEARTBEAT:
		OnHeartbeat(head, sock, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case gamemanager::GAMEMANAGER_SERVICE_RUN_SCRIPT:
		OnRunScript(head, sock, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case gamemanager::GAMEMANAGER_SERVICE_RUN_SCRIPT_REPLY:
		OnRunScriptReply(head, sock, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case gamemanager::GAMEMANAGER_SERVICE_RUN_LUA_MESSAGE:
		OnLuaMessage(head, sock, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case gamemanager::GAMEMANAGER_SERVICE_FORBID_NEW_CONNECTION:
	case gamemanager::GAMEMANAGER_SERVICE_IGNORE_CLIENT_ENTITY_MSG:
	case gamemanager::GAMEMANAGER_SERVICE_DISCONNECT_ALL_CONNECTION:
	case gamemanager::GAMEMANAGER_SERVICE_CLOSE_GATE:
		OnGateControlMessage(head, sock, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case gamemanager::GAMEMANAGER_SERVICE_NOTIFY_GAME_CLOSING:
	case gamemanager::GAMEMANAGER_SERVICE_NOTIFY_GAME_CLOSED:
	case gamemanager::GAMEMANAGER_SERVICE_CLOSE_GAME:
		OnGameControlMessage(head, sock, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		break;
	case gamemanager::GAMEMANAGER_SERVICE_FORWARD_GAME_MESSAGE:
		OnForwardGameMessage(head, sock, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
	default:
		break;
	}
}

void GameManagerServerModule::OnSocketEvent(const int sock, const NET_EVENT eEvent, INet * net)
{
	if (eEvent & NET_EVENT_EOF)
	{
		_info("Connection closed");
		OnServerDisconnect(sock);
	}
	else if (eEvent & NET_EVENT_ERROR)
	{
		_info("Got an error on the connection");
		OnServerDisconnect(sock);
	}
	else if (eEvent & NET_EVENT_TIMEOUT)
	{
		_info("read timeout");
		OnServerDisconnect(sock);
	}
	else  if (eEvent == NET_EVENT_CONNECTED)
	{
		_info("connectioned success");
		OnServerConnected(sock);
	}
}

void GameManagerServerModule::SendMessageToServer(const SERVERID dstServerID, const uint16_t serviceType, IMessage* message)
{
	if ( !message)
	{
		SendDataToServer(dstServerID, serviceType, nullptr, 0);
		return;
	}

	std::string data;
	if (!message->SerializeToString(&data))
	{
		_xerror("Failed SendMessageToServer because %s", message->Utf8DebugString().c_str());
		return;
	}
	
	SendDataToServer(dstServerID, serviceType, data.c_str(), message->ByteSize());
}


uint32_t GameManagerServerModule::PackServerMessageHead(const SERVERID srcServerID, const SERVERID dstServerID, int serviceType, const DATA_LENGTH_TYPE messageLength)
{
	ServerMessageHead* head = (ServerMessageHead*)(m_sendBuff + NET_HEAD_LENGTH);
	head->SrcServerID = srcServerID;
	head->DstServerID = dstServerID;
	head->ServiceType = serviceType;

	DATA_LENGTH_TYPE* pTotalLen = (DATA_LENGTH_TYPE*)m_sendBuff;
	*pTotalLen = SERVER_MESSAGE_HEAD_LENGTH + messageLength;

	return SERVER_MESSAGE_HEAD_LENGTH + NET_HEAD_LENGTH;
}

void GameManagerServerModule::SendDataToServer(const SERVERID dstServerID, const uint16_t serviceType, const char* data, const DATA_LENGTH_TYPE dataLength)
{		
	SendDataToServer(0, dstServerID, serviceType, data, dataLength);
}

void GameManagerServerModule::SendDataToServer(const SERVERID srcServerID, const SERVERID dstServerID, const uint16_t serviceType, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	DATA_LENGTH_TYPE headLength = PackServerMessageHead(srcServerID, dstServerID,  serviceType, dataLength);
	int sock = m_serverManager.GetSock(dstServerID);
	if (sock == INVALID_SOCKET_ID)
	{
		_warn("Failed get socket of serverid %d", dstServerID);
		return;
	}
	if (sizeof(m_sendBuff) < headLength + dataLength)
	{
		_xerror("DataSize %d overflow", headLength + dataLength);
		return;
	}
	if (data && data != m_sendBuff)
	{
		memcpy(m_sendBuff + headLength, data, dataLength);
	}
	

	m_netModule.SendData(m_sendBuff, dataLength + headLength, sock);
}

void GameManagerServerModule::SendDataToGMClient(const SERVERID dstServerID, const uint16_t serviceType, const char* data, const DATA_LENGTH_TYPE dataLength)
{
	DATA_LENGTH_TYPE headLength = PackServerMessageHead(0, dstServerID, serviceType, dataLength);
	auto it = m_GMClientSock.find(dstServerID);
	if (it == m_GMClientSock.end())
	{
		_warn("Failed get socket of serverid %d", dstServerID);
		return;
	}
	int sock = it->second;

	if (sizeof(m_sendBuff) < headLength + dataLength)
	{
		_xerror("DataSize %d overflow", headLength + dataLength);
		return;
	}
	if (data && data != m_sendBuff)
	{
		memcpy(m_sendBuff + headLength, data, dataLength);
	}


	m_netModule.SendData(m_sendBuff, dataLength + headLength, sock);
}

void GameManagerServerModule::BroadcastMessageToGate(const uint16_t serviceType, IMessage * message)
{
	BroadcastMessage(SERVER_TYPE_GATE, serviceType, message);
}

void GameManagerServerModule::BroadcastMessageToFight(const uint16_t serviceType, IMessage * message)
{
	BroadcastMessage(SERVER_TYPE_FIGHT, serviceType, message);
}

void GameManagerServerModule::BroadcastMessageToGame(const uint16_t serviceType, IMessage * message)
{
	BroadcastMessage(SERVER_TYPE_GAME, serviceType, message);
}

void GameManagerServerModule::BroadcastMessageToDB(const uint16_t serviceType, IMessage * message)
{
	BroadcastMessage(SERVER_TYPE_DB, serviceType, message);
}

void GameManagerServerModule::BroadcastMessage(const int serverType, const uint16_t serviceType, IMessage* message)
{
	std::set<SERVERID> allserver;
	m_serverManager.GetAllServerOfType(serverType, allserver);
	_info("BroadcastMessage serverType %d", serviceType);
	for (auto it = allserver.begin(); it != allserver.end(); ++it)
	{
		_info("BroadcastMessage serverType %d And SendTo Gate %d", serviceType, *it);
		SendMessageToServer(*it, serviceType, message);
	}
}

void GameManagerServerModule::OnServerDisconnect(const int sock)
{
	for (auto it = m_GMClientSock.begin(); it != m_GMClientSock.end(); ++it)
	{
		if (it->second == sock)
		{
			_info("GMClient %d Disconnect", it->first);
			m_GMClientSock.erase(it);
			break;
		}
	}

	SERVERID serverid = m_serverManager.GetServerID(sock);
	if (serverid == INVALID_SERVER_ID)
	{
		_xerror("OnServerDisconnect failed find serverid SHOULD NERVER HAPPEN");
		return;
	}
	int serverType = m_serverManager.GetServerType(serverid);
	m_serverManager.DeleteServerProxy(serverid);

	//TODO 广播通知有server失去连接
	if (serverType == SERVER_TYPE_GAME)
	{
		GameServerInfos message;
		std::set<SERVERID> allgame;
		m_serverManager.GetAllServerOfType(SERVER_TYPE_GAME, allgame);
		for (auto it = allgame.begin(); it != allgame.end(); ++it)
		{
			SERVERID serverid = *it;
			auto server = m_serverManager.GetServerProxy(serverid);
			if (server == nullptr)
			{
				continue;
			}
			ServerInfo *serverinfo = message.add_gameservers();
			serverinfo->set_svrtype(server->servertype);
			serverinfo->set_port(server->serverport);
			serverinfo->set_sid(server->sid);
			serverinfo->set_ip(server->serverip);
			serverinfo->set_banclient(false);
		}
		BroadcastMessageToGate(gamemanager::GAMEMANAGER_CLIENT_ALL_GAME_INFO, &message);
		BroadcastMessageToGame(gamemanager::GAMEMANAGER_CLIENT_ALL_GAME_INFO, &message);
	}
}

void GameManagerServerModule::OnServerConnected(const int sock)
{

}

void GameManagerServerModule::OnServerRegister(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	GS_REGISTER_SERVER request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("failed ParseFromArray GS_REGISTER_SERVER");
		return;
	}
	SERVERID serverid = request.serverid();
	int oldSock = m_serverManager.GetSock(serverid);
	if (oldSock != INVALID_SOCKET_ID && oldSock == sock)
	{
		_xerror("The register serverid %d is exist", serverid);
		m_netModule.CloseSession(oldSock);
	}

	std::string ip = request.ip();
	if (ip == "0.0.0.0" || ip == "127.0.0.1")
	{
		_warn("The IP of server %d is %s", serverid, ip.c_str());
	}

	m_serverManager.AddServerProxy(serverid, sock, request.servertype(), ip, request.port());
	_info("ServerID %d and ServerType %d Register", serverid, request.servertype());

	switch (request.servertype())
	{
	case SERVER_TYPE_GAME:
		OnGameServerRegister(head, sock, data, dataLength);
		break;

	default:
		break;
	}
	return;
}

void GameManagerServerModule::OnHeartbeat(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	SendDataToServer(head->SrcServerID, gamemanager::GAMEMANAGER_CLIENT_HEARTBEAT, nullptr, 0);
}

void GameManagerServerModule::OnGameServerRegister(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	GS_REGISTER_SERVER request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("failed ParseFromArray GS_REGISTER_SERVER");
		return;
	}

	//广播给所有的Gate有新的Game进程进来
	GameServerInfos message;
	std::set<SERVERID> allgame;
	m_serverManager.GetAllServerOfType(SERVER_TYPE_GAME, allgame);
	for (auto it = allgame.begin(); it != allgame.end(); ++it)
	{
		SERVERID serverid = *it;
		auto server = m_serverManager.GetServerProxy(serverid);
		if (server == nullptr)
		{
			continue;
		}
		ServerInfo *serverinfo = message.add_gameservers();
		serverinfo->set_svrtype(server->servertype);
		serverinfo->set_port(server->serverport);
		serverinfo->set_sid(server->sid);
		serverinfo->set_ip(server->serverip);
		serverinfo->set_banclient(false);
	}
	BroadcastMessageToGate(gamemanager::GAMEMANAGER_CLIENT_ALL_GAME_INFO, &message);
	BroadcastMessageToGame(gamemanager::GAMEMANAGER_CLIENT_ALL_GAME_INFO, &message);
	return;
}

void GameManagerServerModule::OnGateServerRegister(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	GS_REGISTER_SERVER request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("failed ParseFromArray GS_REGISTER_SERVER");
		return;
	}

	SERVERID serverid = request.serverid();
	int oldSock = m_serverManager.GetSock(serverid);
	if (oldSock != INVALID_SOCKET_ID && oldSock == sock)
	{
		_xerror("The register serverid %d is exist", serverid);
		m_netModule.CloseSession(oldSock);
	}

	m_serverManager.AddServerProxy(serverid, sock, request.servertype(), request.ip(), request.port());
	_info("ServerID %d and ServerType %d Register", serverid, request.servertype());

	//将所有的Game进程消息发送给新来的Gate
	GameServerInfos message;
	std::set<SERVERID> allgame;
	m_serverManager.GetAllServerOfType(SERVER_TYPE_GAME, allgame);
	for (auto it = allgame.begin(); it != allgame.end(); ++it)
	{
		SERVERID serverid = *it;
		auto server = m_serverManager.GetServerProxy(serverid);
		if (server == nullptr)
		{
			continue;
		}
		ServerInfo *serverinfo = message.add_gameservers();
		serverinfo->set_svrtype(server->servertype);
		serverinfo->set_port(server->serverport);
		serverinfo->set_sid(server->sid);
		serverinfo->set_ip(server->serverip);
		serverinfo->set_banclient(false);
	}
	SendMessageToServer(head->SrcServerID, gamemanager::GAMEMANAGER_CLIENT_ALL_GAME_INFO, &message);
}

void GameManagerServerModule::OnDBServerRegister(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	GS_REGISTER_SERVER request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("failed ParseFromArray GS_REGISTER_SERVER");
		return;
	}
	SERVERID serverid = request.serverid();
	int oldSock = m_serverManager.GetSock(serverid);
	if (oldSock != INVALID_SOCKET_ID && oldSock == sock)
	{
		_xerror("The register serverid %d is exist", serverid);
		m_netModule.CloseSession(oldSock);
	}
	SocketSession*  session = m_netModule.GetNet()->GetSocketSession(sock);
	if (!session)
	{
		_xerror("fml, why the session is none");
		return;
	}
	std::string ip = request.ip();
	if (ip == "0.0.0.0" || ip == "127.0.0.1")
	{
		_warn("The IP of server %d is %s", serverid, ip.c_str());
		//ip = session->GetIP();
	}

	m_serverManager.AddServerProxy(serverid, sock, request.servertype(), ip, request.port());
	_info("ServerID %d and ServerType %d Register", serverid, request.servertype());
	return;
}

void GameManagerServerModule::OnRunScript(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{	
	_info("OnRunScript");
	LUA_SCRIPT message;
	message.set_script_content(data, dataLength);
	m_GMClientSock[head->SrcServerID] = sock;
	message.set_clientsock(head->SrcServerID);
	BroadcastMessageToGame(gamemanager::GAMEMANAGER_CLIENT_RUN_SCRIPT, &message);
}

void GameManagerServerModule::OnRunScriptReply(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	_info("OnRunScriptReply");
	SC_Lua_RunRequest message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse SC_Lua_RunRequest");
		return;
	}

	SendDataToGMClient(message.opcode(), gamemanager::GAMEMANAGER_CLIENT_RUN_SCRIPT_REPLY, message.parameters().c_str(), message.parameters().length());
}


void GameManagerServerModule::OnLuaMessage(ServerMessageHead * head, const int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	//json
}

void GameManagerServerModule::OnGateControlMessage(ServerMessageHead * head, int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	BroadcastMessageToGate(head->ServiceType, nullptr);
}

void GameManagerServerModule::OnGameControlMessage(ServerMessageHead * head, int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	BroadcastMessageToGame(head->ServiceType, nullptr);
}

void GameManagerServerModule::OnForwardGameMessage(ServerMessageHead * head, int sock, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	SendDataToServer(head->SrcServerID,head->DstServerID, gamemanager::GAMEMANAGER_CLIENT_FORWARD_GAME_MESSAGE, data, dataLength);
}

