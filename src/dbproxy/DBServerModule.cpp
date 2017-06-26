#include "DBServerModule.h"
#include "NetModule.h"
#include "IDBProxy.h"
#include "message/LuaMessage.pb.h"
#include "message/dbmongo.pb.h"

DBServerModule::DBServerModule()
{

}

DBServerModule::~DBServerModule()
{
}

bool DBServerModule::Init(uint32_t maxClient, int port)
{
	if (!m_netModule.InitAsServer(maxClient, port))
	{
		_xerror("Failed Init m_netModule of DBServerModule");
		return false;
	}

	m_netModule.AddReceiveCallBack(this, &DBServerModule::OnMessage);

	m_netModule.AddEventCallBack(this, &DBServerModule::OnSocketEvent);

	if (!m_mongo.Init())
	{
		_xerror("Failed Init mongodb");
		return false;
	}
	return true;
}

void DBServerModule::OnSocketEvent(const int sock, const NET_EVENT eEvent, INet* net)
{
	if (eEvent & NET_EVENT_EOF)
	{
		_info("Connection closed");
		OnClientDisconnect(sock);
	}
	else if (eEvent & NET_EVENT_ERROR)
	{
		_info("Got an error on the connection");
		OnClientDisconnect(sock);
	}
	else if (eEvent & NET_EVENT_TIMEOUT)
	{
		_info("read timeout");
		OnClientDisconnect(sock);
	}
	else  if (eEvent == NET_EVENT_CONNECTED)
	{
		_info("connectioned success");
		OnClientConnected(sock);
	}
}

void DBServerModule::OnClientDisconnect(const int sock)
{
	SERVERID serverID = 0;
	for (auto it = m_servers.begin(); it != m_servers.end(); it++)
	{
		if (it->second == sock)
		{
			serverID = it->first;
			break;
		}
	}
	OnServerDisconnect(serverID);
	m_servers.erase(serverID);
}

void DBServerModule::OnClientConnected(const int sock)
{
}

void DBServerModule::OnMessage(const int sock, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	m_tickMessageCount++;
	m_tickMessageLength += messageLength;
	ServerMessageHead* head = (ServerMessageHead*)message;
	if (head->ServiceType == dbproxy::DBSERVICE_REGISTER_SERVER)
	{
		SERVERID serverID = head->SrcServerID;
		if (m_servers.find(serverID) != m_servers.end())
		{
			_xerror("The register gateid %d is exist", serverID);
		}
		m_servers[serverID] = sock;
		return;
	}
	else if (head->ServiceType == dbproxy::DBSERVICE_INSERT_DOC)
	{
		try
		{
			m_mongo.InsertOpreation(head->SrcServerID, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
		}
		catch (const std::exception& e)
		{
			_xerror("Failed InsertOpreation Reason : %s", e.what());
		}
		 
	}
	else if (head->ServiceType == dbproxy::DBSERVICE_FIND_ONE_DOC)
	{
		try
		{
			auto start = GetNowTimeMille();
			m_mongo.FindOneOperation(head->SrcServerID, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
			_trace("FindOneOperation cost time %llu", GetNowTimeMille() - start);
		}
		catch (const std::exception& e)
		{
			_xerror("Failed FindOneOperation Reason : %s", e.what());
		}
	}
	else if (head->ServiceType == dbproxy::DBSERVICE_UPDATE_DOC)
	{
		try
		{
			auto start = GetNowTimeMille();
			m_mongo.UpdateOpearation(head->SrcServerID, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
			_trace("UpdateOpearation cost time %llu", GetNowTimeMille() - start);
		}
		catch (const std::exception& e)
		{
			_xerror("Failed UpdateOpearation Reason : %s", e.what());
		}
		
	}
	else if (head->ServiceType == dbproxy::DBSERVICE_FIND_N_DOC)
	{
		try
		{
			auto start = GetNowTimeMille();
			m_mongo.FindNOperation(head->SrcServerID, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
			_trace("FindNOperation cost time %llu", GetNowTimeMille() - start);
		}
		catch (const std::exception& e)
		{
			_xerror("Failed FindNOperation Reason : %s", e.what());
		}	
	}
	else if (head->ServiceType == dbproxy::DBSERVICE_FIND_AND_MODIFY_DOC)
	{
		try
		{
			auto start = GetNowTimeMille();
			m_mongo.FindAndModifyOperation(head->SrcServerID, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
			_trace("FindAndModifyOperation cost time %llu", GetNowTimeMille() - start);
		}
		catch (const std::exception& e)
		{
			_xerror("Failed FindAndModifyOperation Reason : %s", e.what());
		}
	}
	else if (head->ServiceType == dbproxy::DBSERVICE_CLOSE_SERVER)
	{
		_info("Recv DBSERVICE_CLOSE_SERVER form Server %d and will close", head->SrcServerID);
		GlobalDBProxy->SetServerState(SERVER_STATE_STOP);
	}
	else if (head->ServiceType == dbproxy::DBSERVICE_TEST_ECHO)
	{
		SendResultBack(head->SrcServerID, dbproxy::DBCLIENT_TEST_ECHO_BACK, message + SERVER_MESSAGE_HEAD_LENGTH, messageLength - SERVER_MESSAGE_HEAD_LENGTH);
	}
	else
	{
		_xerror("Wrong InnerMessageHead: %d", head->ServiceType);
	}
}


void DBServerModule::OnServerDisconnect(const SERVERID gateid)
{
}



void DBServerModule::SendResultBack(const SERVERID dstServerID, const uint16_t messageID, IMessage * message)
{
	if (NULL == message)
	{
		return;
	}

	uint32_t headLength = GetPackServerMessageHeadLength();
	if (!message->SerializeToArray(m_sendBuff + headLength, sizeof(m_sendBuff) - headLength))
	{
		_xerror("DBServerModule::SerializeToArray failed messageID is %d reason is %s��%s", messageID, message->Utf8DebugString());
		return;
	}

	PackServerMessageHead(dstServerID, messageID, message->ByteSize());

	SendDataWithHead(dstServerID, headLength + message->ByteSize());
}

void DBServerModule::SendResultBack(const SERVERID dstServerID, const uint16_t messageID, const char* data, const DATA_LENGTH_TYPE dataLength)
{
	if (NULL == data)
	{
		return;
	}
	
	uint32_t dwHeadLen = PackServerMessageHead(dstServerID, messageID, dataLength);
	if ((dataLength + dwHeadLen) > sizeof(m_sendBuff))
	{
		_xerror("The length %d is larger than send buffer", dataLength);
		return;
	}

	memcpy(m_sendBuff + dwHeadLen, data, dataLength);

	SendDataWithHead(dstServerID, dataLength + dwHeadLen);
}



void DBServerModule::SendDataWithHead(const SERVERID serverID, const DATA_LENGTH_TYPE dataLength)
{
	auto it = m_servers.find(serverID);
	if (it == m_servers.end())
	{
		_warn("Failed get server socket of server %d", serverID);
		return;
	}

	m_netModule.SendData(m_sendBuff, dataLength, it->second);
}

uint32_t DBServerModule::PackServerMessageHead(const SERVERID dstServerID, const int serviceType, const DATA_LENGTH_TYPE messageLength)
{
	ServerMessageHead* head = (ServerMessageHead*)(m_sendBuff + NET_HEAD_LENGTH);
	head->DstServerID = dstServerID;
	head->SrcServerID = GlobalDBID;
	head->ServiceType = serviceType;
	DATA_LENGTH_TYPE* pTotalLen = (DATA_LENGTH_TYPE*)m_sendBuff;
	*pTotalLen = SERVER_MESSAGE_HEAD_LENGTH + messageLength;

	return GetPackServerMessageHeadLength();
}

bool DBServerModule::Tick()
{
	m_tickMessageCount = 0;
	m_tickMessageLength = 0;
	m_netModule.Tick();
	if (m_tickMessageCount)
	{
		_info("One Tick DB Recv Game Message Count is %d MessageLength %d", m_tickMessageCount, m_tickMessageLength);
	}
	return true;
}

