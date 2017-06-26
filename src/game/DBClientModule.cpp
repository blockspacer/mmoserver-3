#include "DBClientModule.h"
#include "message/servermessage.pb.h"
#include "message/dbmongo.pb.h"

DBClientModule::DBClientModule():m_connected(false)
{
	m_tickCount = 0;
	m_tickMessageCount = 0;
	m_totalMessageCount = 0;
}

DBClientModule::~DBClientModule()
{

}

bool DBClientModule::Init()
{
	if (!m_DBClient.Init())
	{
		_xerror("Failed Init GameClientNetModule");
		return false;
	}

	m_DBClient.AddReceiveCallBack(this, &DBClientModule::OnMessage);

	m_DBClient.AddEventCallBack(this, &DBClientModule::OnSocketEventOfDBProxy);

	auto gameconfig = ServerConfigure::Instance()->GetServerHolder(GlobalGameServer->GetServerID(), SERVER_TYPE_GAME);
	if (!gameconfig)
	{
		_xerror("Failed find gameconfig");
		assert(!"Failed find gameconfig");
		return false;
	}

	SERVERID dbID = ServerConfigure::Instance()->GetServerID(gameconfig->dbname);
	auto dbconfig = ServerConfigure::Instance()->GetServerHolder(dbID, SERVER_TYPE_DB);
	if (!dbconfig)
	{
		_xerror("Failed find dbconfig");
		assert(!"Failed find dbconfig");
		return false;
	}

	ConnectData xServerData;
	xServerData.serverID = dbconfig->serverID;
	xServerData.strIP = dbconfig->connectIP;
	xServerData.nPort = dbconfig->listenPort;
	xServerData.strName = dbconfig->serverName;

	m_DBClient.AddServer(xServerData);

	return true;
}

bool DBClientModule::Tick()
{
	m_tickCount++;
	m_tickMessageCount = 0;
	m_tickMessageLength = 0;
	m_DBClient.Tick();
	if (m_tickMessageCount)
	{
		_trace("One Tick Game Recv DBProxy Message Count is %d MessageLength %d", m_tickMessageCount, m_tickMessageLength);
	}
	return false;
}

void DBClientModule::OnSocketEventOfDBProxy(const int sock, const NET_EVENT eEvent, INet* pNet)
{
	if (eEvent & NET_EVENT_EOF)
	{
		_xerror("DBProxy Connect Close");
	}
	else if (eEvent & NET_EVENT_ERROR)
	{
		_xerror("DBProxy Connect Error");
	}
	else if (eEvent & NET_EVENT_TIMEOUT)
	{
		_xerror("DBProxy Connect Timeout");
	}
	else  if (eEvent == NET_EVENT_CONNECTED)
	{
		_info("DBProxy Connected");
		Register(pNet);
	}
}

void DBClientModule::Register(INet* pNet)
{
	//连接上某个Game之后将自己的ID发过去
	NF_SHARE_PTR<ConnectData> pServerData = m_DBClient.GetServerNetInfo(pNet);
	if (pServerData)
	{
		int nTargetID = pServerData->serverID;
		m_DBID = nTargetID;
		m_connected = true;
		//GS_REGISTER_SERVER message;
		//message.set_ip("");
		//message.set_port(0);
		//message.set_serverid(0);
		//message.set_servertype(0);

		SendDataToDBProxy(nTargetID, dbproxy::DBSERVICE_REGISTER_SERVER, nullptr, 0);
		_info("Register Game2DB of DBProxyID %d", nTargetID);
		//TestDBMessage();
	}
	else
	{
		_xerror("Failed find ServerInfo of connected server");
	}
}


// 处理收到的消息，DBProxy返回的消息
void DBClientModule::OnMessage(const int sock, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	m_tickMessageCount++;
	m_tickMessageLength += messageLength;
	m_totalMessageCount++;
	GlobalGameServerModule->OnDBReply(message, messageLength);
	
}


uint32_t DBClientModule::PackServerMessageHead(const int dstServerID, const int serviceType, const DATA_LENGTH_TYPE messageLenth)
{
	ServerMessageHead* head = (ServerMessageHead*)(m_sendBuff + NET_HEAD_LENGTH);
	head->ServiceType = serviceType;
	head->DstServerID = dstServerID;
	head->SrcServerID = GlobalGameServer->GetServerID();

	DATA_LENGTH_TYPE* pTotalLen = (DATA_LENGTH_TYPE*)m_sendBuff;
	*pTotalLen = SERVER_MESSAGE_HEAD_LENGTH + messageLenth;
	// 消息流的长度包括包的长度以及包头长度
	return SERVER_MESSAGE_HEAD_LENGTH + NET_HEAD_LENGTH;
}

void DBClientModule::TestDBMessage()
{
	uint64_t start = GetNowTimeMille();
	InsertDocRequest request;
	request.set_db("tlbytestonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyiGlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_TEST_ECHO, &request);void DBClientModule::SendDataToDBProxy(const int nServerID, const int messageID, const char* data, const DATA_LENGTH_TYPE dataLength)void DBClientModule::SendMessageToDBProxy(const int dbID, const int serviceType, IMessage* message)");
	request.set_collection("tonglingbaoyintlbytestonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyiGlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_TEST_ECHO, &request);void DBClientModule::SendDataToDBProxy(const int nServerID, const int messageID, const char* data, const DATA_LENGTH_TYPE dataLength)void DBClientModule::SendMessageToDBProxy(const int dbID, const int serviceType, IMessage* message)tlbytestonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyiGlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_TEST_ECHO, &request);void DBClientModule::SendDataToDBProxy(const int nServerID, const int messageID, const char* data, const DATA_LENGTH_TYPE dataLength)void DBClientModule::SendMessageToDBProxy(const int dbID, const int serviceType, IMessage* message)");
	request.set_doc("tonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyintlbytestonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyiGlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_TEST_ECHO, &request);void DBClientModule::SendDataToDBProxy(const int nServerID, const int messageID, const char* data, const DATA_LENGTH_TYPE dataLength)void DBClientModule::SendMessageToDBProxy(const int dbID, const int serviceType, IMessage* messagetlbytestonglingbaoyintonglingbaoyintonglingbaoyintonglingbaoyiGlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_TEST_ECHO, &request);void DBClientModule::SendDataToDBProxy(const int nServerID, const int messageID, const char* data, const DATA_LENGTH_TYPE dataLength)void DBClientModule::SendMessageToDBProxy(const int dbID, const int serviceType, IMessage* message)");
	request.set_callback_id(100);

	uint16_t headLength = GetPackServerMessageHeadLength();

	if (!request.SerializeToArray(m_sendBuff + headLength, sizeof(m_sendBuff) - headLength))
	{
		return;
	}

	for (int i = 0; i < 1000000; i++)
	{
		//GlobalDBClientModule->SendMessageToDBProxy(GlobalGameServer->GetServerID(), dbproxy::DBSERVICE_TEST_ECHO, &request);
		SendDataToDBProxy(m_DBID, dbproxy::DBSERVICE_TEST_ECHO, m_sendBuff + headLength, request.ByteSize());
	}

}

bool DBClientModule::IsReady()
{
	return m_connected;
}

void DBClientModule::SendDataToDBProxy(const int nServerID, const int messageID, const char* data, const DATA_LENGTH_TYPE dataLength)
{
	uint32_t headLength = PackServerMessageHead(nServerID, messageID, dataLength);
	if (dataLength + headLength > MAX_SENDBUF_LEN)
	{
		_xerror("DataLength %d overflow", dataLength);
		//assert(false);
		return;
	}
	if (data && data != (m_sendBuff + headLength))
	{
		memcpy(m_sendBuff + headLength, data, dataLength);
	}

	// 整个包的长度
	m_DBClient.SendByServerID(nServerID, m_sendBuff, dataLength + headLength);
}

void DBClientModule::SendMessageToDBProxy(const int dbID, const int serviceType, IMessage* message)
{
	uint16_t headLength = GetPackServerMessageHeadLength();
	if (!message)
	{
		SendDataToDBProxy(m_DBID, serviceType, m_sendBuff + headLength, 0);
		return;
	}
	
	if (!message->SerializeToArray(m_sendBuff + headLength, sizeof(m_sendBuff) - headLength))
	{
		_xerror("DBClientModule::SendMessageToDBProxy failed because %s", message->Utf8DebugString());
		return;
	}
	SendDataToDBProxy(m_DBID, serviceType, m_sendBuff + headLength, message->ByteSize());
}

void DBClientModule::SendDataToDBProxyWithHead(const int serverID, const char* data, const DATA_LENGTH_TYPE dataLength)
{
	m_DBClient.SendByServerID(serverID, data, dataLength);
}
