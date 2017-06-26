#include "robotheartbeat.h"
#include "Timer.h"
#include "robotmanager.h"
#include <limits.h>

RobotHeartbeat::RobotHeartbeat()
{
	Reset();
}

RobotHeartbeat::~RobotHeartbeat()
{
}

void RobotHeartbeat::Reset()
{
	m_nTimerId = 0;
	m_nRobotId = -1;
	m_nMinDelay = ULLONG_MAX;
}

void RobotHeartbeat::SetRobotId(int nRobotId)
{
	m_nRobotId = nRobotId;
}

void RobotHeartbeat::Tick(int param)
{
	SendPingMessage();
}

void RobotHeartbeat::StartSyncTime()
{
	StopSyncTime();
	SendPingMessage();
	m_nTimerId = CTimerMgr::Instance()->CreateTimer(0, this, &RobotHeartbeat::Tick, 1000,1000);
}

void RobotHeartbeat::StopSyncTime()
{
	if (m_nTimerId != 0)
	{
		CTimerMgr::Instance()->DestroyTimer(m_nTimerId);
	}	
	m_nTimerId = 0;
}

void RobotHeartbeat::SendPingMessage()
{
	if (m_nRobotId == -1)
	{
		_warn("RobotHeartbeat::SendPingMessage m_nRobotId == -1")
		return;
	}
	GlobalRobotManager->SendPingMessage(m_nRobotId, GetNowTimeMille());
}

void RobotHeartbeat::OnPingBack(const uint64_t nServerTime,const uint64_t nClientTime)
{
	//_info("RobotHeartbeat::OnPingBack nServerTime %ld,nClientTime %ld", nServerTime, nClientTime)
	uint64_t nNowTime = GetNowTimeMille();
	uint64_t nDelayTime = (nNowTime - nClientTime) / 2;
	if (nDelayTime < m_nMinDelay)
	{
		m_nMinDelay = nDelayTime;
	}
	m_nDeltaTime = nServerTime + nDelayTime - nClientTime;
	SendPingBackMessage(nServerTime);
}

void RobotHeartbeat::SendPingBackMessage(const uint64_t nServerTime)
{
	//_info("RobotHeartbeat::SendPingBackMessage nServerTime %ld", nServerTime)
	if (m_nRobotId == -1)
	{
		_warn("RobotHeartbeat::SendPingBackMessage m_nRobotId == -1")
		return;
	}
	GlobalRobotManager->SendPingBackMessage(m_nRobotId, nServerTime, GetNowTimeMille());
}

uint64_t RobotHeartbeat::GetServerTime()
{
	return GetNowTimeMille() + m_nDeltaTime;
}