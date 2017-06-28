#pragma once
#ifndef _ROBOT_MANAGER_H_
#define _ROBOT_MANAGER_H_
#include "common.h"
#include "ClientNetModule.h"
#include "LuaModule.h"
#include "message.h"
#include "robot.h"
#include "robotconfig.h"
#include "detour/OftDetour.h"

enum ROBOT_MANAGER_STATUS
{
	ROBOT_MANAGER_STATUS_INIT,
	ROBOT_MANAGER_STATUS_CONNECTED,
	ROBOT_MANAGER_STATUS_LOGIN,
	ROBOT_MANAGER_STATUS_DO_COMMAND,
	ROBOT_MANAGER_STATUS_STOP,
};

class RobotManager
{
public:
	RobotManager(std::string strServerName);
	~RobotManager();

	bool Init(std::string configPath);
	void OnSocketEvent(const int sock, const NET_EVENT eEvent, INet* net);
	void OnMessage(const int sock, const char* data, const DATA_LENGTH_TYPE dataLength);
	void SendMessageToServer(int clientid, int opcode, IMessage* message);
	void Tick();
	void Run();
	void UpdateRobot(Robot& robot);
	void OnPingBack(Robot& robot, const char* data, const DATA_LENGTH_TYPE dataLength);
	void SetClientStatus(const int robotId, const int status);
	void GetPath(const int nResourceId, const float cx, const float cy, const float cz, const float tx, const float ty, const float tz, std::vector<float> &path);
	void InitScenesDetour(const std::vector<int> &scenes);
	void RobotMove(const int nRobotId,const uint32_t nSceneId,const std::string strEntityId,const float x,const float y,const float z,const float orientation,const float speed);
	void RobotStopMove(const int nRobotId, const uint32_t nSceneId, const std::string strEntityId, const float x, const float y, const float z, const float orientation, const float speed);
	void SyncTime(const int nRobotId);
	void SendPingMessage(const int nRobotId, const uint64_t lClientTime);
	void SendPingBackMessage(const int nRobotId, const long lServerTime, const long lClientTime);
	uint64_t GetServerTime(const int nRobotId);
private:
	void OnShowDebugInfo(int a);
	std::string GetRobotStatusString(ROBOT_STATUS status);
private:
	RobotConfigure m_config;
	ClientNetModule    m_ClientManager;
	LogModule         m_logModule;
	char m_sendBuffer[MAX_SENDBUF_LEN];
	//int m_maxClientCount;
	//std::string m_serverIP;
	//int m_serverPort;
	Robot* m_robotPoll;
	std::map<int, int> m_sockToIndexID;
	int m_loginCount;

	int m_status;
	int m_debugTimerID;
	uint64_t m_startTime;
	std::string m_strServerName;
	std::map<int, std::shared_ptr<OftDetour> > m_mapDetour;
};

extern RobotManager* g_pRobotManager;
#define GlobalRobotManager g_pRobotManager

#endif