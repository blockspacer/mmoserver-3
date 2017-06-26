#include "GateServerModule.h"
#include "message.h"
#include "message/LuaMessage.pb.h"
#include "message/servermessage.pb.h"
#include "SocketSession.h"
//#include <iterator>

void GateServeModule::ProcessClientMessage(SocketSession* session, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	if (!session)
	{
		return;
	}

	SESSIONID sessionID = session->GetSessionID();
	ClientMessageHead* clientHead = (ClientMessageHead*)data;
	//if (clientHead->MessageID == CLIENT_MESSAGE_OPCODE_CONNECT_REQUEST)
	//{
	//	OnConnectQuest(session, data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH);
	//}

	//if (!session->GetWorkState())
	//{
	//	assert(!"SessionWorkState false");
	//	//TODO close the socketsession
	//	return;
	//}
	//if (!CheckGameServerID(session->GetGameServer()))
	//{
	//	_xerror("Failed CheckGameServerID %d", session->GetGameServer());
	//	return;
	//}
	SERVERID gameServerID = session->GetGameServer();
	if (!CheckGameServerID(gameServerID))
	{

		gameServerID = AssignGameServer(sessionID);
		if (gameServerID == 0)
		{
			_xerror("No valid game server");
			return;
		}
		session->SetGameServer(gameServerID);
	}

#ifdef _DEBUG
	if (clientHead->MessageID == CLIENT_MESSAGE_LUA_MESSAGE)
	{
		int a = 1;
	}
#endif

	GlobalGameClientModule->SendEntityMessage(sessionID, session->GetGameServer(), clientHead, data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH);
}



void GateServeModule::ProcessServiceMessage(SocketSession* session, const int serviceType, const char * msg, const DATA_LENGTH_TYPE dataLength)
{
}


void GateServeModule::OnGameServerMessage(ServerMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	switch (head->ServiceType)
	{
	case gate::GATESERVICE_AVATAR_INFO:
		OnAvatarInfo(head, data , dataLength);
		break;
	default:
		break;
	}

}

void GateServeModule::OnServerStop()
{
	// 停止处理消息
	GlobalGateServer->SetServerState(SERVER_STATE_FINISH);
}

void GateServeModule::OnAvatarChangeGame(SESSIONID clientSessionID, SERVERID gameid)
{
	int sock = GetClientSocketBySession(clientSessionID);
	if (sock == INVALID_SOCKET_ID)
	{
		_trace("Failed find socket of clientSessionID %lld", clientSessionID);
		return;
	}
	NetModule* netModule = GetServerNetModule();
	if (!netModule)
	{
		return;
	}
	SocketSession* session = netModule->GetNet()->GetSocketSession(sock);
	session->SetGameServer(gameid);
}

void GateServeModule::OnAvatarInfo(ServerMessageHead* head, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	AvatarInfo message;
	if (!message.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse AvatarInfo");
		return;
	}
	int sock = GetClientSocketBySession(message.sessionid());
	if (sock == INVALID_SOCKET_ID)
	{
		_trace("Failed find socket of clientSessionID %llu", message.sessionid());
		return;
	}
	NetModule* netModule = GetServerNetModule();
	if (!netModule)
	{
		return;
	}
	SocketSession* session = netModule->GetNet()->GetSocketSession(sock);
	if (!session)
	{
		return;
	}
	session->SetDeviceID(message.avatarid());
	session->SetCountry(message.level());
}

//void GateServeModule::OnConnectQuest(SocketSession* session, const char * data, const DATA_LENGTH_TYPE dataLength)
//{
//	if (!session)
//	{
//		return;
//	}
//	ConnectServerRequest message;
//	if (!message.ParseFromArray(data, dataLength))
//	{
//		_xerror("Failed Parse ConnectServerRequest");
//		return;
//	}
//	if (session->GetGameServer() != 0)
//	{
//		_warn("ConnectServer the session is already bind to a game");
//		assert(false);
//		return;
//	}
//	std::string deviceid = message.deviceid();
//	auto it = m_device2session.find(deviceid);
//
//	SERVERID gameid = 0;
//	if (it != m_device2session.end())
//	{
//		// have other old session, need to close old
//		int oldSock = it->second;
//		NetModule* netModule = GetServerNetModule();
//		if (!netModule)
//		{
//			return ;
//		}
//
//		SocketSession*  oldSession = netModule->GetNet()->GetSocketSession(oldSock);
//		if (oldSession)
//		{
//			gameid = oldSession->GetGameServer(); // recommand origin gameserver
//			//TODO how to process old session ?
//			oldSession->SetWorkState(false);
//		}
//	}
//
//	if (!CheckGameServerID(gameid))
//	{
//		gameid = AssignGameServer(session->GetSessionID());
//	}
//	session->SetGameServer(gameid);
//	session->SetWorkState(true);
//	session->SetDeviceID(deviceid);
//	
//	m_device2session[deviceid] = session->GetSock();
//
//	ConnectServerReply reply;
//	reply.set_type(ConnectServerReply_ReplyType_CONNECTED);
//	reply.set_extramsg("token123");
//	SendMessageToClient(session->GetSessionID(), SERVER_MESSAGE_OPCODE_CONNECT_REPLY, &reply);
//}

bool GateServeModule::CheckGameServerID(SERVERID gameServerID)
{
	//TODO need check gameserver connection
	return gameServerID > 0;
}

SERVERID GateServeModule::AssignGameServer(SESSIONID clientSession)
{
	std::set<SERVERID>    gameServers;
	GlobalGameClientModule->GetAllValidGameServer(gameServers);
	auto it = gameServers.begin();
	//std::advance(it, random_0_to_n(gameServers.size()));
	if (it != gameServers.end())
	{
		return *it;
	}
	return 0;
}


bool GateServeModule::AfterInit()
{
	return true;
}

bool GateServeModule::OnConnectionClose(int sock)
{
	// 需要通知game进行有玩家下线
	NetModule* netModule = GetServerNetModule();
	if (!netModule)
	{
		return false;
	}

	SocketSession*  session = netModule->GetNet()->GetSocketSession(sock);
	if (!session)
	{
		_xerror("The session of socket %d is null", sock);
		return false;
	}

	_info("client session in gate %ull will close", session->GetSessionID());
	SERVERID gameServerID = session->GetGameServer();
	if (!CheckGameServerID(gameServerID))
	{
		_warn("Failed CheckGameServerID %d", gameServerID);
		return true;
	}
	SESSIONID  clientSessionID = session->GetSessionID();
	DeleteSession(clientSessionID);
	RecycleSessionID(clientSessionID);

	GlobalGameClientModule->NotifyClientConnectionClose(clientSessionID, gameServerID);
	return true;
}


