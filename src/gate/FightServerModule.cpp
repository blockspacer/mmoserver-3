#include "FightServerModule.h"
#include "SocketSession.h"
#include "BattleProxyModule.h"
#include "message/LuaMessage.pb.h"
#include "ServerConfigure.h"
#include "timemeter.h"

bool FightServerModule::Init(uint32_t maxClients, int port)
{
	if (!BaseGateServerModule::Init(maxClients, port))
	{
		_xerror("Failed Init BaseGateServerModule");
		return false;
	}
	std::shared_ptr<ServerHolder> self = ServerConfigure::Instance()->GetServerHolder(GlobalGateServer->GetServerID(), SERVER_TYPE_FIGHT);
	if (!self)
	{
		_xerror("Failed Find ServerHolder");
		assert(!"Failed Find ServerHolder");
		return false;
	}
	if (!m_fightLuaModule.Init(self->luaPath))
	{
		_xerror("Failed Init FightLuaModule");
		return false;
	}
	m_proxyModule = new BattleProxyModule;
	if (m_proxyModule == nullptr)
	{
		_xerror("Failed new BattleProxyModule");
		return false;
	}
	if (!m_proxyModule->Init())
	{
		_xerror("Failed Init BattleProxyModule");
		return false;
	}

	if (!RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_MOVE, dynamic_cast<ProxyModule*>(m_proxyModule), &ProxyModule::EntityMove))
	{
		return false;
	}
	if (!RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_STOP_MOVE, dynamic_cast<ProxyModule*>(m_proxyModule), &ProxyModule::EntityStopMove))
	{
		return false;
	}
	if (!RegisterEntityMethodCallback(CLIENT_MESSAGE_FORCE_POSITION, dynamic_cast<ProxyModule*>(m_proxyModule), &ProxyModule::EntityForceMove))
	{
		return false;
	}
	if (!RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_TURN_DIRECTION, dynamic_cast<ProxyModule*>(m_proxyModule), &ProxyModule::EntityTurnDirection))
	{
		return false;
	}
	if (!RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_PING, dynamic_cast<ProxyModule*>(m_proxyModule), &ProxyModule::ProcessPing))
	{
		return false;
	}
	if (!RegisterEntityMethodCallback(CLIENT_MESSAGE_OPCODE_PING_BACK, dynamic_cast<ProxyModule*>(m_proxyModule), &ProxyModule::ProcessPingBack))
	{
		return false;
	}

	return true;
}

bool FightServerModule::AfterInit()
{
	if (!m_fightLuaModule.AfterInit())
	{
		return false;
	}
	return true;
}

bool FightServerModule::Tick()
{
	TimeMeter tm(10);

	tm.Stamp();
	BaseGateServerModule::Tick();
	tm.Stamp("Base");

	m_proxyModule->Tick(0);
	tm.Stamp("AOI");
	tm.Check(MSG_MARK, "fightmodule");

	 return true;
}

void FightServerModule::OnAvatarChangeGame(SESSIONID sid, SERVERID gameid)
{

}

//void FightServerModule::OnConnectQuest(SocketSession * session, const char * data, const DATA_LENGTH_TYPE dataLength)
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
//
//	ConnectServerReply reply;
//	reply.set_type(ConnectServerReply_ReplyType_CONNECTED);
//	reply.set_extramsg("token123");
//	SendMessageToClient(session->GetSessionID(), SERVER_MESSAGE_OPCODE_CONNECT_REPLY, &reply);
//}

bool FightServerModule::OnConnectionClose(int sock)
{
	// 通知lua层玩家离线
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

	CLuaParam input[1];
	input[0] = session->GetSessionID();

	LuaModule::Instance()->RunFunction("OnFightClientDisconnect", input, 1, nullptr, 0);
	return false;
}

bool FightServerModule::KickOff(SESSIONID sid)
{
	return false;
}

void FightServerModule::ProcessClientMessage(SocketSession* session, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	ClientMessageHead* pHead = (ClientMessageHead*)data;
	SESSIONID sessionID = session->GetSessionID();
	ClientMessageHead* clientHead = (ClientMessageHead*)data;
	//if (clientHead->MessageID == CLIENT_MESSAGE_OPCODE_CONNECT_REQUEST)
	//{
	//	OnConnectQuest(session, data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH);
	//}

	auto it = m_EntityMessageHandlers.find(pHead->MessageID);
	if (it != m_EntityMessageHandlers.end())
	{
		ENTITYT_MESSAGE_HANDLER_PTR& ptr = it->second;
		ENTITYT_MESSAGE_HANDLER* functor = ptr.get();
		functor->operator()(session->GetSessionID(), data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH);
	}
	else
	{
		_info("Failed find handle of MessageID %d", pHead->MessageID);
	}
}

void FightServerModule::ProcessServiceMessage(SocketSession* session, const int serviceType, const char * data, const DATA_LENGTH_TYPE dataLength)
{

}

void FightServerModule::OnGameServerMessage(ServerMessageHead * head, const char * data, const DATA_LENGTH_TYPE dataLength)
{
	switch (head->ServiceType)
	{
	case game::GAMECLIENT_FIGHT_MESSAGE:
		m_fightLuaModule.OnGameServerLuaMessage(head->SrcServerID, data, dataLength);
		break;
	default:
		break;
	}
}

void FightServerModule::OnServerStop()
{
	if (!LuaModule::Instance()->RunFunction("OnFightServerClose", nullptr, 0, nullptr, 0))
	{
		_xerror("Failed OnFightServerClose And Close Fight Directly");
		GlobalGateServer->SetServerState(SERVER_STATE_FINISH);
	}
	GlobalGateServer->SetServerState(SERVER_STATE_STOPING);
}
