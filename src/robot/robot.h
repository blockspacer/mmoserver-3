#pragma once
#ifndef _ROBOT_H_
#define _ROBOT_H_

#include "robotheartbeat.h"

enum ROBOT_STATUS
{
	ROBOT_STATUS_NONE,
	ROBOT_STATUS_INIT,
	ROBOT_STATUS_CONNECTING,
	ROBOT_STATUS_CONNECTED,
	ROBOT_STATUS_CONNECT_FAILED,
	ROBOT_STATUS_LOGINING,
	ROBOT_STATUS_LOGIN_FAILED,
	ROBOT_STATUS_RUN,
	ROBOT_STATUS_FAILED,
	ROBOT_STATUS_CLOSE,
};

struct Robot
{
public:
	void Reset()
	{
		m_status = ROBOT_STATUS_NONE;
		m_lastTickTime = 0;
	}
	void SetIndexId(int nIndexId)
	{
		m_indexID = nIndexId;
		m_robotHeartbeat.SetRobotId(m_indexID);
	}
	RobotHeartbeat* GetHeartbeat()
	{
		return &m_robotHeartbeat;
	}
public:
	int m_sock;
	int m_indexID;
	ROBOT_STATUS m_status;
	uint64_t m_lastTickTime;
private:
	RobotHeartbeat m_robotHeartbeat;
};
#endif