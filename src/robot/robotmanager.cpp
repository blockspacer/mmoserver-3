#include "robotmanager.h"
#include "message/LuaMessage.pb.h"
#include "RobotLuaFunction.h"
#include "Timer.h"
#include "robotheartbeat.h"
#include <thread>
#define _PRESS

RobotManager::RobotManager(std::string strServerName):m_strServerName(strServerName)
{
}

RobotManager::~RobotManager()
{
}

bool RobotManager::Init( std::string configPath)
{
	if (!m_config.Init(configPath, m_strServerName))
	{
		return false;
	}
	if (!m_logModule.Init(m_config.LogFilePath, m_config.LogLevel))
	{
		assert(false);
		return false;
	}
	SetLogListen(&m_logModule);
	_info("Init LogModule Success");

#ifdef _PRESS
	if (!LuaModule::Instance()->Init(m_config.LuaPath))
	{
		_xerror("Failed Init LuaPath %s", m_config.LuaPath.c_str());
		return false;
	}
	luaopen_robotfunction(LuaModule::Instance()->GetLuaState());
	if (!LuaModule::Instance()->LoadFile(m_config.LuaPath.c_str()))
	{
		_xerror("Failed Load LuaPath %s", m_config.LuaPath.c_str());
		return false;
	}
#endif // _PRESS

	if (!m_ClientManager.Init())
	{
		_xerror("Failed Init ClientNetModule");
		return false;
	}

	m_ClientManager.AddReceiveCallBack(this, &RobotManager::OnMessage);

	m_ClientManager.AddEventCallBack(this, &RobotManager::OnSocketEvent);

	m_robotPoll = new Robot[m_config.MaxClientCount];
	if (!m_robotPoll)
	{
		_xerror("Failed New robot poll");
		return false;
	}

	//设置客户端管理ID，以防止开多个机器人进程时玩家重复	
	CLuaParam input[3];
	input[0] = m_config.m_nClientID;

	LuaModule::Instance()->RunFunction("OnSetRobotManagerID", input, 1, nullptr, 0);

	for (int i = 0; i < m_config.MaxClientCount; ++i)
	{
		Robot& robot = m_robotPoll[i];
		robot.SetIndexId(i);
		//robot.m_indexID = i;
		robot.Reset();

		ConnectData xServerData;
		xServerData.serverID = i;
		xServerData.strIP = m_config.ConnectIP;
		xServerData.nPort = m_config.ConnectPort;

		m_ClientManager.AddServer(xServerData);
	}
	m_startTime = GetNowTimeMille();
#ifdef _DEBUG
	m_debugTimerID = CTimerMgr::Instance()->CreateTimer(0, this, &RobotManager::OnShowDebugInfo, 500, 500);
#endif // _DEBUG
	return true;
}

std::string RobotManager::GetRobotStatusString(ROBOT_STATUS status)
{
	std::string result;
	switch (status)
	{
	case ROBOT_STATUS_NONE:
		result = "ROBOT_STATUS_NONE";
		break;
	case ROBOT_STATUS_INIT:
		result = "ROBOT_STATUS_INIT";
		break;
	case ROBOT_STATUS_CONNECTING:
		result = "ROBOT_STATUS_CONNECTING";
		break;
	case ROBOT_STATUS_CONNECTED:
		result = "ROBOT_STATUS_CONNECTED";
		break;
	case ROBOT_STATUS_CONNECT_FAILED:
		result = "ROBOT_STATUS_CONNECT_FAILED";
		break;
	case ROBOT_STATUS_LOGINING:
		result = "ROBOT_STATUS_LOGINING";
		break;
	case ROBOT_STATUS_LOGIN_FAILED:
		result = "ROBOT_STATUS_LOGIN_FAILED";
		break;
	case ROBOT_STATUS_RUN:
		result = "ROBOT_STATUS_RUN";
		break;
	case ROBOT_STATUS_FAILED:
		result = "ROBOT_STATUS_FAILED";
		break;
	case ROBOT_STATUS_CLOSE:
		result = "ROBOT_STATUS_CLOSE";
		break;
	default:
		char tmp[2];
		sprintf(tmp, "%d", status);
		result = tmp;
		break;
	}
	return result;
}

void RobotManager::OnShowDebugInfo(int a)
{
	uint64_t startTime = GetNowTimeMille() - m_startTime;
	_info("client start time %lld", startTime)
	std::map<int, int> mapStatus;
	for (int i = ROBOT_STATUS::ROBOT_STATUS_NONE;i <= ROBOT_STATUS::ROBOT_STATUS_CLOSE;i++)
	{
		mapStatus[i] = 0;
	}
	for (int i = 0; i < m_config.MaxClientCount; ++i)
	{
		Robot& robot = m_robotPoll[i];
		mapStatus[robot.m_status] = mapStatus[robot.m_status] + 1;
	}

	for (std::map<int,int>::iterator it = mapStatus.begin();it != mapStatus.end();it++)
	{
		if (it->first == ROBOT_STATUS::ROBOT_STATUS_LOGINING or it->first == ROBOT_STATUS::ROBOT_STATUS_RUN)
		{
			_info("The status %s count is %d ", GetRobotStatusString((ROBOT_STATUS)it->first).c_str(), it->second);
		}			
	}
}

void RobotManager::OnSocketEvent(const int sock, const NET_EVENT eEvent, INet* net)
{
	if (eEvent & NET_EVENT_EOF)
	{
		_xerror("GameClientModule Connect Close");
		m_sockToIndexID.erase(sock);
	}
	else if (eEvent & NET_EVENT_ERROR)
	{
		_xerror("GameClientModule Connect Error");
		m_sockToIndexID.erase(sock);
	}
	else if (eEvent & NET_EVENT_TIMEOUT)
	{
		_xerror("GameClientModule Connect Timeout");
		m_sockToIndexID.erase(sock);
	}
	else  if (eEvent == NET_EVENT_CONNECTED)
	{
		NF_SHARE_PTR<ConnectData> connectData = m_ClientManager.GetServerNetInfo(net);
		if (!connectData)
		{
			_fatal("Failed find connectData");
			return;
		}
		int index = connectData->serverID;
		m_robotPoll[index].m_sock = sock;
		m_robotPoll[index].m_status = ROBOT_STATUS_CONNECTED;
		m_sockToIndexID[sock] = index;
	}
}

void RobotManager::OnMessage(const int sock, const char* data, const DATA_LENGTH_TYPE dataLength)
{
	auto it = m_sockToIndexID.find(sock);
	if (it == m_sockToIndexID.end())
	{
		_xerror("Failed Find indexID of sock %d", sock);
		return;
	}
	int indexID = it->second;
	Robot& robot = m_robotPoll[indexID];
	ClientMessageHead* head = (ClientMessageHead*)data;
	switch (head->MessageID)
	{
	case SERVER_MESSAGE_OPCODE_PING_BACK:
		OnPingBack(robot, data+CLIENT_MESSAGE_HEAD_LENGTH, dataLength-CLIENT_MESSAGE_HEAD_LENGTH);
		break;
	case SERVER_MESSAGE_OPCODE_LUA_MESSAGE:
	{
		SC_Lua_RunRequest message;
		if (!message.ParseFromArray(data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH))
		{
			_xerror("Failed ParseMessage");
			return;
		}
		Robot& robot = m_robotPoll[indexID];
		//TODO check robot status
		CLuaParam input[3];
		input[0] = indexID;
		input[1] = message.opcode();
		input[2] = message.parameters();

		LuaModule::Instance()->RunFunction("OnServerMessage", input, 3, nullptr, 0);
	}
		break;
	case SERVER_MESSAGE_OPCODE_CREATE_ENTITY:
	{
		SC_CREATE_ENTITY message;
		if (!message.ParseFromArray(data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH))
		{
			_xerror("Failed ParseMessage SERVER_MESSAGE_OPCODE_CREATE_ENTITY");
			return;
		}
		int nSceneId = message.sceneid();
		int count = message.entitiescreate_size();
		for (int i=0;i < count;++i)
		{
			SC_CREATE_ENTITY_Entity* pEntity = message.mutable_entitiescreate(i);
			CLuaParam input[9];
			input[0] = indexID;
			input[1] = nSceneId;
			input[2] = pEntity->entityid();
			input[3] = pEntity->entityinfo();
			input[4] = pEntity->entitypos().destx();
			input[5] = pEntity->entitypos().desty();
			input[6] = pEntity->entitypos().destz();
			input[7] = pEntity->entitypos().orientation();
			input[8] = pEntity->entitypos().speed();
			LuaModule::Instance()->RunFunction("OnAOIAdd", input, 9, nullptr, 0);
		}
		break;
	}
	case  SERVER_MESSAGE_OPCODE_DESTROY_ENTITY:
	{
		SC_DESTROY_ENTITY message;
		if (!message.ParseFromArray(data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH))
		{
			_xerror("Failed ParseMessage SERVER_MESSAGE_OPCODE_DESTROY_ENTITY");
			return;
		}
		int nSceneId = message.sceneid();
		int count = message.entitiesdestroy_size();
		for (int i = 0; i < count; ++i)
		{
			CLuaParam input[3];
			input[0] = indexID;
			input[1] = nSceneId;
			input[2] = message.mutable_entitiesdestroy(i);
			LuaModule::Instance()->RunFunction("OnAOIDel", input, 3, nullptr, 0);
		}
		break;
	}
	case SERVER_MESSAGE_OPCODE_MOVE:
	{
		SC_MOVE_SYNC message;
		if (!message.ParseFromArray(data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH))
		{
			_xerror("Failed ParseMessage SERVER_MESSAGE_OPCODE_MOVE");
			return;
		}
		Position *positon = message.mutable_syncpostion();
		CLuaParam input[9];
		input[0] = indexID;
		input[1] = message.sceneid();
		input[2] = message.servertime();
		input[3] = positon->entityid();
		input[4] = positon->destx();
		input[5] = positon->desty();
		input[6] = positon->destz();
		input[7] = positon->orientation();
		input[8] = positon->speed();
		LuaModule::Instance()->RunFunction("OnAOIMove", input, 9, nullptr, 0);
		break;
	}
	case  SERVER_MESSAGE_OPCODE_STOP_MOVE:
	{
		SC_STOP_MOVE_SYNC message;
		if (!message.ParseFromArray(data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH))
		{
			_xerror("Failed ParseMessage SERVER_MESSAGE_OPCODE_STOP_MOVE");
			return;
		}
		int count = message.syncpostion_size();
		for (int i = 0; i < count; ++i)
		{
			Position *positon = message.mutable_syncpostion(i);
			CLuaParam input[9];
			input[0] = indexID;
			input[1] = message.sceneid();
			input[2] = message.servertime();
			input[3] = positon->entityid();
			input[4] = positon->destx();
			input[5] = positon->desty();
			input[6] = positon->destz();
			input[7] = positon->orientation();
			input[8] = positon->speed();
			LuaModule::Instance()->RunFunction("OnAOIStopMove", input, 9, nullptr, 0);
		}		
		break;
	}
	case SERVER_MESSAGE_FORCE_POSITION:
	{
		SC_FORCE_MOVE message;
		if (!message.ParseFromArray(data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH))
		{
			_xerror("Failed ParseMessage SERVER_MESSAGE_FORCE_POSITION");
			return;
		}
		CLuaParam input[6];
		input[0] = indexID;
		input[1] = message.sceneid();
		input[2] = message.entityid();
		input[3] = message.destx();
		input[4] = message.desty();
		input[5] = message.destz();
		LuaModule::Instance()->RunFunction("OnAOIForcePosition", input, 6, nullptr, 0);
		break;
	}
	case SERVER_MESSAGE_OPCODE_TURN_DIRECTION:
	{
		SC_TURN_DIRECTION message;
		if (!message.ParseFromArray(data + CLIENT_MESSAGE_HEAD_LENGTH, dataLength - CLIENT_MESSAGE_HEAD_LENGTH))
		{
			_xerror("Failed ParseMessage SERVER_MESSAGE_OPCODE_TURN_DIRECTION");
			return;
		}
		CLuaParam input[7];
		input[0] = indexID;
		input[1] = message.sceneid();
		input[2] = message.entityid();
		input[3] = message.destx();
		input[4] = message.desty();
		input[5] = message.destz();
		input[6] = message.direction();
		LuaModule::Instance()->RunFunction("OnAOITurnDirection", input, 7, nullptr, 0);
		break;
	}
	default:
		break;
	}
}

void RobotManager::SendMessageToServer(int clientid, int opcode, IMessage* message)
{
	std::string data;
	if (!message->SerializeToString(&data))
	{
		_xerror("Failed SerializeToString");
		return;
	}
	ClientMessageHead* head = (ClientMessageHead*)(m_sendBuffer + NET_HEAD_LENGTH);
	head->SerialNumber = 1;
	head->ServiceType = 0;
	head->MessageID = opcode;

	DATA_LENGTH_TYPE* pTotalLen = (DATA_LENGTH_TYPE*)m_sendBuffer;
	*pTotalLen = CLIENT_MESSAGE_HEAD_LENGTH + data.length();

	memcpy(m_sendBuffer + CLIENT_MESSAGE_HEAD_LENGTH + NET_HEAD_LENGTH, data.data(), data.length());

	//def encrypt(data) :
	//	data_length = len(data)
	//	rst = bytearray(data_length)

	//	offset = 2
	//	for i in range(0, offset) :
	//		rst[i] = ord(data[i])
	//		for i in range(offset, data_length - 1) :
	//			rst[i] = ord(data[i]) ^ ord(data[i + 1])
	//			rst[data_length - 1] = ord(data[data_length - 1]) ^ 58

	//// Decode
	//m_recvBuff[dataLength - 1] ^= 0x3A;
	//for (int i = dataLength - 2; i >= 0; --i)
	//{
	//	m_recvBuff[i] ^= m_recvBuff[i + 1];
	//}

	int dataLength = CLIENT_MESSAGE_HEAD_LENGTH + NET_HEAD_LENGTH + data.length();

	int offset = 4;
	for (int i = offset; i <= dataLength - 2; ++i)
	{
		m_sendBuffer[i] ^= m_sendBuffer[i + 1];
	}
	m_sendBuffer[dataLength - 1] ^= 0x3A;

	m_ClientManager.SendByServerID(clientid, m_sendBuffer, dataLength);
}
	

void RobotManager::Tick()
{
	m_ClientManager.Tick();
	CTimerMgr::Instance()->Tick();
	for (int i = 0; i < m_config.MaxClientCount; ++i)
	{
		Robot& robot = m_robotPoll[i];
		UpdateRobot(robot);
	}
}

void RobotManager::Run()
{
	Tick();
	//std::this_thread::sleep_for(std::chrono::milliseconds(10));
}

void RobotManager::UpdateRobot(Robot& robot)
{
	uint64_t nowtime = GetNowTimeMille();
	switch (robot.m_status)
	{
	case ROBOT_STATUS_INIT:
	{
		robot.m_status = ROBOT_STATUS_CONNECTING;
	}	
		break;
	case ROBOT_STATUS_CONNECTING:
		break;
	case ROBOT_STATUS_CONNECTED:
	{
		////执行登录
		CLuaParam input[1];
		input[0] = robot.m_indexID;

		LuaModule::Instance()->RunFunction("OnClientConnected", input, 1, nullptr, 0);
		robot.m_status = ROBOT_STATUS_LOGINING;

		//if (robot.m_lastTickTime + 100 < nowtime)
		//{
		//	CS_PING request;
		//	request.set_clienttime(nowtime);
		//	SendMessageToServer(robot.m_indexID, CLIENT_MESSAGE_OPCODE_PING, &request);
		//	robot.m_lastTickTime = nowtime;
		//}
	}
		break;
	case ROBOT_STATUS_LOGINING:
		break;
	case ROBOT_STATUS_LOGIN_FAILED:
	{
		// 重新登录
	}
		break;
	case ROBOT_STATUS_RUN:
	{
		CLuaParam input[1];
		input[0] = robot.m_indexID;
		LuaModule::Instance()->RunFunction("OnClientRuning", input, 1, nullptr, 0);
	}
		break;
	case ROBOT_STATUS_CLOSE:
		break;
	default:
		break;
	}
}

void RobotManager::OnPingBack(Robot& robot, const char* data, const DATA_LENGTH_TYPE dataLength)
{
	SC_PING_BACK request;
	if (!request.ParseFromArray(data, dataLength))
	{
		_xerror("Failed Parse SC_PING_BACK");
		return;
	}
	RobotHeartbeat* pHeartbeat = robot.GetHeartbeat();
	if (pHeartbeat == nullptr)
	{
		return;
	}
	pHeartbeat->OnPingBack(request.servertime(), request.clienttime());
	//uint64_t latency = GetNowTimeMille() - request.clienttime();
	//_info("Latencty of %d is %llu", robot.m_indexID, latency);
}

void RobotManager::SetClientStatus(const int robotID, const int status)
{
	if (robotID < 0 || robotID >= m_config.MaxClientCount)
	{
		_warn("RobotManager::SetClientStatus robotID is illegal!robotID is %d,max client count is %d", robotID, m_config.MaxClientCount)
		return;
	}
	Robot& robot = m_robotPoll[robotID];
	robot.m_status = (ROBOT_STATUS)status;
}

void RobotManager::GetPath(const int nResourceId, const float cx, const float cy, const float cz, const float tx, const float ty, const float tz,std::vector<float> &path)
{
	std::map<int, std::shared_ptr<OftDetour> >::iterator it = m_mapDetour.find(nResourceId);
	if (it == m_mapDetour.end())
	{
		return;
	}
	int length = 0;
	const float* p = it->second->GetPath(cx, cy, cz, tx, ty, tz, length);
	if (length < 1)
	{
		return;
	}
	path.reserve(length * 3);
	for (int i = 0; i < length;++i)
	{
		path.push_back(*(p + 3 * i));
		path.push_back(*(p + 3 * i + 1));
		path.push_back(*(p + 3 * i + 2));
	}
}

void RobotManager::InitScenesDetour(const std::vector<int> &scenes)
{
	char cFileName[20];
	for (std::vector<int>::const_iterator it = scenes.begin(); it != scenes.end(); ++it)
	{		
		sprintf(cFileName, "detour/%d.nav", *it);
		m_mapDetour[*it] = std::make_shared<OftDetour>();
		m_mapDetour[*it]->Init(cFileName);
	}
}

void RobotManager::RobotMove(const int nRobotId,const uint32_t nSceneId, const std::string strEntityId, const float x, const float y, const float z, const float orientation, const float speed)
{
	CS_CLIENT_MOVE message;
	Position* pos = message.mutable_mypostion();
	pos->set_destx(x);
	pos->set_desty(y);
	pos->set_destz(z);
	pos->set_entityid(strEntityId);
	pos->set_orientation(orientation);
	pos->set_speed(speed);
	message.set_sceneid(nSceneId);
	message.set_clienttime(GetNowTimeMille());
	SendMessageToServer(nRobotId, CLIENT_MESSAGE_OPCODE_MOVE, &message);	
}

void RobotManager::RobotStopMove(const int nRobotId, const uint32_t nSceneId, const std::string strEntityId, const float x, const float y, const float z, const float orientation, const float speed)
{
	CS_STOP_MOVE message;
	Position* pos = message.mutable_mypostion();
	pos->set_destx(x);
	pos->set_desty(y);
	pos->set_destz(z);
	pos->set_entityid(strEntityId);
	pos->set_orientation(orientation);
	pos->set_speed(speed);
	message.set_sceneid(nSceneId);
	message.set_clienttime(GetNowTimeMille());
	SendMessageToServer(nRobotId, CLIENT_MESSAGE_OPCODE_STOP_MOVE, &message);
}

void RobotManager::SyncTime(const int nRobotId)
{
	_info("RobotManager::SyncTime nRobotId %d", nRobotId);
	if (nRobotId < 0 || nRobotId >= m_config.MaxClientCount)
	{
		_warn("RobotManager::SyncTime nRobotId is illegal!nRobotId is %d,max client count is %d", nRobotId, m_config.MaxClientCount)
		return;
	}
	Robot& robot = m_robotPoll[nRobotId];
	RobotHeartbeat* pHeartbeat = robot.GetHeartbeat();
	if (pHeartbeat == nullptr)
	{
		return;
	}
	pHeartbeat->StartSyncTime();
}

void RobotManager::SendPingMessage(const int nRobotId, const uint64_t lClientTime)
{
	//_info("SendPingMessage lClientTime = %llu", lClientTime);
	CS_PING message;
	message.set_clienttime(lClientTime);
	SendMessageToServer(nRobotId, CLIENT_MESSAGE_OPCODE_PING, &message);
}

void RobotManager::SendPingBackMessage(const int nRobotId, const long lServerTime, const long lClientTime)
{
	CS_PING_BACK_BACK message;
	message.set_servertime(lServerTime);
	message.set_clienttime(lClientTime);
	SendMessageToServer(nRobotId, CLIENT_MESSAGE_OPCODE_PING_BACK, &message);
}

uint64_t RobotManager::GetServerTime(const int nRobotId)
{
	if (nRobotId < 0 || nRobotId >= m_config.MaxClientCount)
	{
		_warn("RobotManager::GetServerTime nRobotId is illegal!nRobotId is %d,max client count is %d", nRobotId, m_config.MaxClientCount)
		return GetNowTimeMille();
	}
	Robot& robot = m_robotPoll[nRobotId];
	RobotHeartbeat* pHeartbeat = robot.GetHeartbeat();
	if (pHeartbeat == nullptr)
	{
		return GetNowTimeMille();
	}
	return pHeartbeat->GetServerTime();
}